import Foundation

public enum AppLanguage: String, Codable, Equatable, CaseIterable {
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case en = "en"
    case ja = "ja"
    case ko = "ko"
    case hi = "hi"
    case es = "es"
    case fr = "fr"

    /// Native name shown in the language picker (not localized).
    public var nativeDisplayName: String {
        switch self {
        case .zhHans:
            return "中文（简体）"
        case .zhHant:
            return "中文（繁體）"
        case .en:
            return "English"
        case .ja:
            return "日本語"
        case .ko:
            return "한국어"
        case .hi:
            return "हिन्दी"
        case .es:
            return "Español"
        case .fr:
            return "Français"
        }
    }

    public init(decodingPersistedValue rawValue: String) {
        self = AppLanguage(rawValue: rawValue) ?? .en
    }

    /// Maps a locale identifier (e.g. from `Locale.preferredLanguages`) to a supported app language.
    public init?(matchingLocaleIdentifier identifier: String) {
        let normalized = identifier.lowercased().replacingOccurrences(of: "_", with: "-")

        if normalized.hasPrefix("zh") {
            self = Self.isTraditionalChineseLocale(normalized) ? .zhHant : .zhHans
            return
        }
        if normalized.hasPrefix("ja") {
            self = .ja
            return
        }
        if normalized.hasPrefix("ko") {
            self = .ko
            return
        }
        if normalized.hasPrefix("hi") {
            self = .hi
            return
        }
        if normalized.hasPrefix("es") {
            self = .es
            return
        }
        if normalized.hasPrefix("fr") {
            self = .fr
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

    private static func isTraditionalChineseLocale(_ normalized: String) -> Bool {
        normalized.contains("hant")
            || normalized.contains("-tw")
            || normalized.contains("-hk")
            || normalized.contains("-mo")
    }
}
