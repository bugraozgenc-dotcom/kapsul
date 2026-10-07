import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case system = "Sistem", light = "Açık", dark = "Koyu"
    var localizedName: String { L10n.text(rawValue) }
    var colorScheme: ColorScheme? {
        switch self { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }
}
