import Foundation

public enum ConfigurationDirectoryRelocationError: Error, Equatable {
    case invalidPath
    case notADirectory
    case directoryNotWritable
    case targetContainsConfigurationFiles
    case sameAsCurrentDirectory
    case copyFailed
    case configurationDirectoryWriteFailed
}

extension ConfigurationDirectoryRelocationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidPath:
            return "请输入有效路径。"
        case .notADirectory:
            return "请选择文件夹路径。"
        case .directoryNotWritable:
            return "目录不可写。"
        case .targetContainsConfigurationFiles:
            return "目标目录已存在配置文件，请选择空目录。"
        case .sameAsCurrentDirectory:
            return "配置目录未更改。"
        case .copyFailed:
            return "复制配置文件失败。"
        case .configurationDirectoryWriteFailed:
            return "保存配置目录设置失败。"
        }
    }
}

public struct ConfigurationDirectoryRelocator {
    private let fileManager: FileManager
    private let configurationDirectoryStore: ConfigurationDirectoryStore
    private let homeDirectory: URL

    public init(
        configurationDirectoryStore: ConfigurationDirectoryStore = ConfigurationDirectoryStore(),
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil
    ) {
        self.configurationDirectoryStore = configurationDirectoryStore
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory ?? ConfigurationPathFormatting.homeDirectoryURL(fileManager: fileManager)
    }

    public func relocate(
        from oldDirectory: URL,
        to newDirectoryPath: String
    ) throws -> URL {
        guard let newDirectory = ConfigurationPathFormatting.normalizedDirectoryURL(
            from: newDirectoryPath,
            homeDirectory: homeDirectory
        ) else {
            throw ConfigurationDirectoryRelocationError.invalidPath
        }

        let oldNormalized = oldDirectory.standardizedFileURL
        if newDirectory == oldNormalized {
            throw ConfigurationDirectoryRelocationError.sameAsCurrentDirectory
        }

        try validateTargetDirectory(newDirectory)

        if !fileManager.fileExists(atPath: newDirectory.path) {
            try fileManager.createDirectory(at: newDirectory, withIntermediateDirectories: true)
        }

        try copyConfigurationFiles(from: oldNormalized, to: newDirectory)

        do {
            try configurationDirectoryStore.save(configurationDirectory: newDirectory.path)
        } catch {
            throw ConfigurationDirectoryRelocationError.configurationDirectoryWriteFailed
        }

        deleteBusinessConfigurationFiles(in: oldNormalized)

        return newDirectory
    }

    private func validateTargetDirectory(_ directory: URL) throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw ConfigurationDirectoryRelocationError.notADirectory
            }
            guard fileManager.isWritableFile(atPath: directory.path) else {
                throw ConfigurationDirectoryRelocationError.directoryNotWritable
            }
        }

        for fileName in ConfigurationFileNames.configurationDirectoryFiles {
            let fileURL = directory.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: fileURL.path) {
                throw ConfigurationDirectoryRelocationError.targetContainsConfigurationFiles
            }
        }
    }

    private func copyConfigurationFiles(from oldDirectory: URL, to newDirectory: URL) throws {
        let files = ConfigurationFileNames.configurationDirectoryFiles
        for fileName in files {
            let source = oldDirectory.appendingPathComponent(fileName)
            guard fileManager.fileExists(atPath: source.path) else {
                continue
            }
            let destination = newDirectory.appendingPathComponent(fileName)
            do {
                try fileManager.copyItem(at: source, to: destination)
            } catch {
                throw ConfigurationDirectoryRelocationError.copyFailed
            }
        }
    }

    private func deleteBusinessConfigurationFiles(in directory: URL) {
        for fileName in ConfigurationFileNames.configurationDirectoryFiles {
            let fileURL = directory.appendingPathComponent(fileName)
            try? fileManager.removeItem(at: fileURL)
        }
    }
}
