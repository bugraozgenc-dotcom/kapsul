import SwiftUI
import Foundation
 enum ClipKind: String, Codable, CaseIterable {
    case text = "Metin", url = "Bağlantı", instagram = "Instagram", image = "Görsel", screenshot = "Ekran görüntüsü", file = "Dosya"
    var icon: String { switch self { case .text: return "text.alignleft"; case .url: return "link"; case .instagram: return "camera"; case .image: return "photo"; case .screenshot: return "viewfinder"; case .file: return "doc" } }
    var color: Color { switch self { case .text: return .purple; case .url: return .blue; case .instagram: return .pink; case .image: return .orange; case .screenshot: return .teal; case .file: return .green } }
 }
 enum Retention: String, Codable, CaseIterable {
    case month = "1 ay", quarter = "3 ay", year = "1 yıl", forever = "Sonsuz"
    var months: Int? { switch self { case .month: return 1; case .quarter: return 3; case .year: return 12; case .forever: return nil } }
 }
 struct Clip: Identifiable, Codable {
    var id = UUID()
    var kind: ClipKind
    var value: String
    var date = Date()
    var pinned = false
    var asset: String? = nil
    var source: ClipSource? = nil
    var sourceBundleID: String? = nil
    var sourceAppName: String? = nil
    var tags: [String]? = nil
    var collectionIDs: [UUID]? = nil
    var extractedText: String? = nil
    var richText: Data? = nil
    var searchableText: String { ([value, extractedText ?? "", sourceAppName ?? ""] + (tags ?? [])).joined(separator: "\n") }
    var groupSource: ClipSource? { source ?? ClipSource.fromURL(value) ?? (kind == .instagram ? .instagram : nil) }
    var webURL: URL? { guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }; return url }
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "dd.MM.yyyy • HH:mm"
        return formatter
    }()
    var timestamp: String { Self.timestampFormatter.string(from: date) }
    var title: String {
        if kind == .screenshot { return L10n.text("Ekran görüntüsü") }; if kind == .image { return L10n.text("Kopyalanan görsel") }
        if kind == .file { return URL(fileURLWithPath: value).lastPathComponent }
        if kind == .instagram, let url = URL(string: value) { return url.path.isEmpty ? "Instagram" : url.path }
        if kind == .url { return URL(string: value)?.host ?? value }
        return String(value.prefix(90))
    }
 }

struct ClipCollection: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
}

struct HistoryDocument: Codable {
    var version = 1
    var clips: [Clip]
    var collections: [ClipCollection]
}

struct ExcludedApplication: Codable, Identifiable, Equatable {
    var id: String // bundle identifier
    var name: String
}
