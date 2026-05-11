import GoogleMobileAds
import SwiftUI
import UIKit

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let view = BannerView(adSize: AdSizeBanner)
        view.adUnitID = adUnitID
        view.rootViewController = Self.topViewController()
        view.load(Request())
        return view
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    private static func topViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}

struct BannerAdStrip: View {
    let adUnitID: String

    var body: some View {
        BannerAdView(adUnitID: adUnitID)
            .frame(width: 320, height: 50)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.zCanvas.opacity(0.98))
    }
}
