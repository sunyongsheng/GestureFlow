import Foundation

public enum AppLanguage: String, Codable, Equatable, CaseIterable {
    case zhHans = "zh-Hans"
    case en = "en"

    public init(decodingPersistedValue rawValue: String) {
        self = AppLanguage(rawValue: rawValue) ?? .en
    }

    /// Maps a locale identifier (e.g. from `Locale.preferredLanguages`) to a supported app language.
    public init?(matchingLocaleIdentifier identifier: String) {
        let normalized = identifier.lowercased()
        if normalized.hasPrefix("zh") {
            self = .zhHans
            return
        }
        if normalized.hasPrefix("en") {
            self = .en
            return
        }
        return nil
    }

    /// Resolves the best supported language from the user's system locale preferences.
    public static func resolvingSystemPreferred() -> AppLanguage {
        for identifier in Locale.preferredLanguages {
            if let language = AppLanguage(matchingLocaleIdentifier: identifier) {
                return language
            }
        }
        if let language = AppLanguage(matchingLocaleIdentifier: Locale.current.identifier) {
            return language
        }
        return .en
    }
}
