import GoogleMobileAds
import SwiftUI

@main
struct ZirizimaApp: App {
    @State private var appState = AppState()

    init() {
        MobileAds.shared.start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.light)
        }
    }
}
