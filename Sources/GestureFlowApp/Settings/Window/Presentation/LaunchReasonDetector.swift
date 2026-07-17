import AppKit
import Carbon

protocol LaunchReasonDetecting {
    var wasLaunchedAtLogin: Bool { get }
}

struct LaunchReasonDetector: LaunchReasonDetecting {
    private let currentAppleEvent: () -> NSAppleEventDescriptor?

    init(
        currentAppleEvent: @escaping () -> NSAppleEventDescriptor? = {
            NSAppleEventManager.shared().currentAppleEvent
        }
    ) {
        self.currentAppleEvent = currentAppleEvent
    }

    var wasLaunchedAtLogin: Bool {
        Self.isLaunchedAtLogin(event: currentAppleEvent())
    }

    static func isLaunchedAtLogin(event: NSAppleEventDescriptor?) -> Bool {
        guard let event else { return false }
        return event.eventID == AEEventID(kAEOpenApplication)
            && event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
                == OSType(keyAELaunchedAsLogInItem)
    }
}
