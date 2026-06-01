import Combine
import Foundation
import GestureFlowCore

final class LocalizationManager: ObservableObject {
    @Published private(set) var language: AppLanguage

    init(language: AppLanguage = .zhHans) {
        self.language = language
    }

    func setLanguage(_ language: AppLanguage) {
        guard self.language != language else { return }
        self.language = language
    }

    func string(_ key: L10nKey) -> String {
        L10nTables.table(for: language)[key] ?? key.rawValue
    }

    func format(_ key: L10nKey, _ arguments: CVarArg...) -> String {
        String(format: string(key), arguments: arguments)
    }

    func message(for error: ConfigurationDirectoryRelocationError) -> String {
        switch error {
        case .invalidPath:
            return string(.errorConfigDirectoryInvalidPath)
        case .notADirectory:
            return string(.errorConfigDirectoryNotADirectory)
        case .directoryNotWritable:
            return string(.errorConfigDirectoryNotWritable)
        case .sameAsCurrentDirectory:
            return string(.errorConfigDirectoryUnchanged)
        case .copyFailed:
            return string(.errorConfigDirectoryCopyFailed)
        case .configurationDirectoryWriteFailed:
            return string(.errorConfigDirectoryWriteFailed)
        case .invalidConfigurationContent:
            return string(.errorConfigDirectoryInvalidContent)
        }
    }

    func localizedDisplayName(for target: GestureTargetApplication) -> String {
        switch target {
        case .foreground:
            return string(.gestureTargetForeground)
        case .underMouse:
            return string(.gestureTargetUnderMouse)
        }
    }

    func localizedDisplayName(for direction: GestureDirection) -> String {
        switch direction {
        case .up:
            return string(.gestureDirectionUp)
        case .down:
            return string(.gestureDirectionDown)
        case .left:
            return string(.gestureDirectionLeft)
        case .right:
            return string(.gestureDirectionRight)
        }
    }

    func localizedDisplayName(for signature: GestureSignature) -> String {
        signature.tokens
            .map { localizedDisplayName(for: $0) }
            .joined(separator: gestureSignatureSeparator)
    }

    private var gestureSignatureSeparator: String {
        switch language {
        case .zhHans, .zhHant, .ja, .ko:
            return "、"
        case .en, .hi, .es, .fr:
            return ", "
        }
    }

    private static let builtInNameKeys: [UUID: L10nKey] = [
        BuiltInGestureSeeds.closeWindowID: .builtInCloseWindowGestureName,
        BuiltInGestureSeeds.backID: .builtInBackGestureName,
        BuiltInGestureSeeds.forwardID: .builtInForwardGestureName,
        BuiltInGestureSeeds.newTabID: .builtInNewTabGestureName,
        BuiltInGestureSeeds.refreshID: .builtInRefreshGestureName,
        BuiltInGestureSeeds.minimizeID: .builtInMinimizeGestureName,
        BuiltInGestureSeeds.undoID: .builtInUndoGestureName,
        BuiltInGestureSeeds.redoID: .builtInRedoGestureName,
        BuiltInGestureSeeds.copyID: .builtInCopyGestureName,
        BuiltInGestureSeeds.pasteID: .builtInPasteGestureName,
        BuiltInGestureSeeds.findID: .builtInFindGestureName,
        BuiltInGestureSeeds.quitAppID: .builtInQuitAppGestureName,
        BuiltInGestureSeeds.chromeScrollToTopID: .builtInChromeScrollToTopGestureName,
        BuiltInGestureSeeds.chromeScrollToBottomID: .builtInChromeScrollToBottomGestureName,
        BuiltInGestureSeeds.chromeReopenClosedTabID: .builtInChromeReopenClosedTabGestureName,
        BuiltInGestureSeeds.chromeFocusAddressBarID: .builtInChromeFocusAddressBarGestureName,
        BuiltInGestureSeeds.finderParentFolderID: .builtInFinderParentFolderGestureName,
        BuiltInGestureSeeds.finderOpenItemID: .builtInFinderOpenItemGestureName,
        BuiltInGestureSeeds.finderNewFolderID: .builtInFinderNewFolderGestureName,
    ]

    func localizedGestureDisplayName(id: UUID, storedName: String?) -> String {
        if let storedName, !storedName.isEmpty {
            return storedName
        }
        if let key = Self.builtInNameKeys[id] {
            return string(key)
        }
        return storedName ?? ""
    }

    func localizedGestureDisplayName(_ gesture: GestureDefinition) -> String {
        localizedGestureDisplayName(id: gesture.id, storedName: gesture.name)
    }
}

enum AppServices {
    static var localization = LocalizationManager()
}
