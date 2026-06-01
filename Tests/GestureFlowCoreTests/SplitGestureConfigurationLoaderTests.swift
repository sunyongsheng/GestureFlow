import XCTest
@testable import GestureFlowCore

final class SplitGestureConfigurationLoaderTests: XCTestCase {
    func testMergeTagsBuiltinAndCustomSources() {
        let customGesture = GestureDefinition(
            name: "Custom",
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.up]),
            shortcut: KeyboardShortcutAction(keyCode: 1, modifiers: [.command])
        )
        let result = SplitGestureConfigurationLoader.merge(
            builtin: BuiltInGestureSeeds.factoryBuiltinConfiguration(),
            custom: GestureConfiguration(
                applicationBundleIdentifiers: ["com.example.app"],
                gestures: [customGesture],
                gestureSignatures: [GestureSignature(tokens: [.left])]
            )
        )

        XCTAssertEqual(result.conflictingGestureIDs, [])
        XCTAssertTrue(result.configuration.applicationBundleIdentifiers.contains("com.example.app"))
        XCTAssertTrue(result.configuration.applicationBundleIdentifiers.contains("com.google.Chrome"))
        XCTAssertTrue(result.configuration.applicationBundleIdentifiers.contains("com.apple.finder"))
        let builtinCount = BuiltInGestureSeeds.factoryGestures().count
        XCTAssertEqual(result.configuration.gestures.count, builtinCount + 1)
        XCTAssertTrue(result.configuration.gestures.dropLast().allSatisfy { $0.source == .builtin })
        XCTAssertEqual(result.configuration.gestures.last?.source, .custom)
        XCTAssertEqual(result.configuration.gestures.last?.id, customGesture.id)
    }

    func testMergeDetectsDuplicateIDs() {
        let duplicateID = BuiltInGestureSeeds.closeWindowID
        let custom = GestureConfiguration(
            gestures: [
                GestureDefinition(
                    id: duplicateID,
                    name: "Duplicate",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.up]),
                    shortcut: KeyboardShortcutAction(keyCode: 1, modifiers: [.command])
                )
            ]
        )

        let result = SplitGestureConfigurationLoader.merge(
            builtin: BuiltInGestureSeeds.factoryBuiltinConfiguration(),
            custom: custom
        )

        XCTAssertEqual(result.conflictingGestureIDs, [duplicateID])
        let builtinCount = BuiltInGestureSeeds.factoryGestures().count
        XCTAssertEqual(result.configuration.gestures.count, builtinCount + 1)
    }

    func testBootstrapMissingFilesCreatesBothYAMLFiles() throws {
        let directory = try makeTemporaryDirectory()
        let builtinStore = GestureConfigurationStore(
            fileURL: directory.appendingPathComponent(ConfigurationFileNames.gesturesBuiltin)
        )
        let customStore = GestureConfigurationStore(
            fileURL: directory.appendingPathComponent(ConfigurationFileNames.gesturesCustom)
        )

        try SplitGestureConfigurationLoader.bootstrapMissingFiles(
            builtinStore: builtinStore,
            customStore: customStore
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: builtinStore.fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: customStore.fileURL.path))
        XCTAssertEqual(try builtinStore.load().gestures.count, BuiltInGestureSeeds.factoryGestures().count)
        XCTAssertTrue(try customStore.load().gestures.isEmpty)
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
