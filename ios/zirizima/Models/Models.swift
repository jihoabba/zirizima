import Foundation

// JSONB localized name from the DB: { en: "...", ko: "...", zh: "...", ja: "..." }
struct LocalizedString: Codable, Hashable {
    let en: String?
    let ko: String?
    let zh: String?
    let ja: String?

    func resolve(_ lang: String) -> String {
        switch lang {
        case "ko": return ko ?? en ?? zh ?? ja ?? ""
        case "zh": return zh ?? en ?? ko ?? ja ?? ""
        case "ja": return ja ?? en ?? ko ?? zh ?? ""
        default:   return en ?? ko ?? zh ?? ja ?? ""
        }
    }
}

// MARK: - Toilet

struct Toilet: Codable, Identifiable, Hashable {
    let id: UUID
    let externalId: String
    let name: LocalizedString
    let address: LocalizedString
    let lat: Double
    let lng: Double
    let district: String?
    let type: String          // 'subway' | 'park' | 'public' | 'tourist_info' | 'public_building'
    let hoursOpen: String?
    let hoursClose: String?
    let is24h: Bool
    let accessible: Bool
    let babyChange: Bool
    let paperProvided: Bool?
    let englishSign: Bool?
    let ratingAvg: Double
    let ratingCount: Int
    let primaryPhoto: String?
    let distanceMeters: Int

    enum CodingKeys: String, CodingKey {
        case id
        case externalId   = "external_id"
        case name
        case address
        case lat
        case lng
        case district
        case type
        case hoursOpen    = "hours_open"
        case hoursClose   = "hours_close"
        case is24h        = "is_24h"
        case accessible
        case babyChange   = "baby_change"
        case paperProvided = "paper_provided"
        case englishSign  = "english_sign"
        case ratingAvg    = "rating_avg"
        case ratingCount  = "rating_count"
        case primaryPhoto = "primary_photo"
        case distanceMeters = "distance_meters"
    }

    var walkMinutes: Int { max(1, Int((Double(distanceMeters) / 80.0).rounded())) }

    var hoursDisplay: String {
        if is24h { return "24h" }
        if let o = hoursOpen, let c = hoursClose {
            return "\(String(o.prefix(5))) – \(String(c.prefix(5)))"
        }
        return "—"
    }

    /// Apple-Maps-style compass direction from origin to this toilet.
    func direction(from oLat: Double, _ oLng: Double) -> String {
        let dLat = lat - oLat
        let dLng = lng - oLng
        let angle = atan2(dLng, dLat) * 180.0 / .pi
        let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N"]
        let idx = Int((((angle + 360).truncatingRemainder(dividingBy: 360)) / 45).rounded())
        return dirs[max(0, min(8, idx))]
    }

    /// Type-driven gradient stops (matches HTML prototype TYPE_GRADIENTS).
    var gradientColors: [String] {
        switch type {
        case "subway":          return ["#c8d6e5", "#a4c0d6", "#d6dee6"]
        case "park":            return ["#d6e8d4", "#b8d4b0", "#e3eee0"]
        case "tourist_info":    return ["#e0d4e8", "#c4b0d4", "#ede0e8"]
        case "public_building": return ["#e6e8ea", "#c8ccd4", "#eef0f2"]
        default:                return ["#e8e4dc", "#d4c8b8", "#ede8de"]
        }
    }
}

// MARK: - Area (curated tourist hotspots)

struct Area: Codable, Identifiable, Hashable {
    let slug: String
    let name: LocalizedString
    let toiletCount: Int
    var lat: Double = 0
    var lng: Double = 0

    var id: String { slug }

    enum CodingKeys: String, CodingKey {
        case slug, name
        case toiletCount = "toilet_count"
    }
}

// MARK: - Review

struct Review: Codable, Identifiable, Hashable {
    let id: UUID
    let rating: Int
    let tags: [String]
    let comment: String?
    let languageCode: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, rating, tags, comment
        case languageCode = "language_code"
        case createdAt    = "created_at"
    }

    var daysAgo: Int {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: createdAt)
            ?? ISO8601DateFormatter().date(from: createdAt)
            ?? Date()
        return max(0, Int(Date().timeIntervalSince(date) / 86400.0))
    }
}

// MARK: - Filters

struct ToiletFilter: Equatable {
    var accessible:   Bool = false
    var babyChange:   Bool = false
    var open24h:      Bool = false
    var englishSign:  Bool = false

    var activeCount: Int {
        [accessible, babyChange, open24h, englishSign].filter { $0 }.count
    }
}
