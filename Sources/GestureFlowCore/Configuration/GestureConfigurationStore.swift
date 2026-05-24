import Foundation

public struct GestureConfigurationStore {
    public var fileURL: URL

    public init(fileURL: URL = GestureConfigurationStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    public func load() throws -> GestureConfiguration {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return GestureConfiguration.defaultTemplate
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(GestureConfiguration.self, from: data)
    }

    public func save(_ configuration: GestureConfiguration) throws {
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

    public static func defaultFileURL() -> URL {
        ConfigurationDirectoryResolver.bootstrap().gesturesFileURL
    }
}
