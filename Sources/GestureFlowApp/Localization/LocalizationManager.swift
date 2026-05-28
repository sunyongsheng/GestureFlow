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
            .joined(separator: language == .zhHans ? "、" : ", ")
    }

    func localizedGestureDisplayName(id: UUID, storedName: String) -> String {
        if id == GestureConfiguration.closeWindowGestureID {
            return string(.builtInCloseWindowGestureName)
        }
        return storedName
    }

    func localizedGestureDisplayName(_ gesture: GestureDefinition) -> String {
        localizedGestureDisplayName(id: gesture.id, storedName: gesture.name)
    }
}

enum AppServices {
    static var localization = LocalizationManager()
}
