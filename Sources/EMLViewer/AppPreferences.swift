import Foundation
import SwiftData

@Model
final class AppPreferences {
    var appearanceRaw: String = AppearanceMode.system.rawValue
    var languageRaw: String = AppLanguage.system.rawValue
    var windowWidth: Double = 900
    var windowHeight: Double = 640

    init() {}

    var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }

    var language: AppLanguage {
        get { AppLanguage(rawValue: languageRaw) ?? .system }
        set { languageRaw = newValue.rawValue }
    }
}
