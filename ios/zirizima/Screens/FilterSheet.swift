import SwiftUI

struct FilterSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ToiletFilter = .init()
    @State private var count: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grabber.padding(.top, 8)
            Text(state.t("filter"))
                .font(.zTitle).zTight()
                .foregroundStyle(Color.zInk)
                .padding(.top, 8)
                .padding(.bottom, 12)

            row(key: state.t("wheelchairAccessible"), sub: state.t("wheelchairAccessibleSub"), icon: "♿",
                isOn: Binding(get: { draft.accessible }, set: { draft.accessible = $0; recount() }))
            Hairline()
            row(key: state.t("babyChanging"), sub: state.t("babyChangingSub"), icon: "👶",
                isOn: Binding(get: { draft.babyChange }, set: { draft.babyChange = $0; recount() }))
            Hairline()
            row(key: state.t("open24hours"), sub: state.t("open24hoursSub"), icon: "🌙",
                isOn: Binding(get: { draft.open24h }, set: { draft.open24h = $0; recount() }))
            Hairline()
            row(key: state.t("englishSignage"), sub: state.t("englishSignageSub"), icon: "EN",
                isOn: Binding(get: { draft.englishSign }, set: { draft.englishSign = $0; recount() }))

            Spacer()

            Button {
                state.filter = draft
                dismiss()
            } label: {
                Text(state.t("showNToilets", ["n": "\(count)"]))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillStyle(variant: .primary))
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 22)
        .background(Color.zCanvas)
        .onAppear {
            draft = state.filter
            Task { await recountAsync() }
        }
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.zInk24)
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func row(key: String, sub: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 16))
                    .frame(width: 32, height: 32)
                    .background(Color.zParchment)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text(key)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.zInk)
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.zInk48)
                }
            }
            Spacer()
            ZToggle(isOn: isOn)
        }
        .padding(.vertical, 12)
    }

    private func recount() {
        Task { await recountAsync() }
    }

    private func recountAsync() async {
        do {
            let list = try await SupabaseAPI.shared.allToilets(
                lat: state.coordinate.latitude,
                lng: state.coordinate.longitude,
                filter: draft
            )
            count = list.count
        } catch {
            count = 0
        }
    }
}
