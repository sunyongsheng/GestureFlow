import Foundation

public struct ConfigurationDirectoryResolver {
    public private(set) var configurationDirectoryURL: URL
    public let standaloneStore: StandaloneConfigurationStore
    private let fileManager: FileManager
    private let homeDirectory: URL

    public init(
        configurationDirectoryURL: URL,
        standaloneStore: StandaloneConfigurationStore = StandaloneConfigurationStore(),
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil
    ) {
        self.configurationDirectoryURL = configurationDirectoryURL
        self.standaloneStore = standaloneStore
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory ?? ConfigurationPathFormatting.homeDirectoryURL(fileManager: fileManager)
    }

    public static var bootstrapBaseDirectoryURL: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return applicationSupport.appendingPathComponent("GestureFlow", isDirectory: true)
    }

    public static var defaultConfigurationDirectoryURL: URL {
        bootstrapBaseDirectoryURL
    }

    public static var defaultConfigurationDirectoryDisplayPath: String {
        ConfigurationPathFormatting.shortenHomePath(defaultConfigurationDirectoryURL.path)
    }

    public static func xdgConfigurationDirectoryURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) -> URL {
        let home = homeDirectory ?? ConfigurationPathFormatting.homeDirectoryURL(fileManager: fileManager)
        let configHome: URL

        if let xdgConfigHome = environment["XDG_CONFIG_HOME"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !xdgConfigHome.isEmpty {
            let expanded = ConfigurationPathFormatting.expandPath(xdgConfigHome, homeDirectory: home)
            configHome = URL(fileURLWithPath: expanded, isDirectory: true)
        } else {
            configHome = home.appendingPathComponent(".config", isDirectory: true)
        }

        return configHome.appendingPathComponent("gestureflow", isDirectory: true)
    }

    public static func xdgConfigurationDirectoryDisplayPath(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) -> String {
        let home = homeDirectory ?? ConfigurationPathFormatting.homeDirectoryURL(fileManager: fileManager)
        return ConfigurationPathFormatting.shortenHomePath(
            xdgConfigurationDirectoryURL(
                environment: environment,
                homeDirectory: home,
                fileManager: fileManager
            ).path,
            homeDirectory: home
        )
    }

    public var configFileURL: URL {
        configurationDirectoryURL.appendingPathComponent(ConfigurationFileNames.config)
    }

    public var gesturesFileURL: URL {
        configurationDirectoryURL.appendingPathComponent(ConfigurationFileNames.gestures)
    }

    public static func bootstrap(
        standaloneStore: StandaloneConfigurationStore = StandaloneConfigurationStore(),
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil
    ) -> ConfigurationDirectoryResolver {
        let home = homeDirectory ?? ConfigurationPathFormatting.homeDirectoryURL(fileManager: fileManager)
        let loadResult = standaloneStore.loadRecovering()
        let candidatePath = loadResult.configuration?.configurationDirectory
        let resolvedURL: URL

        if let candidatePath,
           let normalized = ConfigurationPathFormatting.normalizedDirectoryURL(
               from: candidatePath,
               homeDirectory: home
           ),
           Self.isValidConfigurationDirectory(normalized, fileManager: fileManager) {
            resolvedURL = normalized
        } else {
            resolvedURL = defaultConfigurationDirectoryURL
        }

        return ConfigurationDirectoryResolver(
            configurationDirectoryURL: resolvedURL,
            standaloneStore: standaloneStore,
            fileManager: fileManager,
            homeDirectory: home
        )
    }

    public mutating func apply(configurationDirectory: URL) {
        configurationDirectoryURL = configurationDirectory.standardizedFileURL
    }

    public func makeConfigurationStore() -> ConfigurationStore {
        ConfigurationStore(fileURL: configFileURL)
    }

    public func makeGestureConfigurationStore() -> GestureConfigurationStore {
        GestureConfigurationStore(fileURL: gesturesFileURL)
    }

    public func displayPath() -> String {
        ConfigurationPathFormatting.shortenHomePath(
            configurationDirectoryURL.path,
            homeDirectory: homeDirectory
        )
    }

    public static func isValidConfigurationDirectory(
        _ url: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }
        return fileManager.isWritableFile(atPath: url.path)
    }
}
