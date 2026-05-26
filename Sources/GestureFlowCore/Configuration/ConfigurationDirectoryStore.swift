import Foundation

public struct ConfigurationDirectoryStore {
    public static let userDefaultsKey = "configurationDirectory"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> String? {
        defaults.string(forKey: Self.userDefaultsKey)
    }

    public func save(configurationDirectory: String) throws {
        let trimmed = configurationDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let defaultPath = ConfigurationDirectoryResolver.defaultConfigurationDirectoryURL
            .standardizedFileURL
            .path
        let normalizedSavedPath = URL(fileURLWithPath: trimmed, isDirectory: true)
            .standardizedFileURL
            .path

        if normalizedSavedPath == defaultPath {
            defaults.removeObject(forKey: Self.userDefaultsKey)
        } else {
            defaults.set(trimmed, forKey: Self.userDefaultsKey)
        }
    }
}
