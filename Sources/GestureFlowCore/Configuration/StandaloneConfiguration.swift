import Foundation

public struct StandaloneConfiguration: Codable, Equatable {
    public var configurationDirectory: String

    public init(configurationDirectory: String) {
        self.configurationDirectory = configurationDirectory
    }
}
