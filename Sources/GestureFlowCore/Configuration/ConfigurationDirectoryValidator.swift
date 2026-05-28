import Foundation

public enum ConfigurationDirectoryValidator {
    public static func validateForAdoption(
        targetDirectory: URL,
        oldDirectory: URL,
        fileManager: FileManager = .default
    ) throws {
        for fileName in ConfigurationFileNames.configurationDirectoryFiles {
            let targetFile = targetDirectory.appendingPathComponent(fileName)
            let oldFile = oldDirectory.appendingPathComponent(fileName)

            if fileManager.fileExists(atPath: targetFile.path) {
                try loadConfiguration(fileName: fileName, fileURL: targetFile)
            } else if fileManager.fileExists(atPath: oldFile.path) {
                try loadConfiguration(fileName: fileName, fileURL: oldFile)
            }
        }
    }

    private static func loadConfiguration(fileName: String, fileURL: URL) throws {
        switch fileName {
        case ConfigurationFileNames.config:
            _ = try AppConfigurationStore(fileURL: fileURL).load()
        case ConfigurationFileNames.gesturesBuiltin, ConfigurationFileNames.gesturesCustom:
            _ = try GestureConfigurationStore(fileURL: fileURL).load()
        default:
            break
        }
    }
}
