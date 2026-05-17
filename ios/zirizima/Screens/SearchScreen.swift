import SwiftUI

struct SearchScreen: View {
    @Environment(AppState.self) private var state
    @Environment(\.appNavPath) private var navPath
    @State private var query = ""
    @State private var areas: [Area] = []
    @State private var results: [Toilet] = []
    @State private var loadingAreas = true
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 10) {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        areaList
                    } else {
                        resultList
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .background(Color.zCanvas)
        .task {
            await loadAreas()
            scheduleSearch()
        }
        .onChange(of: query) { _, _ in scheduleSearch() }
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
                    .focused($searchFocused)
                    .submitLabel(.search)
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
            .contentShape(Capsule())
            .onTapGesture { searchFocused = true }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(Hairline(), alignment: .bottom)
    }

    @ViewBuilder
    private var areaList: some View {
        if loadingAreas {
            ProgressView().padding(.vertical, 40)
        } else if areas.isEmpty {
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
            ForEach(areas) { a in areaRow(a) }
        }
    }

    @ViewBuilder
    private var resultList: some View {
        if searching {
            ProgressView().padding(.vertical, 40)
        } else if results.isEmpty {
            Text(state.t("noResults"))
                .font(.system(size: 14))
                .foregroundStyle(Color.zInk48)
                .padding(.vertical, 40)
        } else {
            ForEach(results) { t in toiletRow(t) }
        }
    }

    @ViewBuilder
    private func areaRow(_ a: Area) -> some View {
        Button {
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

    @ViewBuilder
    private func toiletRow(_ t: Toilet) -> some View {
        Button {
            navPath.wrappedValue.append(.detail(t))
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.name(t.name))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.zInk)
                        .lineLimit(1)
                    Text(state.name(t.address))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.zInk48)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(distanceText(t))
                        .font(.system(size: 14, weight: .semibold))
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

    private func distanceText(_ t: Toilet) -> String {
        if t.distanceMeters < 1000 { return "\(t.distanceMeters)m" }
        return String(format: "%.1fkm", Double(t.distanceMeters) / 1000.0)
    }

    private func loadAreas() async {
        loadingAreas = true
        do {
            areas = try await SupabaseAPI.shared.popularAreas()
        } catch {
            areas = []
        }
        loadingAreas = false
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            results = []
            searching = false
            return
        }
        searching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            do {
                let r = try await SupabaseAPI.shared.searchToilets(
                    query: q,
                    lat: state.coordinate.latitude,
                    lng: state.coordinate.longitude
                )
                if Task.isCancelled { return }
                results = r
            } catch {
                if !Task.isCancelled { results = [] }
            }
            if !Task.isCancelled { searching = false }
        }
    }
}
