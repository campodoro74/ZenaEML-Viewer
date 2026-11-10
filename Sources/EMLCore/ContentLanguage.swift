import Foundation

/// Language used for generated PDF / HTML labels (English or Italian).
public enum ContentLanguage: String, Sendable, CaseIterable {
    case english
    case italian

    public static var systemPreferred: ContentLanguage {
        let codes = Locale.preferredLanguages.map { $0.lowercased() }
        if codes.contains(where: { $0.hasPrefix("it") }) {
            return .italian
        }
        return .english
    }

    public var htmlLang: String {
        switch self {
        case .english: return "en"
        case .italian: return "it"
        }
    }
}
