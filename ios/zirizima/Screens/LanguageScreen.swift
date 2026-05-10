import SwiftUI

struct LanguageScreen: View {
    @Environment(AppState.self) private var state
    var onContinue: () -> Void

    private let langs = ["en", "zh", "ja", "ko"]

    var body: some View {
        ZStack {
            Color.zCanvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text(state.t("chooseLanguage"))
                    .font(.zDisplay).zTight()
                    .foregroundStyle(Color.zInk)
                    .padding(.top, 24)

                Text(state.t("chooseLanguageSub"))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.zInk48)
                    .padding(.top, 6)
                    .padding(.bottom, 28)

                VStack(spacing: 10) {
                    ForEach(langs, id: \.self) { lang in
                        let selected = state.language == lang
                        Button(action: { state.setLanguage(lang) }) {
                            HStack {
                                Text(Localized.t("langName", in: lang))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.zInk)
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.zPrimary)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                            .padding(16)
                            .background(selected ? Color.zCanvas : Color.zParchment)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selected ? Color.zPrimary : Color.clear, lineWidth: 2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                Button(action: onContinue) {
                    Text(state.t("continue"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillStyle(variant: .primary))
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
    }
}
