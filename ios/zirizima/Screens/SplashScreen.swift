import SwiftUI

struct SplashScreen: View {
    @Environment(AppState.self) private var state
    var onContinue: () -> Void

    @State private var rise = false

    var body: some View {
        ZStack {
            Color.zCanvas.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("zirizima.")
                    .font(.zHero).zTight()
                    .foregroundStyle(Color.zInk)
                    .opacity(rise ? 1 : 0)
                    .offset(y: rise ? 0 : 12)

                Capsule()
                    .fill(Color.zPrimary)
                    .frame(width: 32, height: 5)
                    .opacity(rise ? 1 : 0)
                    .offset(y: rise ? 0 : 12)

                Text(state.t("tagline"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.zInk48)
                    .opacity(rise ? 1 : 0)
                    .offset(y: rise ? 0 : 12)

                Button(action: onContinue) {
                    Text(state.t("getStarted"))
                }
                .buttonStyle(PillStyle(variant: .primary))
                .padding(.top, 16)
                .opacity(rise ? 1 : 0)
                .offset(y: rise ? 0 : 12)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) { rise = true }
        }
    }
}
