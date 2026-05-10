import SwiftUI

struct SearchScreen: View {
    @Environment(AppState.self) private var state
    @State private var query = ""
    @State private var areas: [Area] = []
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 10) {
                    if loading {
                        ProgressView().padding(.vertical, 40)
                    } else if filteredAreas.isEmpty {
                        Text(state.t("noResults"))
                            .font(.system(size: 14))
                            .foregroundStyle(Color.zInk48)
                            .padding(.vertical, 40)
                    } else {
                        Text(state.t("popularAreas"))
                            .font(.zEyebrow)
                            .tracking(1.4)
                            .foregroundStyle(Color.zInk48)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 4)
                        ForEach(filteredAreas) { a in
                            areaRow(a)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .background(Color.zCanvas)
        .task { await load() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Text(state.t("search"))
                    .font(.zSubtitle).zTight()
                    .foregroundStyle(Color.zInk)
                Spacer()
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.zInk48)
                TextField(state.t("searchPlaceholder"), text: $query)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.zInk)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.zInk48)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.zCanvas)
            .overlay(Capsule().stroke(Color.zHairline, lineWidth: 1))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(Hairline(), alignment: .bottom)
    }

    @ViewBuilder
    private func areaRow(_ a: Area) -> some View {
        Button {
            // Tapping an area updates the user's "current location" so the
            // home screen re-fetches around there.
            state.updateLocation(.init(latitude: a.lat, longitude: a.lng))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.name(a.name))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.zInk)
                    Text(state.t("nToilets", ["n": "\(a.toiletCount)"]))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.zInk48)
                }
                Spacer()
                Text("›").foregroundStyle(Color.zPrimary).font(.system(size: 18))
            }
            .padding(14)
            .background(Color.zCanvas)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.zDivider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var filteredAreas: [Area] {
        if query.isEmpty { return areas }
        let q = query.lowercased()
        return areas.filter { a in
            [a.name.en, a.name.ko, a.name.zh, a.name.ja]
                .compactMap { $0?.lowercased() }
                .contains(where: { $0.contains(q) })
        }
    }

    private func load() async {
        loading = true
        do {
            areas = try await SupabaseAPI.shared.popularAreas()
        } catch {
            areas = []
        }
        loading = false
    }
}
