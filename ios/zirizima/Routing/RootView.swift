import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            switch state.phase {
            case .onboarding:
                OnboardingFlow()
            case .main:
                MainTab()
            }
        }
        .background(Color.zParchment)
    }
}

// =============================================================================
// Onboarding flow — splash → language → permission
// =============================================================================

struct OnboardingFlow: View {
    @Environment(AppState.self) private var state
    @State private var step: Int = 0  // 0: splash, 1: language, 2: permission

    var body: some View {
        ZStack {
            switch step {
            case 0: SplashScreen { withAnimation { step = 1 } }
            case 1: LanguageScreen(onContinue: { withAnimation { step = 2 } })
            default: PermissionScreen(onComplete: { state.completeOnboarding() })
            }
        }
        .transition(.opacity)
    }
}

// =============================================================================
// Main tab — Home + List + Search using a custom tab bar that matches the
// HTML prototype's home-bottom-nav.
// =============================================================================

struct MainTab: View {
    @Environment(AppState.self) private var state
    @State private var selection: Tab = .home
    @State private var navPath: [AppRoute] = []

    enum Tab: Hashable { case home, browse, search }

    var body: some View {
        NavigationStack(path: $navPath) {
            VStack(spacing: 0) {
                Group {
                    switch selection {
                    case .home:   HomeScreen()
                    case .browse: ListScreen()
                    case .search: SearchScreen()
                    }
                }
                bottomNav
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .detail(let t): DetailScreen(toilet: t)
                case .search:        SearchScreen()
                case .rate(let t):   RateScreen(toilet: t)
                }
            }
        }
        .environment(\.appNavPath, $navPath)
    }

    private var bottomNav: some View {
        HStack(spacing: 0) {
            navButton(.home, system: "house.fill", label: state.t("home"))
            navButton(.browse, system: "list.bullet", label: state.t("browse"))
            navButton(.search, system: "magnifyingglass", label: state.t("search"))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(Hairline(), alignment: .top)
    }

    @ViewBuilder
    private func navButton(_ tab: Tab, system: String, label: String) -> some View {
        Button {
            selection = tab
            navPath.removeAll()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: system).font(.system(size: 18))
                Text(label).font(.system(size: 10))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(selection == tab ? Color.zPrimary : Color.zInk48)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Environment value for nav path access from screens

private struct AppNavPathKey: EnvironmentKey {
    static let defaultValue: Binding<[AppRoute]> = .constant([])
}
extension EnvironmentValues {
    var appNavPath: Binding<[AppRoute]> {
        get { self[AppNavPathKey.self] }
        set { self[AppNavPathKey.self] = newValue }
    }
}
