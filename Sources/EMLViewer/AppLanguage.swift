import Foundation
import SwiftUI
import EMLCore

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case italian

    var id: String { rawValue }

    /// Short picker label (always bilingual-recognizable).
    var pickerLabel: String {
        switch self {
        case .system: return L10n.t(.languageSystem)
        case .english: return "English"
        case .italian: return "Italiano"
        }
    }

    static let userDefaultsKey = "it.zenaconsult.zenaemlviewer.language"

    static func load() -> AppLanguage {
        let raw = UserDefaults.standard.string(forKey: userDefaultsKey) ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: raw) ?? .system
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.userDefaultsKey)
    }

    /// Concrete language used for UI and PDF (never `.system`).
    var resolved: ContentLanguage {
        switch self {
        case .english: return .english
        case .italian: return .italian
        case .system: return ContentLanguage.systemPreferred
        }
    }
}
