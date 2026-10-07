import Foundation
import Combine

struct CustomSource: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let domains: [String]

    init(id: UUID = UUID(), name: String, domains: [String]) {
        self.id = id
        self.name = name
        self.domains = domains
    }

    func matches(host: String) -> Bool {
        let normalized = SourceValidation.canonicalHost(host)
        return domains.contains { SourceValidation.contains(host: normalized, domain: $0) }
    }
}

enum SourceCatalogError: LocalizedError {
    case invalidName
    case duplicateName(String)
    case missingDomain
    case invalidDomain(String)
    case domainConflict(String, String)
    case persistence(String)
    case unreadableCatalog(String)

    var errorDescription: String? {
        switch self {
        case .invalidName: return L10n.text("Kaynak adı 1–60 karakter olmalı ve tek satırda yazılmalı.")
        case .duplicateName(let name): return L10n.text("“%@” adı zaten kullanılıyor. Başka bir kaynak adı seçin.", name)
        case .missingDomain: return L10n.text("En az bir alan adı veya web bağlantısı ekleyin.")
        case .invalidDomain(let value): return L10n.text("“%@” geçerli bir alan adı veya HTTP/HTTPS bağlantısı değil. Örnek: example.com", value)
        case .domainConflict(let domain, let name): return L10n.text("“%@” zaten “%@” kaynağına ait.", domain, name)
        case .persistence(let reason): return L10n.text("Kaynaklar kaydedilemedi: %@", reason)
        case .unreadableCatalog(let reason): return L10n.text("Kaynak dosyası okunamadığı için değişiklik kaydedilemiyor: %@", reason)
        }
    }
}

// Shared, side-effect-free validation keeps saved sources and settings input consistent.
enum SourceValidation {
    static let reservedNames = ["Tümü", "Sabitlenenler", "Metin", "Bağlantı", "Görsel", "Ekran görüntüsü", "Dosya"]

    static func canonicalName(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "ı", with: "i")
    }

    static func canonicalHost(_ value: String) -> String {
        var host = value.lowercased()
        if host.hasSuffix(".") { host.removeLast() }
        return host
    }

    static func contains(host: String, domain: String) -> Bool {
        host == domain || host.hasSuffix("." + domain)
    }

    static func overlap(_ first: String, _ second: String) -> Bool {
        contains(host: first, domain: second) || contains(host: second, domain: first)
    }

    static func normalizeDomain(_ input: String) throws -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) }) else {
            throw SourceCatalogError.invalidDomain(value)
        }
        var host: String
        if value.contains("://") {
            guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  let websiteHost = url.host, url.user == nil, url.password == nil else {
                throw SourceCatalogError.invalidDomain(value)
            }
            host = canonicalHost(websiteHost)
        } else {
            // Bare domains cannot contain a path, port, credentials, or a URL query.
            guard !value.contains(where: { "/\\:@?#%".contains($0) }), let url = URL(string: "https://" + value), let websiteHost = url.host else {
                throw SourceCatalogError.invalidDomain(value)
            }
            host = canonicalHost(websiteHost)
        }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        guard host.utf8.count <= 253, labels.count >= 2,
              labels.allSatisfy({ label in
                  !label.isEmpty && label.utf8.count <= 63 && label.first != "-" && label.last != "-" &&
                  label.unicodeScalars.allSatisfy { allowed.contains($0) }
              }), host.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) else {
            throw SourceCatalogError.invalidDomain(value)
        }
        return host
    }

    static func normalizedDomains(_ text: String) throws -> [String] {
        let tokens = text.components(separatedBy: CharacterSet(charactersIn: ",;\n\r"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !tokens.isEmpty else { throw SourceCatalogError.missingDomain }
        var domains: [String] = []
        for token in tokens {
            let domain = try normalizeDomain(token)
            if domains.contains(where: { contains(host: domain, domain: $0) }) { continue }
            // A parent domain already covers any subdomains entered on the same source.
            domains.removeAll { contains(host: $0, domain: domain) }
            domains.append(domain)
        }
        return domains
    }

    static func validate(name inputName: String, domainsText: String, existing: [CustomSource], id: UUID = UUID()) throws -> CustomSource {
        let name = inputName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...60).contains(name.count), !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw SourceCatalogError.invalidName
        }
        let normalizedName = canonicalName(name)
        let usedNames = ClipSource.allCases.map(\.rawValue) + reservedNames + existing.map(\.name)
        guard !usedNames.contains(where: { canonicalName($0) == normalizedName }) else {
            throw SourceCatalogError.duplicateName(name)
        }
        let domains = try normalizedDomains(domainsText)
        for domain in domains {
            if let builtin = ClipSource.allCases.first(where: { $0.domains.contains { overlap(domain, $0) } }) {
                throw SourceCatalogError.domainConflict(domain, builtin.rawValue)
            }
            if let custom = existing.first(where: { $0.domains.contains { overlap(domain, $0) } }) {
                throw SourceCatalogError.domainConflict(domain, custom.name)
            }
        }
        return CustomSource(id: id, name: name, domains: domains)
    }
}

@MainActor final class SourceCatalog: ObservableObject {
    @Published private(set) var customs: [CustomSource] = []
    @Published var errorMessage: String?
    private let folder: URL
    private var loadingFailure: String?
    private var fileURL: URL { folder.appendingPathComponent("custom-sources.json") }

    init(folder: URL? = nil) {
        self.folder = folder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CopyGlass", isDirectory: true)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let saved = try JSONDecoder().decode([CustomSource].self, from: Data(contentsOf: fileURL))
            var validated: [CustomSource] = []
            for source in saved {
                guard !validated.contains(where: { $0.id == source.id }) else {
                    throw SourceCatalogError.persistence(L10n.text("Tekrarlanan kaynak kimliği bulundu."))
                }
                validated.append(try SourceValidation.validate(name: source.name, domainsText: source.domains.joined(separator: "\n"), existing: validated, id: source.id))
            }
            customs = validated
        } catch {
            loadingFailure = error.localizedDescription
            errorMessage = L10n.text("Kaynaklar yüklenemedi: %@", error.localizedDescription)
        }
    }

    @discardableResult func add(name: String, domainsText: String) throws -> CustomSource {
        do {
            let source = try SourceValidation.validate(name: name, domainsText: domainsText, existing: customs)
            let updated = customs + [source]
            try persist(updated)
            customs = updated
            errorMessage = nil
            return source
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func remove(_ source: CustomSource) throws {
        guard customs.contains(where: { $0.id == source.id }) else { return }
        do {
            let updated = customs.filter { $0.id != source.id }
            try persist(updated)
            customs = updated
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func customSource(for value: String) -> CustomSource? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), let host = url.host else { return nil }
        return customs.first { $0.matches(host: host) }
    }

    private func persist(_ sources: [CustomSource]) throws {
        if let loadingFailure { throw SourceCatalogError.unreadableCatalog(loadingFailure) }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(sources).write(to: fileURL, options: .atomic)
        } catch {
            throw SourceCatalogError.persistence(error.localizedDescription)
        }
    }
}
