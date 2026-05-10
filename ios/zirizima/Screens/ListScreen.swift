import SwiftUI

struct ListScreen: View {
    @Environment(AppState.self) private var state
    @Environment(\.appNavPath) private var navPath
    @State private var toilets: [Toilet] = []
    @State private var loading = true
    @State private var showingFilter = false

    var body: some View {
        VStack(spacing: 0) {
            subnav
            ScrollView {
                LazyVStack(spacing: 10) {
                    if loading {
                        ProgressView().padding(.vertical, 40)
                    } else if toilets.isEmpty {
                        empty
                    } else {
                        ForEach(toilets) { t in
                            row(t)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .background(Color.zCanvas)
        .task(id: filterKey) { await load() }
        .sheet(isPresented: $showingFilter) {
            FilterSheet().presentationDetents([.medium, .large])
        }
    }

    private var filterKey: String {
        "\(state.coordinate.latitude),\(state.coordinate.longitude),\(state.filter.activeCount),\(state.language)"
    }

    private var subnav: some View {
        VStack(spacing: 8) {
            HStack {
                Text(state.t("nearby"))
                    .font(.zSubtitle).zTight()
                    .foregroundStyle(Color.zInk)
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterChip(label: state.t("all"), on: state.filter.activeCount == 0) {
                        state.filter = .init()
                    }
                    FilterChip(label: "♿", on: state.filter.accessible) {
                        state.filter.accessible.toggle()
                    }
                    FilterChip(label: "👶", on: state.filter.babyChange) {
                        state.filter.babyChange.toggle()
                    }
                    FilterChip(label: "🌙 \(state.t("open24"))", on: state.filter.open24h) {
                        state.filter.open24h.toggle()
                    }
                    FilterChip(label: "EN", on: state.filter.englishSign) {
                        state.filter.englishSign.toggle()
                    }
                    FilterChip(
                        label: state.t("filter") + (state.filter.activeCount > 0 ? " (\(state.filter.activeCount))" : ""),
                        on: false
                    ) { showingFilter = true }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(Hairline(), alignment: .bottom)
    }

    @ViewBuilder
    private func row(_ t: Toilet) -> some View {
        Button {
            navPath.wrappedValue.append(.detail(t))
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.name(t.name))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.zInk)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        StarsView(rating: t.ratingAvg, size: 11)
                        Text(String(format: "%.1f (%d)", t.ratingAvg, t.ratingCount))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.zInk48)
                    }
                    HStack(spacing: 4) {
                        if t.accessible    { ZBadge(text: "♿") }
                        if t.babyChange    { ZBadge(text: "👶") }
                        if t.is24h         { ZBadge(text: state.t("open24")) }
                        if t.englishSign == true { ZBadge(text: "EN") }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(t.distanceMeters)m")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.zPrimary)
                    Text(state.t("minWalkOnly", ["n": "\(t.walkMinutes)"]))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.zInk48)
                }
            }
            .padding(14)
            .background(Color.zCanvas)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.zDivider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Text("○").font(.system(size: 40)).opacity(0.4)
            Text(state.t("noResults"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.zInk80)
            Text(state.t("tryAdjust"))
                .font(.system(size: 13))
                .foregroundStyle(Color.zInk48)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private func load() async {
        loading = true
        do {
            toilets = try await SupabaseAPI.shared.allToilets(
                lat: state.coordinate.latitude,
                lng: state.coordinate.longitude,
                filter: state.filter
            )
        } catch {
            toilets = []
        }
        loading = false
    }
}
