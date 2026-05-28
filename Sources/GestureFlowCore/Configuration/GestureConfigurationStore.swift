import Foundation

public struct GestureConfigurationStore {
    public var fileURL: URL

    public init(fileURL: URL = GestureConfigurationStore.defaultCustomFileURL()) {
        self.fileURL = fileURL
    }

    public func load() throws -> GestureConfiguration {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return GestureConfiguration.emptyCustomTemplate
        }

        let data = try Data(contentsOf: fileURL)
        return try YAMLConfigurationCoder.decode(GestureConfiguration.self, from: data)
    }

    public func save(_ configuration: GestureConfiguration) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let data = try YAMLConfigurationCoder.encode(configuration)
        try data.write(to: fileURL, options: .atomic)
    }

    public static func defaultCustomFileURL() -> URL {
        ConfigurationDirectoryResolver.bootstrap().gesturesCustomFileURL
    }
}
