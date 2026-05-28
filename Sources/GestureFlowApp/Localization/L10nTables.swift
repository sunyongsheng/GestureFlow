import Foundation
import GestureFlowCore

enum L10nTables {
    static func table(for language: AppLanguage) -> [L10nKey: String] {
        switch language {
        case .zhHans:
            return L10nStringsZhHans.table
        case .en:
            return L10nStringsEn.table
        }
    }
}
