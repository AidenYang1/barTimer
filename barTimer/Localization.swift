import Foundation

enum AppLanguage: String, CaseIterable {
    case system
    case zhHans = "zh-Hans"
    case en = "en"
    
    static let storageKey = "appLanguage"
    
    static var current: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: raw) ?? .system
    }
    
    static var currentLocale: Locale {
        switch current {
        case .system:
            return Locale.current
        case .zhHans:
            return Locale(identifier: "zh-Hans")
        case .en:
            return Locale(identifier: "en")
        }
    }
}

