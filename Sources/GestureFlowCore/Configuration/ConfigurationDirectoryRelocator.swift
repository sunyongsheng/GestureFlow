import Foundation

public enum ConfigurationDirectoryRelocationError: Error, Equatable {
    case invalidPath
    case notADirectory
    case directoryNotWritable
    case sameAsCurrentDirectory
    case copyFailed
    case configurationDirectoryWriteFailed
    case invalidConfigurationContent
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

    public func targetHasConfigurationFiles(at directoryPath: String) -> Bool {
        guard let directory = ConfigurationPathFormatting.normalizedDirectoryURL(
            from: directoryPath,
            homeDirectory: homeDirectory
        ) else {
            return false
        }

        return ConfigurationFileNames.configurationDirectoryFiles.contains { fileName in
            fileManager.fileExists(
                atPath: directory.appendingPathComponent(fileName).path
            )
        }
    }

    public func relocate(
        from oldDirectory: URL,
        to newDirectoryPath: String,
        mode: ConfigurationDirectoryRelocationMode = .copyCurrentToEmptyTarget
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

        switch mode {
        case .copyCurrentToEmptyTarget:
            try copyConfigurationFiles(from: oldNormalized, to: newDirectory)
        case .adoptTargetAndMergeMissing:
            do {
                try ConfigurationDirectoryValidator.validateForAdoption(
                    targetDirectory: newDirectory,
                    oldDirectory: oldNormalized,
                    fileManager: fileManager
                )
            } catch {
                throw ConfigurationDirectoryRelocationError.invalidConfigurationContent
            }
            try mergeMissingConfigurationFiles(from: oldNormalized, to: newDirectory)
        }

        do {
            try configurationDirectoryStore.save(configurationDirectory: newDirectoryPath)
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
    }

    private func copyConfigurationFiles(from oldDirectory: URL, to newDirectory: URL) throws {
        for fileName in ConfigurationFileNames.configurationDirectoryFiles {
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

    private func mergeMissingConfigurationFiles(from oldDirectory: URL, to newDirectory: URL) throws {
        for fileName in ConfigurationFileNames.configurationDirectoryFiles {
            let destination = newDirectory.appendingPathComponent(fileName)
            guard !fileManager.fileExists(atPath: destination.path) else {
                continue
            }
            let source = oldDirectory.appendingPathComponent(fileName)
            guard fileManager.fileExists(atPath: source.path) else {
                continue
            }
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
