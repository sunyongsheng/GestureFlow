import Foundation

public struct ConfigurationLoadResult: Equatable {
    public var configuration: AppConfiguration
    public var didRecoverFromCorruption: Bool
    public var backupURL: URL?

    public init(
        configuration: AppConfiguration,
        didRecoverFromCorruption: Bool,
        backupURL: URL? = nil
    ) {
        self.configuration = configuration
        self.didRecoverFromCorruption = didRecoverFromCorruption
        self.backupURL = backupURL
    }
}

public struct ConfigurationStore {
    public var fileURL: URL

    public init(fileURL: URL = ConfigurationStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    public func load() throws -> AppConfiguration {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return AppConfiguration()
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(AppConfiguration.self, from: data)
    }

    public func loadRecovering() -> ConfigurationLoadResult {
        do {
            return ConfigurationLoadResult(
                configuration: try load(),
                didRecoverFromCorruption: false
            )
        } catch {
            let backupURL = backupCorruptConfiguration()
            return ConfigurationLoadResult(
                configuration: AppConfiguration(),
                didRecoverFromCorruption: true,
                backupURL: backupURL
            )
        }
    }

    public func save(_ configuration: AppConfiguration) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configuration)
        try data.write(to: fileURL, options: .atomic)
    }

    private func backupCorruptConfiguration() -> URL? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let backupURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(fileURL.lastPathComponent).corrupt-\(Date().timeIntervalSince1970)")

        do {
            try FileManager.default.moveItem(at: fileURL, to: backupURL)
            return backupURL
        } catch {
            return nil
        }
    }

    public static func defaultFileURL() -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return applicationSupport
            .appendingPathComponent("GestureFlow", isDirectory: true)
            .appendingPathComponent("config.json")
    }
}
