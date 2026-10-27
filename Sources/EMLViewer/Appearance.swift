import SwiftUI
import AppKit

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    static let userDefaultsKey = "it.zenaconsult.zenaemlviewer.appearance"

    static func load() -> AppearanceMode {
        let raw = UserDefaults.standard.string(forKey: userDefaultsKey) ?? AppearanceMode.system.rawValue
        return AppearanceMode(rawValue: raw) ?? .system
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.userDefaultsKey)
    }

    func applyToApp() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light:  NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
