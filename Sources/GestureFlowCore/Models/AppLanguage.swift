import Foundation

public enum AppLanguage: String, Codable, Equatable, CaseIterable {
    case zhHans = "zh-Hans"
    case en = "en"

    public init(decodingPersistedValue rawValue: String) {
        self = AppLanguage(rawValue: rawValue) ?? .zhHans
    }
}
