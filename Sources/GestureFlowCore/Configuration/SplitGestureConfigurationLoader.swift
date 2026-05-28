import Foundation

public struct GestureConfigurationMergeResult: Equatable {
    public var configuration: GestureConfiguration
    public var conflictingGestureIDs: [UUID]

    public init(configuration: GestureConfiguration, conflictingGestureIDs: [UUID]) {
        self.configuration = configuration
        self.conflictingGestureIDs = conflictingGestureIDs
    }
}

public enum SplitGestureConfigurationLoader {
    public static func merge(
        builtin: GestureConfiguration,
        custom: GestureConfiguration
    ) -> GestureConfigurationMergeResult {
        let builtinIDs = Set(builtin.gestures.map(\.id))
        let conflictingGestureIDs = custom.gestures
            .map(\.id)
            .filter { builtinIDs.contains($0) }
            .sorted { $0.uuidString < $1.uuidString }

        let taggedBuiltin = builtin.gestures.map { gesture -> GestureDefinition in
            var copy = gesture
            copy.source = .builtin
            return copy
        }
        let taggedCustom = custom.gestures.map { gesture -> GestureDefinition in
            var copy = gesture
            copy.source = .custom
            return copy
        }

        let configuration = GestureConfiguration(
            applicationBundleIdentifiers: custom.applicationBundleIdentifiers,
            gestures: taggedBuiltin + taggedCustom,
            customGestureSignatures: custom.customGestureSignatures
        )

        return GestureConfigurationMergeResult(
            configuration: configuration,
            conflictingGestureIDs: conflictingGestureIDs
        )
    }

    public static func bootstrapMissingFiles(
        builtinStore: GestureConfigurationStore,
        customStore: GestureConfigurationStore,
        fileManager: FileManager = .default
    ) throws {
        if !fileManager.fileExists(atPath: builtinStore.fileURL.path) {
            try builtinStore.save(BuiltInGestureSeeds.factoryBuiltinConfiguration())
        }
        if !fileManager.fileExists(atPath: customStore.fileURL.path) {
            try customStore.save(GestureConfiguration.emptyCustomTemplate)
        }
    }
}
