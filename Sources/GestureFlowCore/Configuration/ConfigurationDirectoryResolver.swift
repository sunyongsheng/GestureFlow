import Foundation

public struct ConfigurationDirectoryResolver {
    public private(set) var configurationDirectoryURL: URL
    public let configurationDirectoryStore: ConfigurationDirectoryStore
    private let fileManager: FileManager
    private let homeDirectory: URL

    public init(
        configurationDirectoryURL: URL,
        configurationDirectoryStore: ConfigurationDirectoryStore = ConfigurationDirectoryStore(),
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil
    ) {
        self.configurationDirectoryURL = configurationDirectoryURL
        self.configurationDirectoryStore = configurationDirectoryStore
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

    public var gesturesBuiltinFileURL: URL {
        configurationDirectoryURL.appendingPathComponent(ConfigurationFileNames.gesturesBuiltin)
    }

    public var gesturesCustomFileURL: URL {
        configurationDirectoryURL.appendingPathComponent(ConfigurationFileNames.gesturesCustom)
    }

    public static func bootstrap(
        configurationDirectoryStore: ConfigurationDirectoryStore = ConfigurationDirectoryStore(),
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil
    ) -> ConfigurationDirectoryResolver {
        let home = homeDirectory ?? ConfigurationPathFormatting.homeDirectoryURL(fileManager: fileManager)
        let candidatePath = configurationDirectoryStore.load()
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
            configurationDirectoryStore: configurationDirectoryStore,
            fileManager: fileManager,
            homeDirectory: home
        )
    }

    public mutating func apply(configurationDirectory: URL) {
        configurationDirectoryURL = configurationDirectory.standardizedFileURL
    }

    public func makeAppConfigurationStore() -> AppConfigurationStore {
        AppConfigurationStore(fileURL: configFileURL)
    }

    public func makeBuiltinGestureConfigurationStore() -> GestureConfigurationStore {
        GestureConfigurationStore(fileURL: gesturesBuiltinFileURL)
    }

    public func makeCustomGestureConfigurationStore() -> GestureConfigurationStore {
        GestureConfigurationStore(fileURL: gesturesCustomFileURL)
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
