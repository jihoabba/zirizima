import SwiftUI
import Observation
import CoreLocation

@Observable
@MainActor
final class AppState {
    enum Phase {
        case onboarding   // splash → language → permission
        case main         // home + the rest of the app
    }

    var phase: Phase
    var language: String          // "en" | "ko" | "zh" | "ja"
    var locationGranted: Bool
    var coordinate: CLLocationCoordinate2D
    var filter: ToiletFilter = .init()
    var saved: Set<UUID> = []

    init() {
        let saved = UserDefaults.standard.string(forKey: "zirizima.lang")
        let sysLang = (Locale.current.language.languageCode?.identifier ?? "en")
        let normalized: String = {
            switch sysLang {
            case "ko": return "ko"
            case "zh": return "zh"
            case "ja": return "ja"
            default:   return "en"
            }
        }()
        self.language = saved ?? normalized

        let onboarded = UserDefaults.standard.bool(forKey: "zirizima.onboarded")
        self.phase = onboarded ? .main : .onboarding

        let lm = LocationManager.shared
        let status = lm.permission
        self.locationGranted = (status == .authorizedWhenInUse || status == .authorizedAlways)

        if let loc = lm.location {
            self.coordinate = loc.coordinate
        } else {
            self.coordinate = LocationManager.defaultCoordinate
        }
    }

    func setLanguage(_ lang: String) {
        language = lang
        UserDefaults.standard.set(lang, forKey: "zirizima.lang")
    }

    func completeOnboarding() {
        phase = .main
        UserDefaults.standard.set(true, forKey: "zirizima.onboarded")
    }

    func updateLocation(_ coord: CLLocationCoordinate2D) {
        coordinate = coord
    }

    func toggleSave(_ id: UUID) {
        if saved.contains(id) { saved.remove(id) } else { saved.insert(id) }
    }

    /// Localized lookup for our string table.
    func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        Localized.t(key, in: language, vars: vars)
    }

    func name(_ s: LocalizedString) -> String { s.resolve(language) }

    /// Localized compass direction word
    func direction(_ code: String) -> String {
        Localized.direction(code, in: language)
    }
}
