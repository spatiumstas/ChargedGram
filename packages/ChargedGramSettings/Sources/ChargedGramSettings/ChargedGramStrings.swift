import Foundation

public enum ChargedGramStrings {
    private static let english = Bundle(path: Bundle.module.path(forResource: "en", ofType: "lproj")!)!
    private static let russian = Bundle(path: Bundle.module.path(forResource: "ru", ofType: "lproj")!)!

    public static func text(_ key: String, languageCode: String, fallbackLanguageCode: String? = nil) -> String {
        for code in [languageCode, fallbackLanguageCode].compactMap({ $0 }) {
            switch code.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first {
            case "ru":
                return russian.localizedString(forKey: key, value: english.localizedString(forKey: key, value: nil, table: nil), table: nil)
            case "en":
                return english.localizedString(forKey: key, value: nil, table: nil)
            default:
                break
            }
        }
        return english.localizedString(forKey: key, value: nil, table: nil)
    }
}
