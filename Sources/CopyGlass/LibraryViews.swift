import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ClipMetadataEditor: View {
    let clip: Clip
    @EnvironmentObject private var store: ClipboardStore
    @EnvironmentObject private var localization: AppLocalization
    @Environment(\.dismiss) private var dismiss
    @State private var tags = ""
    @State private var memberships = Set<UUID>()
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localization.text("Etiketler ve koleksiyonlar")).font(.title2.bold())
            Text(clip.title).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            TextField(localization.text("Etiketler (virgülle ayır)"), text: $tags).textFieldStyle(.roundedBorder)
            if store.collections.isEmpty { Text(localization.text("Koleksiyonları Ayarlar’dan oluşturabilirsin.")).foregroundStyle(.secondary) }
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(store.collections) { collection in
                        Toggle(collection.name, isOn: Binding(get: { memberships.contains(collection.id) }, set: { if $0 { memberships.insert(collection.id) } else { memberships.remove(collection.id) } }))
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 200)
            HStack {
                Button(localization.text("Vazgeç")) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(localization.text("Kaydet")) { store.updateMetadata(clip, tags: tags, collectionIDs: memberships); dismiss() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 420)
            .onAppear { tags = (clip.tags ?? []).joined(separator: ", "); memberships = Set(clip.collectionIDs ?? []) }
    }
}

struct RecognizedTextView: View {
    let clipID: UUID
    @EnvironmentObject private var store: ClipboardStore
    @EnvironmentObject private var localization: AppLocalization
    @Environment(\.dismiss) private var dismiss
    private var clip: Clip? { store.clips.first { $0.id == clipID } }
    private var resultText: String {
        if store.recognizing.contains(clipID) { return "" }
        if let error = store.recognitionErrors[clipID] { return error }
        if let text = clip?.extractedText, !text.isEmpty { return text }
        return localization.text("Görselde okunabilir metin bulunamadı.")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localization.text("Görselden metin")).font(.title2.bold())
            if store.recognizing.contains(clipID) { ProgressView(localization.text("Metin çıkarılıyor…")) }
            ScrollView { Text(resultText).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
            HStack {
                Button(localization.text("Yeniden tara")) { if let clip { store.recognize(clip) } }.disabled(store.recognizing.contains(clipID))
                Spacer()
                CopyFeedbackButton { clip.map { store.copy($0, plainText: true) } ?? false }.disabled(store.recognizing.contains(clipID) || clip?.extractedText?.isEmpty != false)
                Button(localization.text("Tamam")) { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }.padding(24).frame(width: 560, height: 400)
    }
}

@MainActor enum LibraryPanels {
    static func backup(_ store: ClipboardStore) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Kapsul-yedek.json"
        panel.title = L10n.text("Geçmişi yedekle")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await store.exportBackup(to: url) }
    }
    static func restore(_ store: ClipboardStore) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = L10n.text("Yedeği içe aktar")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await store.importBackup(from: url) }
    }
    static func text(_ store: ClipboardStore, ids: Set<UUID> = []) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Kapsul-metin.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await store.exportText(to: url, ids: ids) }
    }
    static func exclude(_ store: ClipboardStore) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.title = L10n.text("Hariç tutulacak uygulamaları seç")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { continue }
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            if !store.excludedApps.contains(where: { $0.id == id }) { store.excludedApps.append(ExcludedApplication(id: id, name: name)) }
        }
    }
}

struct BulkSelectionBar: View {
    @Binding var ids: Set<UUID>
    let visibleIDs: Set<UUID>
    let onFinish: () -> Void
    @EnvironmentObject private var store: ClipboardStore
    @EnvironmentObject private var localization: AppLocalization
    @State private var confirmDelete = false
    var body: some View {
        HStack(spacing: 12) {
            Text(localization.text("%@ kayıt seçildi", String(ids.count)))
                .font(.subheadline.weight(.semibold)).monospacedDigit()
            Button(localization.text(ids == visibleIDs && !ids.isEmpty ? "Seçimi temizle" : "Tümünü seç")) {
                ids = ids == visibleIDs ? [] : visibleIDs
            }.buttonStyle(.borderless).disabled(visibleIDs.isEmpty)
            Spacer(minLength: 0)
            Button(role: .destructive) { confirmDelete = true } label: {
                Label(localization.text("Seçilenleri sil"), systemImage: "trash")
            }.buttonStyle(.bordered).disabled(ids.isEmpty)
            Button(localization.text("Seçimi bitir"), action: onFinish).keyboardShortcut(.cancelAction)
        }.padding(14).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.blue.opacity(0.2), lineWidth: 1))
            .background {
                Button(localization.text("Tümünü seç")) { ids = visibleIDs }.keyboardShortcut("a", modifiers: .command).hidden()
            }
            .confirmationDialog(localization.text("%@ kayıt kalıcı olarak silinsin mi?", String(ids.count)), isPresented: $confirmDelete) {
                Button(localization.text("Seçilenleri sil"), role: .destructive) { store.removeMany(ids); ids = [] }
                Button(localization.text("Vazgeç"), role: .cancel) {}
            }
    }
}
