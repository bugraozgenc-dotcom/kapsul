import AppKit
import Foundation

@main struct LibraryChecks {
    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Kapsul.LibraryChecks." + UUID().uuidString)
        let suite = "Kapsul.LibraryChecks." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let board = NSPasteboard(name: .init(suite))
        defaults.set(Retention.forever.rawValue, forKey: "retention")
        defaults.set(false, forKey: "automaticOCR")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suite)
            board.releaseGlobally()
        }
        var count = 0
        func check(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(), message); count += 1 }
        func rejected(_ action: () throws -> Void, _ message: String) { do { try action(); preconditionFailure(message) } catch { count += 1 } }
        let original = Clip(kind: .text, value: "Legacy text")
        // A genuine old history entry has no new optional keys.
        let legacy: [[String: Any]] = [["id": original.id.uuidString, "kind": "Metin", "value": "Legacy text", "date": original.date.timeIntervalSinceReferenceDate, "pinned": false]]
        try JSONSerialization.data(withJSONObject: legacy).write(to: root.appendingPathComponent("history.json"))
        var active = ExcludedApplication(id: "test.allowed", name: "Allowed App")
        let store = ClipboardStore(folder: root, defaults: defaults, pasteboard: board, monitoring: false, applicationProvider: { active })
        check(store.clips.count == 1 && store.clips[0].tags == nil, "Legacy migration retains the original entry")
        check(store.addCollection("Work"), "Collection creation")
        check(!store.addCollection("work"), "Duplicate collection rejected")
        store.error = nil
        let collection = store.collections[0]
        store.updateMetadata(store.clips[0], tags: "Design, design, Research", collectionIDs: [collection.id])
        check(store.clips[0].tags == ["Design", "Research"], "Tags deduplicate")
        check(store.clips[0].searchableText.contains("Research"), "Tags searchable")
        let saved = ClipboardStore(folder: root, defaults: defaults, pasteboard: board, monitoring: false)
        check(saved.collections == store.collections && saved.clips[0].collectionIDs == [collection.id], "Metadata persists after reopening")

        let rich = try NSAttributedString(string: "Rich text", attributes: [.font: NSFont.boldSystemFont(ofSize: 18)]).data(from: NSRange(location: 0, length: 9), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        board.clearContents(); board.setString("Rich text", forType: .string); board.setData(rich, forType: .rtf)
        store.poll()
        let captured = store.clips[0]
        check(captured.richText == rich && captured.sourceBundleID == "test.allowed", "Capture rich text and source app")
        check(store.copy(captured), "Normal copy")
        check(board.data(forType: .rtf) == rich, "Normal copy preserves RTF")
        check(store.copy(captured, plainText: true), "Plain copy")
        check(board.string(forType: .string) == "Rich text" && board.data(forType: .rtf) == nil, "Plain copy removes formatting")
        let beforeSelfCopy = store.clips.count; store.poll()
        check(store.clips.count == beforeSelfCopy, "Self copies aren't captured again")

        store.excludedApps = [ExcludedApplication(id: "test.blocked", name: "Blocked")]
        active.id = "test.blocked"
        board.clearContents(); board.setString("Do not store", forType: .string); store.poll()
        check(!store.clips.contains { $0.value == "Do not store" }, "Excluded application does not enter history")
        active.id = "test.allowed"; store.poll()
        check(!store.clips.contains { $0.value == "Do not store" }, "Excluded clipboard is consumed and never recorded after switching apps")
        board.clearContents(); board.setString("Secret", forType: .string); board.setString("1", forType: .init("org.nspasteboard.ConcealedType")); store.poll()
        check(!store.clips.contains { $0.value == "Secret" }, "Private pasteboard remains excluded")
        let reopened = ClipboardStore(folder: root, defaults: defaults, pasteboard: board, monitoring: false)
        check(reopened.isExcluded("test.blocked"), "App exclusion persists")

        let second = Clip(kind: .url, value: "https://example.com")
        store.add(second)
        let ids: Set<UUID> = [original.id, second.id]
        store.pinMany(ids)
        check(store.clips.filter { ids.contains($0.id) }.allSatisfy(\.pinned), "Bulk pin")
        store.pinMany(ids)
        check(store.clips.filter { ids.contains($0.id) }.allSatisfy { !$0.pinned }, "Bulk unpin")
        store.assign(ids, to: collection)
        check(store.clips.filter { ids.contains($0.id) }.allSatisfy { $0.collectionIDs?.contains(collection.id) == true }, "Bulk collection assignment")
        check(store.copyMany(ids), "Bulk text copy")
        check(board.string(forType: .string)?.contains("Legacy text") == true && board.string(forType: .string)?.contains("https://example.com") == true, "Bulk copy includes both entries")

        // Draw a known local OCR fixture; never inspect the user's screenshots.
        let image = NSImage(size: NSSize(width: 1000, height: 260))
        image.lockFocus()
        NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 1000, height: 260).fill()
        ("KAPSUL 12345" as NSString).draw(at: NSPoint(x: 45, y: 90), withAttributes: [.font: NSFont.systemFont(ofSize: 90), .foregroundColor: NSColor.black])
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let png = bitmap.representation(using: .png, properties: [:])!
        let fixture = root.appendingPathComponent("fixture.png")
        try png.write(to: fixture)
        let ocrStart = Date()
        let recognized = try await TextRecognition.recognize(fixture)
        check(Date().timeIntervalSince(ocrStart) < 20, "OCR completes promptly without model initialization stall")
        check(recognized.contains("KAPSUL") && recognized.contains("12345"), "Real Vision OCR recognizes fixture")
        check(store.importScreenshot(fixture), "Screenshot fixture imports")
        var imageClip = store.clips[0]
        check(imageClip.asset != nil, "Image persisted")
        let recognition = store.recognize(imageClip)
        store.recognize(imageClip)
        await recognition?.value
        imageClip = store.clips.first { $0.id == imageClip.id }!
        check(!store.recognizing.contains(imageClip.id), "OCR clears processing state")
        check(imageClip.extractedText?.contains("KAPSUL") == true, "OCR result stored")
        check(imageClip.searchableText.contains("12345"), "OCR searchable")
        check(store.copy(imageClip, plainText: true) && board.string(forType: .string)?.contains("KAPSUL") == true, "OCR text copy")

        let backupURL = root.appendingPathComponent("backup.json")
        await store.exportBackup(to: backupURL)
        let backup = try HistoryBackup.read(backupURL)
        check(backup.history.clips.count == store.clips.count && backup.assets.count == 1, "Backup includes history and actual image data")
        let targetFolder = root.appendingPathComponent("restored")
        let target = ClipboardStore(folder: targetFolder, defaults: defaults, pasteboard: board, monitoring: false)
        target.add(Clip(kind: .text, value: "Local entry"))
        await target.importBackup(from: backupURL)
        check(target.clips.count == store.clips.count + 1 && target.clips.contains { $0.value == "Local entry" }, "Restore merges without losing existing data")
        check(target.collections.count == 1, "Collection restored")
        let restoredImage = target.clips.first { $0.id == imageClip.id }!
        check(restoredImage.asset != imageClip.asset, "Restored asset gets independent safe filename")
        check((try? Data(contentsOf: target.assetURL(restoredImage)!)) == (try? Data(contentsOf: store.assetURL(imageClip)!)), "Restored image bytes match")
        await target.importBackup(from: backupURL)
        check(target.clips.count == store.clips.count + 1, "Repeated restore is idempotent")
        var corrupt = backup
        corrupt.history.clips.append(corrupt.history.clips[0])
        rejected({ try corrupt.validate() }, "Duplicate identifiers rejected")
        corrupt = backup; corrupt.assets = [:]
        rejected({ try corrupt.validate() }, "Missing image rejected")
        corrupt = backup; corrupt.history.clips[0].asset = "../../outside.png"
        rejected({ try corrupt.validate() }, "Traversal rejected")
        corrupt = backup; corrupt.version = 99
        rejected({ try corrupt.validate() }, "Unknown version rejected")
        let beforeInvalid = target.clips.count
        let invalidURL = root.appendingPathComponent("invalid.json")
        try JSONEncoder().encode(corrupt).write(to: invalidURL)
        await target.importBackup(from: invalidURL)
        check(target.clips.count == beforeInvalid, "Invalid import leaves existing history untouched")
        let exportURL = root.appendingPathComponent("export.txt")
        await store.exportText(to: exportURL, ids: [imageClip.id])
        check((try? String(contentsOf: exportURL, encoding: .utf8))?.contains("12345") == true, "OCR text exports")
        let expired = Clip(kind: .text, value: "Expired", date: Date.distantPast)
        var oldBackup = backup; oldBackup.history.clips = [expired]; oldBackup.assets = [:]
        target.retention = .month
        try target.mergeBackup(oldBackup)
        check(!target.clips.contains { $0.id == expired.id }, "Restore honors retention")
        // Failed disk commits must not delete images or mutate the displayed history.
        let historyFile = root.appendingPathComponent("history.json")
        try FileManager.default.removeItem(at: historyFile)
        try FileManager.default.createDirectory(at: historyFile, withIntermediateDirectories: false)
        let countBeforeFailure = store.clips.count
        store.removeMany([imageClip.id])
        check(store.clips.count == countBeforeFailure, "Failed write rolls back bulk deletion")
        check(FileManager.default.fileExists(atPath: store.assetURL(imageClip)!.path), "Failed write retains image bytes")
        try FileManager.default.removeItem(at: historyFile)
        store.save()
        store.removeMany([imageClip.id, second.id])
        check(!store.clips.contains { $0.id == imageClip.id || $0.id == second.id }, "Bulk delete")
        check(!FileManager.default.fileExists(atPath: store.assetURL(imageClip)!.path), "Bulk deletion removes image")
        store.removeCollection(collection)
        check(store.collections.isEmpty && store.clips.allSatisfy { ($0.collectionIDs ?? []).isEmpty }, "Removing collection retains entries but clears memberships")
        print("\(count) migration, rich/plain copy, exclusion, collection, bulk operation, OCR and backup checks passed.")
    }
}
