import Foundation

/// Anonymous device identifier persisted in UserDefaults across app launches.
/// Used to enforce one-review-per-device and per-device rate limiting.
enum DeviceID {
    private static let key = "zirizima.device_id"

    static var value: UUID {
        let defaults = UserDefaults.standard
        if let s = defaults.string(forKey: key), let id = UUID(uuidString: s) {
            return id
        }
        let id = UUID()
        defaults.set(id.uuidString, forKey: key)
        return id
    }
}
