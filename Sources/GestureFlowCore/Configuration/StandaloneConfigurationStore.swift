import Foundation

public struct StandaloneConfigurationLoadResult: Equatable {
    public var configuration: StandaloneConfiguration?
    public var didRecoverFromCorruption: Bool
    public var backupURL: URL?

    public init(
        configuration: StandaloneConfiguration?,
        didRecoverFromCorruption: Bool,
        backupURL: URL? = nil
    ) {
        self.configuration = configuration
        self.didRecoverFromCorruption = didRecoverFromCorruption
        self.backupURL = backupURL
    }
}

public struct StandaloneConfigurationStore {
    public var fileURL: URL

    public init(fileURL: URL = StandaloneConfigurationStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    public func load() throws -> StandaloneConfiguration? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try YAMLConfigurationCoder.decode(StandaloneConfiguration.self, from: data)
    }

    public func loadRecovering() -> StandaloneConfigurationLoadResult {
        do {
            return StandaloneConfigurationLoadResult(
                configuration: try load(),
                didRecoverFromCorruption: false
            )
        } catch {
            let backupURL = backupCorruptConfiguration()
            return StandaloneConfigurationLoadResult(
                configuration: nil,
                didRecoverFromCorruption: true,
                backupURL: backupURL
            )
        }
    }

    public func save(_ configuration: StandaloneConfiguration) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let data = try YAMLConfigurationCoder.encode(configuration)
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
        ConfigurationDirectoryResolver.bootstrapBaseDirectoryURL
            .appendingPathComponent(ConfigurationFileNames.standalone)
    }
}
