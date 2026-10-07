import Foundation

@main struct LocalizationChecks {
    @MainActor static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let catalog = try JSONDecoder().decode([String: [String: String]].self, from: Data(contentsOf: url))
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }
        let reference = catalog["tr"]!
        check(Set(catalog.keys) == Set(AppLanguage.allCases.map(\.rawValue)), "Dil listesi ile çeviriler eşleşmeli")
        for language in AppLanguage.allCases {
            let table = catalog[language.rawValue]!
            check(Set(table.keys) == Set(reference.keys), "Eksik çeviri: \(language)")
            for (key, value) in table {
                check(!value.isEmpty, "Boş çeviri: \(key)")
                check(value.components(separatedBy: "%@").count == key.components(separatedBy: "%@").count,
                      "Biçim alanı değişti: \(language) \(key)")
            }
            let inserted = L10n.translation("“%@” zaten “%@” kaynağına ait.", language: language,
                                           arguments: ["résumé.example", "My 100% source"], catalog: catalog)
            check(inserted.contains("résumé.example") && inserted.contains("My 100% source") && !inserted.contains("%@"),
                  "Kaynak değerleri güvenli ve değişmeden yerleştirilmeli")
        }
        check(L10n.translation("Missing", language: .french, catalog: catalog) == "Missing", "Eksik anahtar güvenli geri dönmeli")
        check(L10n.translation("Fallback", language: .spanish, catalog: ["tr": ["Fallback": "Türkçe"]]) == "Türkçe",
              "Eksik dil çevirisi Türkçeye dönmeli")
        let expected = ["tr": "Ayarlar", "en": "Settings", "fr": "Réglages", "de": "Einstellungen", "es": "Ajustes"]
        for language in AppLanguage.allCases {
            check(L10n.translation("Ayarlar", language: language, catalog: catalog) == expected[language.rawValue],
                  "Dil seçimi doğru tabloyu kullanmalı")
        }
        let suite = "Kapsul.LocalizationChecks." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppLocalization(defaults: defaults)
        check(settings.language == .turkish, "Mevcut kullanıcılar Türkçe ile başlamalı")
        for language in AppLanguage.allCases {
            settings.language = language
            check(defaults.string(forKey: "appLanguage") == language.rawValue, "Tercih kalıcı kaydedilmeli")
            check(defaults.stringArray(forKey: "AppleLanguages") == [language.rawValue], "Yerel macOS menü dili tercih edilmeli")
            check(AppLocalization(defaults: defaults).language == language, "Yeniden açılış tercihi yüklemeli")
        }
        defaults.set("unknown", forKey: "appLanguage")
        check(AppLocalization(defaults: defaults).language == .turkish, "Geçersiz tercih Türkçeye dönmeli")
        print("\(checks) dil kapsamı, format ve tercih saklama kontrolü geçti.")
    }
}
