import Foundation
import GestureFlowCore

enum L10nTables {
    static func table(for language: AppLanguage) -> [L10nKey: String] {
        switch language {
        case .zhHans:
            return L10nStringsZhHans.table
        case .zhHant:
            return L10nStringsZhHant.table
        case .en:
            return L10nStringsEn.table
        case .ja:
            return L10nStringsJa.table
        case .ko:
            return L10nStringsKo.table
        case .hi:
            return L10nStringsHi.table
        case .es:
            return L10nStringsEs.table
        case .fr:
            return L10nStringsFr.table
        }
    }
}
