import SwiftUI

// Single Route enum drives all NavigationStack pushes from the home tree.
enum AppRoute: Hashable {
    case detail(Toilet)
    case search
    case rate(Toilet)
}
