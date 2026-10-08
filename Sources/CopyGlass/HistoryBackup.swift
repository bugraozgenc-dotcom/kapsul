import Foundation

struct HistoryBackup: Codable {
    var format = "KapsulBackup"
    var version = 1
    var createdAt = Date()
    var history: HistoryDocument
    var assets: [String: Data]

    static let maximumFileSize = 256 * 1024 * 1024

    func validate() throws {
        guard format == "KapsulBackup", version == 1, history.version == 1,
              history.clips.count <= 100_000, history.collections.count <= 1_000,
              Set(history.clips.map(\.id)).count == history.clips.count,
              Set(history.collections.map(\.id)).count == history.collections.count else {
            throw BackupError.invalid
        }
        let collectionIDs = Set(history.collections.map(\.id))
        guard history.collections.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.name.count <= 60 }) else { throw BackupError.invalid }
        var total = 0
        for clip in history.clips {
            guard Set(clip.collectionIDs ?? []).isSubset(of: collectionIDs),
                  (clip.tags ?? []).count <= 50,
                  (clip.tags ?? []).allSatisfy({ !$0.isEmpty && $0.count <= 40 }) else { throw BackupError.invalid }
            if let asset = clip.asset {
                guard Self.validAssetName(asset), let data = assets[asset], !data.isEmpty,
                      data.count <= 64 * 1024 * 1024,
                      data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]) else { throw BackupError.invalid }
            } else if clip.kind == .image || clip.kind == .screenshot { throw BackupError.invalid }
        }
        let referenced = Set(history.clips.compactMap(\.asset))
        guard referenced == Set(assets.keys) else { throw BackupError.invalid }
        for data in assets.values { total += data.count }
        guard total <= 160 * 1024 * 1024 else { throw BackupError.tooLarge }
    }

    static func validAssetName(_ name: String) -> Bool {
        name.hasSuffix(".png") && UUID(uuidString: String(name.dropLast(4))) != nil
    }

    static func read(_ url: URL) throws -> HistoryBackup {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= maximumFileSize else { throw BackupError.tooLarge }
        let result = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        try result.validate()
        return result
    }
}

enum BackupError: LocalizedError {
    case invalid, tooLarge
    var errorDescription: String? {
        L10n.text(self == .invalid ? "Yedek dosyası geçersiz veya eksik." : "Yedek dosyası çok büyük (en fazla 256 MB).")
    }
}
