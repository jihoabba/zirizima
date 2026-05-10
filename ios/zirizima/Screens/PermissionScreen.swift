import SwiftUI
import CoreLocation

struct PermissionScreen: View {
    @Environment(AppState.self) private var state
    @StateObject private var location = LocationManager.shared
    var onComplete: () -> Void

    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.zCanvas.ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.zParchment)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                    Circle()
                        .fill(Color.zPrimary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.zPrimary.opacity(0.16))
                                .frame(width: 56, height: 56)
                        )
                        .scaleEffect(pulse ? 1.04 : 1.0)
                }
                .padding(.bottom, 12)

                Text(state.t("findToilets"))
                    .font(.zTitle).zTight()
                    .foregroundStyle(Color.zInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)

                Text(state.t("findToiletsBody"))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.zInk48)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
                    .lineSpacing(2)

                Spacer()

                Button(action: requestLocation) {
                    Text(state.t("allowLocation"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillStyle(variant: .primary))

                Button(action: onComplete) {
                    Text(state.t("maybeLater"))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.zPrimary)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onChange(of: location.permission) { _, newStatus in
            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                state.locationGranted = true
                if let coord = location.location?.coordinate {
                    state.updateLocation(coord)
                }
                onComplete()
            }
        }
    }

    private func requestLocation() {
        location.requestWhenInUse()
    }
}
