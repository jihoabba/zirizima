import SwiftUI

struct HomeScreen: View {
    @Environment(AppState.self) private var state
    @Environment(\.appNavPath) private var navPath
    @StateObject private var location = LocationManager.shared

    @State private var loading = true
    @State private var toilets: [Toilet] = []
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                topBar
                if loading {
                    ProgressView().padding(.vertical, 60).frame(maxWidth: .infinity)
                } else if let hero = toilets.first {
                    heroCard(hero)
                    if toilets.count > 1 {
                        Text(state.t("alternatives"))
                            .font(.zEyebrow)
                            .foregroundStyle(Color.zInk48)
                            .tracking(1.4)
                            .padding(.leading, 4)
                            .padding(.top, 4)
                        ForEach(toilets.dropFirst()) { t in
                            altCard(t)
                        }
                    }
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [Color.zCanvas, Color.zParchment],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .safeAreaInset(edge: .bottom) {
            BannerAdStrip(adUnitID: AdConfig.homeBanner)
        }
        .task(id: locationKey) { await load() }
        .onChange(of: location.location) { _, newLoc in
            if let c = newLoc?.coordinate {
                state.updateLocation(c)
            }
        }
    }

    private var locationKey: String {
        "\(state.coordinate.latitude),\(state.coordinate.longitude),\(state.filter.activeCount),\(state.language)"
    }

    private var topBar: some View {
        HStack {
            Text("zirizima.")
                .font(.zSubtitle).zTight()
                .foregroundStyle(Color.zInk)
            Spacer()
            HStack(spacing: 8) {
                Text(state.language.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.zInk48)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(Capsule().stroke(Color.zHairline, lineWidth: 1))
            }
        }
        .padding(4)
    }

    @ViewBuilder
    private func heroCard(_ t: Toilet) -> some View {
        Button {
            navPath.wrappedValue.append(.detail(t))
        } label: {
            ZCard {
                VStack(spacing: 0) {
                    Text(state.t("nearestFreeToilet"))
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(Color.zInk48)

                    Text(state.name(t.name))
                        .font(.zSubtitle).zTight()
                        .foregroundStyle(Color.zInk)
                        .padding(.top, 6)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(distanceText(t).number)
                            .font(.zBigNumber(64)).zTight()
                            .foregroundStyle(Color.zInk)
                        Text(distanceText(t).unit)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.zInk48)
                    }
                    .padding(.top, 12)

                    Text("\(state.t("minWalk", ["n": "\(t.walkMinutes)"]))  ·  \(state.t("directionWord", ["dir": state.direction(t.direction(from: state.coordinate.latitude, state.coordinate.longitude))]))")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.zInk48)
                        .padding(.top, 6)

                    Hairline().padding(.vertical, 14)

                    HStack(spacing: 8) {
                        StarsView(rating: t.ratingAvg, size: 13)
                        Text(String(format: "%.1f", t.ratingAvg))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.zInk)
                        Text("(\(t.ratingCount) \(state.t("reviews")))")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.zInk48)
                    }

                    badges(t).padding(.top, 12)

                    Button {
                        openMaps(t)
                    } label: {
                        Text("→ \(state.t("takeMeThere"))")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PillStyle(variant: .primary))
                    .padding(.top, 16)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func altCard(_ t: Toilet) -> some View {
        Button {
            navPath.wrappedValue.append(.detail(t))
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.name(t.name))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.zInk)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        StarsView(rating: t.ratingAvg, size: 11)
                        Text(String(format: "%.1f (%d)", t.ratingAvg, t.ratingCount))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.zInk48)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(distanceText(t).number)\(distanceText(t).unit)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.zPrimary)
                    Text(state.t("minWalkOnly", ["n": "\(t.walkMinutes)"]))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.zInk48)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.zCanvas)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.04), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func badges(_ t: Toilet) -> some View {
        HStack(spacing: 6) {
            if t.accessible    { ZBadge(text: state.t("accessible"), icon: "♿") }
            if t.babyChange    { ZBadge(text: state.t("babyChange"), icon: "👶") }
            if t.is24h         { ZBadge(text: state.t("open24")) }
            if t.englishSign == true { ZBadge(text: "EN") }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("○").font(.system(size: 40)).opacity(0.4)
            Text(state.t("noResults"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.zInk80)
            Text(state.t("tryAdjust"))
                .font(.system(size: 13))
                .foregroundStyle(Color.zInk48)
            Button(action: { state.filter = .init() }) {
                Text(state.t("all"))
            }
            .buttonStyle(PillStyle(variant: .primary, compact: true))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func distanceText(_ t: Toilet) -> (number: String, unit: String) {
        if t.distanceMeters < 1000 {
            return ("\(t.distanceMeters)", "m")
        }
        return (String(format: "%.1f", Double(t.distanceMeters) / 1000.0), "km")
    }

    private func openMaps(_ t: Toilet) {
        let urlStr = "https://www.google.com/maps/dir/?api=1&origin=\(state.coordinate.latitude),\(state.coordinate.longitude)&destination=\(t.lat),\(t.lng)&travelmode=walking"
        if let url = URL(string: urlStr) {
            UIApplication.shared.open(url)
        }
    }

    private func load() async {
        loading = true
        do {
            let result = try await SupabaseAPI.shared.nearestToilets(
                lat: state.coordinate.latitude,
                lng: state.coordinate.longitude,
                limit: 3,
                filter: state.filter
            )
            toilets = result
            error = nil
        } catch {
            self.error = "\(error)"
        }
        loading = false
    }
}
