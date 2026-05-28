import Foundation
import GestureFlowCore

final class GestureConfigurationService {
    private(set) var builtinStore: GestureConfigurationStore
    private(set) var customStore: GestureConfigurationStore
    var configuration: GestureConfiguration
    private(set) var conflictingGestureIDs: [UUID] = []

    init(
        builtinStore: GestureConfigurationStore? = nil,
        customStore: GestureConfigurationStore? = nil
    ) {
        let resolver = ConfigurationDirectoryResolver.bootstrap()
        self.builtinStore = builtinStore
            ?? GestureConfigurationStore(fileURL: resolver.gesturesBuiltinFileURL)
        self.customStore = customStore
            ?? GestureConfigurationStore(fileURL: resolver.gesturesCustomFileURL)
        self.configuration = .emptyCustomTemplate
        load()
    }

    func replaceStores(builtinStore: GestureConfigurationStore, customStore: GestureConfigurationStore) {
        self.builtinStore = builtinStore
        self.customStore = customStore
        load()
    }

    func load() {
        do {
            try SplitGestureConfigurationLoader.bootstrapMissingFiles(
                builtinStore: builtinStore,
                customStore: customStore
            )
        } catch {
            // Settings surfaces save errors through SettingsViewModel.
        }

        let builtin = (try? builtinStore.load()) ?? BuiltInGestureSeeds.factoryBuiltinConfiguration()
        let custom = (try? customStore.load()) ?? .emptyCustomTemplate
        applyMerge(builtin: builtin, custom: custom)
    }

    func save() throws {
        let builtinGestures = configuration.gestures.filter { $0.source == .builtin }
        let customGestures = configuration.gestures.filter { $0.source == .custom }

        var builtinConfiguration = try builtinStore.load()
        builtinConfiguration.gestures = builtinGestures
        try builtinStore.save(builtinConfiguration)

        let customConfiguration = GestureConfiguration(
            applicationBundleIdentifiers: configuration.applicationBundleIdentifiers,
            gestures: customGestures,
            customGestureSignatures: configuration.customGestureSignatures
        )
        try customStore.save(customConfiguration)

        applyMerge(builtin: builtinConfiguration, custom: customConfiguration)
    }

    func restoreDefaults() throws {
        try builtinStore.save(BuiltInGestureSeeds.factoryBuiltinConfiguration())
        try customStore.save(GestureConfiguration.emptyCustomTemplate)
        load()
    }

    func persistAfterMutation(_ mutation: (inout GestureConfiguration) -> Void) {
        mutation(&configuration)
        do {
            try save()
        } catch {
            // Settings surfaces save errors through SettingsViewModel.
        }
    }

    private func applyMerge(builtin: GestureConfiguration, custom: GestureConfiguration) {
        let result = SplitGestureConfigurationLoader.merge(builtin: builtin, custom: custom)
        configuration = result.configuration
        conflictingGestureIDs = result.conflictingGestureIDs
    }
}
