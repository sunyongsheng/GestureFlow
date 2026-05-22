import ApplicationServices
import Foundation

final class PermissionService {
    private let trustCheck: () -> Bool
    private let permissionPrompt: () -> Void

    var isAccessibilityTrusted: Bool {
        trustCheck()
    }

    init(
        trustCheck: @escaping () -> Bool = { AXIsProcessTrusted() },
        permissionPrompt: @escaping () -> Void = {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options = [key: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    ) {
        self.trustCheck = trustCheck
        self.permissionPrompt = permissionPrompt
    }

    func promptForAccessibilityPermission() {
        permissionPrompt()
    }

    @discardableResult
    func refreshAccessibilityTrust() -> Bool {
        trustCheck()
    }
}
