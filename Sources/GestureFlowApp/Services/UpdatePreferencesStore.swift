import Foundation

final class UpdatePreferencesStore: @unchecked Sendable {
    static let automaticUpdateEnabledKey = "automaticUpdateEnabled"
    static let lastUpdateCheckDateKey = "lastUpdateCheckDate"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isAutomaticUpdateEnabled: Bool {
        get {
            defaults.object(forKey: Self.automaticUpdateEnabledKey) as? Bool ?? false
        }
        set {
            defaults.set(newValue, forKey: Self.automaticUpdateEnabledKey)
        }
    }

    var lastUpdateCheckDate: Date? {
        get {
            let interval = defaults.double(forKey: Self.lastUpdateCheckDateKey)
            guard interval > 0 else { return nil }
            return Date(timeIntervalSince1970: interval)
        }
        set {
            if let newValue {
                defaults.set(newValue.timeIntervalSince1970, forKey: Self.lastUpdateCheckDateKey)
            } else {
                defaults.removeObject(forKey: Self.lastUpdateCheckDateKey)
            }
        }
    }
}
