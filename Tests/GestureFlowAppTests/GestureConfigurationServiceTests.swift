import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class GestureConfigurationServiceTests: XCTestCase {
    func testLoadCreatesBothFilesWhenMissing() throws {
        let directory = try makeTemporaryDirectory()
        let service = makeService(in: directory)

        service.load()

        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent(ConfigurationFileNames.gesturesBuiltin).path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent(ConfigurationFileNames.gesturesCustom).path
            )
        )
        let builtinCount = BuiltInGestureSeeds.factoryGestures().count
        XCTAssertEqual(service.configuration.gestures.count, builtinCount)
        XCTAssertTrue(service.configuration.gestures.allSatisfy { $0.source == .builtin })
    }

    func testSaveWritesCustomMetadataToCustomFileOnly() throws {
        let directory = try makeTemporaryDirectory()
        let service = makeService(in: directory)
        service.load()
        service.configuration.applicationBundleIdentifiers = ["com.apple.Safari"]

        try service.save()

        let custom = try GestureConfigurationStore(
            fileURL: directory.appendingPathComponent(ConfigurationFileNames.gesturesCustom)
        ).load()
        XCTAssertEqual(custom.applicationBundleIdentifiers, ["com.apple.Safari"])
    }

    func testSaveBuiltinEditWritesBuiltinFile() throws {
        let directory = try makeTemporaryDirectory()
        let service = makeService(in: directory)
        service.load()

        var updated = service.configuration
        guard let index = updated.gestures.firstIndex(where: { $0.source == .builtin }) else {
            return XCTFail("Expected built-in gesture")
        }
        updated.gestures[index].shortcut = KeyboardShortcutAction(keyCode: 1, modifiers: [.command])
        service.configuration = updated

        try service.save()

        let builtin = try GestureConfigurationStore(
            fileURL: directory.appendingPathComponent(ConfigurationFileNames.gesturesBuiltin)
        ).load()
        XCTAssertEqual(builtin.gestures[0].shortcut.keyCode, 1)
    }

    func testRestoreDefaultsResetsBothFiles() throws {
        let directory = try makeTemporaryDirectory()
        let service = makeService(in: directory)
        service.load()
        service.configuration.applicationBundleIdentifiers = ["com.apple.Safari"]
        try service.save()

        try service.restoreDefaults()

        let custom = try GestureConfigurationStore(
            fileURL: directory.appendingPathComponent(ConfigurationFileNames.gesturesCustom)
        ).load()
        XCTAssertTrue(custom.applicationBundleIdentifiers.isEmpty)
        XCTAssertTrue(custom.gestures.isEmpty)
        let builtinCount = BuiltInGestureSeeds.factoryGestures().count
        XCTAssertEqual(service.configuration.gestures.count, builtinCount)
        XCTAssertTrue(service.configuration.gestures.contains { $0.id == BuiltInGestureSeeds.closeWindowID })
    }

    func testLoadReportsMergeConflicts() throws {
        let directory = try makeTemporaryDirectory()
        let builtinStore = GestureConfigurationStore(
            fileURL: directory.appendingPathComponent(ConfigurationFileNames.gesturesBuiltin)
        )
        let customStore = GestureConfigurationStore(
            fileURL: directory.appendingPathComponent(ConfigurationFileNames.gesturesCustom)
        )
        try builtinStore.save(BuiltInGestureSeeds.factoryBuiltinConfiguration())
        try customStore.save(
            GestureConfiguration(
                gestures: [
                    GestureDefinition(
                        id: BuiltInGestureSeeds.closeWindowID,
                        name: "Duplicate",
                        trigger: .rightMouse,
                        signature: GestureSignature(tokens: [.up]),
                        shortcut: KeyboardShortcutAction(keyCode: 1, modifiers: [.command])
                    )
                ]
            )
        )

        let service = GestureConfigurationService(builtinStore: builtinStore, customStore: customStore)

        XCTAssertEqual(service.conflictingGestureIDs, [BuiltInGestureSeeds.closeWindowID])
    }

    private func makeService(in directory: URL) -> GestureConfigurationService {
        GestureConfigurationService(
            builtinStore: GestureConfigurationStore(
                fileURL: directory.appendingPathComponent(ConfigurationFileNames.gesturesBuiltin)
            ),
            customStore: GestureConfigurationStore(
                fileURL: directory.appendingPathComponent(ConfigurationFileNames.gesturesCustom)
            )
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }
}
