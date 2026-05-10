import SwiftUI

@main
struct ZirizimaApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.light)
        }
    }
}
