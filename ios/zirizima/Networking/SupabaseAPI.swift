import Foundation

// Thin Supabase REST client. Zero dependencies — uses URLSession + JSONCoder.
// All RPCs map 1:1 to the prototype's data.js api.* methods.

enum SupabaseError: Error {
    case http(Int, String)
    case decode(String)
    case rateLimited
}

actor SupabaseAPI {
    static let shared = SupabaseAPI()

    // The publishable key is safe to ship in client code. RLS on the toilets/
    // areas/reviews tables prevents anything beyond what the RPCs allow.
    private let baseURL  = URL(string: "https://strdafvajmxpcwinlzdv.supabase.co")!
    private let apiKey   = "sb_publishable_GnyAhOMQohjiXl3gTeESPQ_gFkqo1Jo"

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 15
        cfg.timeoutIntervalForResource = 30
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: cfg)
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    // MARK: - Generic helpers

    private func request(path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { req.httpBody = body }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.http(0, "no response")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            if body.contains("rate_limit_exceeded") {
                throw SupabaseError.rateLimited
            }
            throw SupabaseError.http(http.statusCode, body)
        }
        return data
    }

    private func rpc<T: Decodable, P: Encodable>(_ name: String, params: P) async throws -> T {
        let body = try encoder.encode(params)
        let data = try await request(path: "/rest/v1/rpc/\(name)", method: "POST", body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseError.decode("\(name): \(error.localizedDescription) — body: \(raw)")
        }
    }

    // MARK: - Toilets

    struct NearestParams: Encodable {
        let in_lat: Double
        let in_lng: Double
        let in_limit: Int
        let in_accessible: Bool
        let in_baby_change: Bool
        let in_open_24h: Bool
        let in_english_sign: Bool
    }

    func nearestToilets(lat: Double, lng: Double, limit: Int, filter: ToiletFilter) async throws -> [Toilet] {
        let params = NearestParams(
            in_lat: lat, in_lng: lng, in_limit: limit,
            in_accessible: filter.accessible,
            in_baby_change: filter.babyChange,
            in_open_24h: filter.open24h,
            in_english_sign: filter.englishSign
        )
        return try await rpc("nearest_toilets", params: params)
    }

    func allToilets(lat: Double, lng: Double, filter: ToiletFilter) async throws -> [Toilet] {
        try await nearestToilets(lat: lat, lng: lng, limit: 50, filter: filter)
    }

    // MARK: - Areas

    func popularAreas() async throws -> [Area] {
        // Areas table — only need slug + name + toilet_count from API; we store
        // hand-picked lat/lng on-device for the 8 curated hotspots.
        let data = try await request(path: "/rest/v1/areas?order=popularity.desc&select=slug,name,toilet_count")
        var areas = (try? decoder.decode([Area].self, from: data)) ?? []
        // Splice in hand-picked lat/lng (production: include via PostGIS RPC).
        let coords: [String: (Double, Double)] = [
            "myeongdong":    (37.5636, 126.9826),
            "gangnam":       (37.4979, 127.0276),
            "hongdae":       (37.5567, 126.9237),
            "insadong":      (37.5740, 126.9851),
            "itaewon":       (37.5347, 126.9947),
            "dongdaemun":    (37.5666, 127.0090),
            "gyeongbokgung": (37.5796, 126.9770),
            "namdaemun":     (37.5599, 126.9774)
        ]
        for i in areas.indices {
            if let c = coords[areas[i].slug] {
                areas[i].lat = c.0
                areas[i].lng = c.1
            }
        }
        return areas
    }

    // MARK: - Reviews

    struct GetReviewsParams: Encodable {
        let in_toilet_id: UUID
        let in_limit: Int
    }

    func reviews(for toiletId: UUID, limit: Int = 5) async throws -> [Review] {
        try await rpc("get_reviews_for_toilet", params: GetReviewsParams(in_toilet_id: toiletId, in_limit: limit))
    }

    struct SubmitReviewParams: Encodable {
        let in_toilet_id: UUID
        let in_device_id: UUID
        let in_rating: Int
        let in_tags: [String]
        let in_comment: String?
        let in_language_code: String?
    }

    struct SubmitReviewResult: Decodable {
        let review_id: UUID
        let is_new: Bool
    }

    func submitReview(toiletId: UUID, rating: Int, tags: [String], comment: String?, language: String) async throws -> SubmitReviewResult {
        let params = SubmitReviewParams(
            in_toilet_id: toiletId,
            in_device_id: DeviceID.value,
            in_rating: rating,
            in_tags: tags,
            in_comment: comment?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? comment : nil,
            in_language_code: language
        )
        return try await rpc("submit_review", params: params)
    }
}
