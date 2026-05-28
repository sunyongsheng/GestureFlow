import XCTest
@testable import GestureFlowCore

final class ConfigurationDirectoryValidatorTests: XCTestCase {
    func testValidateForAdoptionAcceptsValidTargetConfig() throws {
        let root = try makeTemporaryRoot()
        let target = root.appendingPathComponent("target", isDirectory: true)
        let old = root.appendingPathComponent("old", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)

        try writeValidAppConfiguration(to: target.appendingPathComponent("config.yaml"))

        XCTAssertNoThrow(
            try ConfigurationDirectoryValidator.validateForAdoption(
                targetDirectory: target,
                oldDirectory: old
            )
        )
    }

    func testValidateForAdoptionRejectsInvalidTargetConfig() throws {
        let root = try makeTemporaryRoot()
        let target = root.appendingPathComponent("target", isDirectory: true)
        let old = root.appendingPathComponent("old", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)

        try "not: valid: yaml".write(
            to: target.appendingPathComponent("config.yaml"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertThrowsError(
            try ConfigurationDirectoryValidator.validateForAdoption(
                targetDirectory: target,
                oldDirectory: old
            )
        )
    }

    func testValidateForAdoptionValidatesOldGesturesWhenMissingAtTarget() throws {
        let root = try makeTemporaryRoot()
        let target = root.appendingPathComponent("target", isDirectory: true)
        let old = root.appendingPathComponent("old", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)

        try writeValidAppConfiguration(to: target.appendingPathComponent("config.yaml"))
        try writeValidSplitGestureConfiguration(in: old)

        XCTAssertNoThrow(
            try ConfigurationDirectoryValidator.validateForAdoption(
                targetDirectory: target,
                oldDirectory: old
            )
        )
    }

    func testValidateForAdoptionRejectsInvalidGesturesAtOldDirectory() throws {
        let root = try makeTemporaryRoot()
        let target = root.appendingPathComponent("target", isDirectory: true)
        let old = root.appendingPathComponent("old", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)

        try writeValidAppConfiguration(to: target.appendingPathComponent("config.yaml"))
        try "invalid".write(
            to: old.appendingPathComponent(ConfigurationFileNames.gesturesCustom),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertThrowsError(
            try ConfigurationDirectoryValidator.validateForAdoption(
                targetDirectory: target,
                oldDirectory: old
            )
        )
    }

    private func writeValidAppConfiguration(to url: URL) throws {
        let data = try YAMLConfigurationCoder.encode(AppConfiguration(isEnabled: true))
        try data.write(to: url, options: .atomic)
    }

    private func writeValidSplitGestureConfiguration(
        in directory: URL,
        custom: GestureConfiguration = .emptyCustomTemplate
    ) throws {
        try GestureConfigurationStore(
            fileURL: directory.appendingPathComponent(ConfigurationFileNames.gesturesBuiltin)
        ).save(BuiltInGestureSeeds.factoryBuiltinConfiguration())
        try GestureConfigurationStore(
            fileURL: directory.appendingPathComponent(ConfigurationFileNames.gesturesCustom)
        ).save(custom)
    }

    private func makeTemporaryRoot() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }
}
