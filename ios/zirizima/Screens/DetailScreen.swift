import SwiftUI

struct DetailScreen: View {
    @Environment(AppState.self) private var state
    @Environment(\.appNavPath) private var navPath
    @Environment(\.dismiss) private var dismiss
    let toilet: Toilet

    @State private var reviews: [Review] = []
    @State private var loadingReviews = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                title
                ratingRow
                infoGrid
                reviewSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 100)
        }
        .background(Color.zCanvas)
        .overlay(alignment: .bottom) {
            ctaBar
        }
        .safeAreaInset(edge: .bottom) {
            BannerAdStrip(adUnitID: AdConfig.detailBanner)
        }
        .navigationBarBackButtonHidden(true)
        .task { await loadReviews() }
    }

    private var header: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: toilet.gradientColors.map { Color(hex: $0) },
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.zInk)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                Spacer()
                Button {
                    state.toggleSave(toilet.id)
                } label: {
                    Image(systemName: state.saved.contains(toilet.id) ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(state.saved.contains(toilet.id) ? Color.zPrimary : Color.zInk)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(state.name(toilet.name))
                .font(.zTitle).zTight()
                .foregroundStyle(Color.zInk)
            Text("\(toilet.distanceMeters)m  ·  \(state.t("minWalk", ["n": "\(toilet.walkMinutes)"]))  ·  \(typeLabel)")
                .font(.system(size: 13))
                .foregroundStyle(Color.zInk48)
        }
    }

    private var ratingRow: some View {
        HStack(spacing: 8) {
            StarsView(rating: toilet.ratingAvg, size: 14)
            Text(String(format: "%.1f", toilet.ratingAvg))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.zInk)
            Text("\(toilet.ratingCount) \(state.t("reviews"))")
                .font(.system(size: 13))
                .foregroundStyle(Color.zInk48)
        }
    }

    private var infoGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 10) {
            infoCell(state.t("hours"), toilet.hoursDisplay)
            infoCell(state.t("accessible"), toilet.accessible ? "♿ \(state.t("yes"))" : state.t("no"))
            infoCell(state.t("babyChange"), toilet.babyChange ? "👶 \(state.t("yes"))" : state.t("no"))
            infoCell(state.t("paper"),
                     toilet.paperProvided == true ? state.t("provided") :
                     toilet.paperProvided == false ? state.t("notProvided") : "—")
        }
    }

    @ViewBuilder
    private func infoCell(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.zInk48)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.zInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.zDivider, lineWidth: 1))
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.t("recentReviews"))
                .font(.zEyebrow)
                .tracking(1.4)
                .foregroundStyle(Color.zInk48)
                .padding(.top, 8)

            if loadingReviews {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 16)
            } else if reviews.isEmpty {
                Text(state.t("noReviewsYet"))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.zInk48)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(reviews) { r in
                    reviewRow(r)
                    if r.id != reviews.last?.id { Hairline() }
                }
            }
        }
    }

    @ViewBuilder
    private func reviewRow(_ r: Review) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Anonymous · \(state.t("daysAgo", ["n": "\(r.daysAgo)"]))")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.zInk48)
                Spacer()
                StarsView(rating: Double(r.rating), size: 12)
            }
            if let c = r.comment, !c.isEmpty {
                Text(c)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.zInk80)
            }
            if !r.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(r.tags, id: \.self) { tag in
                        ZBadge(text: tag.replacingOccurrences(of: "_", with: " "))
                    }
                }
            }
        }
        .padding(.vertical, 12)
    }

    private var ctaBar: some View {
        HStack(spacing: 8) {
            Button {
                openMaps()
            } label: {
                Text("→ \(state.t("takeMeThere"))")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillStyle(variant: .primary))

            Button {
                navPath.wrappedValue.append(.rate(toilet))
            } label: {
                Text(state.t("rate"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillStyle(variant: .ghost))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .overlay(Hairline(), alignment: .top)
    }

    private var typeLabel: String {
        let map: [String: String] = [
            "subway":          "typeSubway",
            "park":            "typePark",
            "public":          "typePublic",
            "tourist_info":    "typeTouristInfo",
            "public_building": "typePublicBuilding"
        ]
        return state.t(map[toilet.type] ?? "typePublic")
    }

    private func openMaps() {
        let urlStr = "https://www.google.com/maps/dir/?api=1&origin=\(state.coordinate.latitude),\(state.coordinate.longitude)&destination=\(toilet.lat),\(toilet.lng)&travelmode=walking"
        if let url = URL(string: urlStr) { UIApplication.shared.open(url) }
    }

    private func loadReviews() async {
        loadingReviews = true
        do {
            reviews = try await SupabaseAPI.shared.reviews(for: toilet.id, limit: 5)
        } catch {
            reviews = []
        }
        loadingReviews = false
    }
}

// MARK: - Color hex helper

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        if h.hasPrefix("#") { h.removeFirst() }
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b: Double
        if h.count == 6 {
            r = Double((int >> 16) & 0xff) / 255
            g = Double((int >> 8)  & 0xff) / 255
            b = Double(int         & 0xff) / 255
        } else { r = 0.5; g = 0.5; b = 0.5 }
        self = Color(red: r, green: g, blue: b)
    }
}
