import Foundation

@main struct CustomSourceChecks {
    @MainActor static func main() throws {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }
        func rejects(_ operation: () throws -> Void, _ message: String) {
            do { try operation(); preconditionFailure(message) }
            catch { check(!error.localizedDescription.isEmpty, message) }
        }
        let domainCases = [
            ("  WWW.Example.com  ", "example.com"),
            ("https://www.Example.com/a?b=1#x", "example.com"),
            ("HTTP://blog.example.com:8080/path", "blog.example.com"),
            ("https://example.com./path", "example.com"),
            ("https://münich.example/article", "xn--mnich-kva.example")
        ]
        for (input, expected) in domainCases {
            let normalized = try SourceValidation.normalizeDomain(input)
            check(normalized == expected, "Alan adı normalleşmedi: \(input)")
        }
        for invalid in ["", "localhost", "file://example.com", "ftp://example.com", "javascript:example.com", "https://", "example.com/path", "example.com:123", "example.com?query", "example com", "https://ex ample.com", "https://user@example.com", "https://foo_bar.example", "https://-foo.example", "https://foo-.example", "https://foo..example", "https://127.0.0.1"] {
            rejects({ _ = try SourceValidation.normalizeDomain(invalid) }, "Geçersiz alan adı kabul edildi: \(invalid)")
        }
        let unique = try SourceValidation.normalizedDomains("www.example.com, example.com; sub.example.com\nhttps://another.example/page")
        check(unique == ["example.com", "another.example"], "Tekrarlanan/alt alan adları birleştirilmeli")
        let reduced = try SourceValidation.normalizedDomains("sub.example.com\nexample.com")
        check(reduced == ["example.com"], "Üst alan adı alt alan adlarını kapsamalı")
        let repeatedWWW = CustomSource(name: "İç Site", domains: [try SourceValidation.normalizeDomain("www.www.internal.example")])
        check(repeatedWWW.matches(host: "www.internal.example"), "Normalleşmiş www alt alan adı eşleşmeli")
        check(repeatedWWW.matches(host: "www.www.internal.example"), "İç içe www alt alan adı eşleşmeli")

        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("Kapsul-custom-source-checks-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let catalog = SourceCatalog(folder: scratch)
        check(catalog.customs.isEmpty, "Yeni katalog boş olmalı")
        let source = try catalog.add(name: "  Tasarım  ", domainsText: "https://www.example.com/article\nother.example")
        check(source.name == "Tasarım" && source.domains == ["example.com", "other.example"], "Kaynak girdisi normalleşmeli")
        for value in ["https://example.com/page", "http://blog.example.com", "https://www.example.com", "https://deep.blog.example.com:443/path", "https://other.example./x"] {
            check(catalog.customSource(for: value)?.id == source.id, "URL kaynağı eşleşmedi: \(value)")
        }
        for value in ["https://example.com.evil.example", "https://fakeexample.com", "file://example.com", "example.com", "example metin", "https://example.com@evil.example"] {
            check(catalog.customSource(for: value) == nil, "Sahte/salt metin kaynak eşleşmesi: \(value)")
        }
        for name in ClipSource.allCases.map(\.rawValue) + SourceValidation.reservedNames + ["tasarim", "TASARIM"] {
            rejects({ _ = try catalog.add(name: name, domainsText: "fresh.example") }, "Tekrarlanan ad kabul edildi: \(name)")
        }
        for name in ["", " \n ", String(repeating: "a", count: 61), "Yeni\nKaynak"] {
            rejects({ _ = try catalog.add(name: name, domainsText: "fresh.example") }, "Geçersiz ad kabul edildi")
        }
        for domain in ["sub.example.com", "other.example", "youtube.com", "www.linkedin.com", "social.medium.com", "gist.github.com"] {
            rejects({ _ = try catalog.add(name: "Yeni Kaynak", domainsText: domain) }, "Çakışan alan adı kabul edildi: \(domain)")
        }
        rejects({ _ = try catalog.add(name: "Boş", domainsText: " ,;\n") }, "Boş alan adı kabul edildi")
        check(catalog.customs == [source], "Başarısız eklemeler kataloğu değiştirmemeli")
        let reloaded = SourceCatalog(folder: scratch)
        check(reloaded.customs == [source], "Kaynaklar kimlikleriyle yeniden yüklenmeli")
        try reloaded.remove(source)
        check(reloaded.customs.isEmpty, "Kaynak silinmeli")
        check(SourceCatalog(folder: scratch).customs.isEmpty, "Silme kalıcı olmalı")
        // Parent/subdomain overlap must be rejected in either direction.
        let nested = try reloaded.add(name: "Blog", domainsText: "blog.fresh.example")
        rejects({ _ = try reloaded.add(name: "Ana Site", domainsText: "fresh.example") }, "Üst alan adı çakışması kabul edildi")
        try reloaded.remove(nested)
        let history = scratch.appendingPathComponent("history.json")
        try Data("existing clipboard history".utf8).write(to: history)
        let disposable = try reloaded.add(name: "Deneme", domainsText: "demo.example")
        try reloaded.remove(disposable)
        let keptHistory = try String(contentsOf: history, encoding: .utf8)
        check(keptHistory == "existing clipboard history", "Kaynak silme geçmişi etkilememeli")
        // An invalid catalog must be surfaced and preserved instead of being overwritten.
        let malformed = Data("broken JSON".utf8)
        let catalogFile = scratch.appendingPathComponent("custom-sources.json")
        try malformed.write(to: catalogFile)
        let brokenCatalog = SourceCatalog(folder: scratch)
        check(brokenCatalog.errorMessage != nil, "Yükleme hatası görünmeli")
        rejects({ _ = try brokenCatalog.add(name: "Kaynak", domainsText: "fresh.example") }, "Bozuk katalog üzerine yazılmamalı")
        let preserved = try Data(contentsOf: catalogFile)
        check(preserved == malformed, "Bozuk kaynak dosyası korunmalı")
        let blockedFolder = scratch.appendingPathComponent("not-a-directory")
        try Data("file".utf8).write(to: blockedFolder)
        let blocked = SourceCatalog(folder: blockedFolder)
        rejects({ _ = try blocked.add(name: "Kaynak", domainsText: "fresh.example") }, "Yazma hatası fırlatılmalı")
        check(blocked.customs.isEmpty && blocked.errorMessage != nil, "Yazma hatasında katalog değişmemeli")
        print("\(checks) özel kaynak kontrolü geçti; testler geçici klasörde çalıştı.")
    }
}
