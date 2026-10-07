import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Codable {
    case turkish = "tr", english = "en", french = "fr", german = "de", spanish = "es"

    var nativeName: String {
        switch self {
        case .turkish: return "Türkçe"
        case .english: return "English"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .spanish: return "Español"
        }
    }
    var locale: Locale { Locale(identifier: rawValue) }
    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "tr") ?? .turkish
    }
}

enum L10n {
    static let catalog: [String: [String: String]] = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "Localizations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let values = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return [:] }
        return values
    }()

    static func text(_ key: String, _ arguments: String...) -> String {
        translation(key, language: .current, arguments: arguments)
    }

    static func translation(_ key: String, language: AppLanguage, arguments: [String] = [],
                            catalog: [String: [String: String]] = catalog) -> String {
        let value = catalog[language.rawValue]?[key] ?? catalog["tr"]?[key] ?? key
        guard !arguments.isEmpty else { return value }
        return String(format: value, locale: language.locale, arguments: arguments.map { $0 as CVarArg })
    }
}

@MainActor final class AppLocalization: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: "appLanguage")
            defaults.set([language.rawValue], forKey: "AppleLanguages")
        }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = AppLanguage(rawValue: defaults.string(forKey: "appLanguage") ?? "tr") ?? .turkish
    }

    func text(_ key: String, _ arguments: String...) -> String {
        L10n.translation(key, language: language, arguments: arguments)
    }
}
