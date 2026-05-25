import Foundation
import ServiceManagement

protocol LaunchAtLoginControlling {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

final class LaunchAtLoginService: LaunchAtLoginControlling {
    private let statusProvider: () -> SMAppService.Status
    private let register: () throws -> Void
    private let unregister: () throws -> Void

    var isEnabled: Bool {
        statusProvider() == .enabled
    }

    init(
        statusProvider: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
        register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
        unregister: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() }
    ) {
        self.statusProvider = statusProvider
        self.register = register
        self.unregister = unregister
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try register()
        } else {
            try unregister()
        }
    }
}
