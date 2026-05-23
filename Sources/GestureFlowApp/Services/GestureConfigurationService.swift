import Foundation
import GestureFlowCore

final class GestureConfigurationService {
    private let store: GestureConfigurationStore
    var configuration: GestureConfiguration

    init(store: GestureConfigurationStore = GestureConfigurationStore()) {
        self.store = store
        self.configuration = GestureConfiguration.defaultTemplate
    }

    func load() {
        let loaded = (try? store.load()) ?? GestureConfiguration.defaultTemplate
        configuration = loaded

        if !FileManager.default.fileExists(atPath: store.fileURL.path) {
            try? store.save(configuration)
        }
    }

    func save() throws {
        try store.save(configuration)
    }

    func persistAfterMutation(_ mutation: (inout GestureConfiguration) -> Void) {
        mutation(&configuration)
        do {
            try save()
        } catch {
            // Settings surfaces save errors through SettingsViewModel.
        }
    }
}
