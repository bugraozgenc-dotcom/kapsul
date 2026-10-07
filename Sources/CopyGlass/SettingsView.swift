import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: ClipboardStore
    @EnvironmentObject var catalog: SourceCatalog
    @EnvironmentObject private var localization: AppLocalization
    @Environment(\.dismiss) private var dismiss
    @AppStorage("linkPreviews") private var previews = false
    @AppStorage("appearance") private var appearance = AppearanceMode.system.rawValue
    @State private var confirmClear = false
    @State private var pendingRetention: Retention = .month
    @State private var confirmRetention = false
    @State private var sourceName = ""
    @State private var domainsText = ""
    @State private var sourceError: Error?
    @State private var sourceAdded = false
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text(localization.text("Ayarlar")).font(.title2.bold()); Spacer() }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(localization.text("Dil"), systemImage: "character.bubble").font(.headline)
                        Picker(localization.text("Dil"), selection: $localization.language) {
                            ForEach(AppLanguage.allCases, id: \.self) { language in
                                Text(language.nativeName).tag(language)
                            }
                        }.pickerStyle(.menu)
                        Text(localization.text("Dil değişiklikleri hemen uygulanır.")).font(.caption).foregroundStyle(.secondary)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Label(localization.text("Görünüm"), systemImage: "circle.lefthalf.filled").font(.headline)
                        Picker(localization.text("Görünüm"), selection: $appearance) {
                            ForEach(AppearanceMode.allCases, id: \.self) { Text(localization.text($0.rawValue)).tag($0.rawValue) }
                        }.pickerStyle(.segmented)
                        Text(localization.text("Sistem seçeneği Mac’in görünüm ayarını izler.")).font(.caption).foregroundStyle(.secondary)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Label(localization.text("Kaynaklarım"), systemImage: "globe").font(.headline)
                        Text(localization.text("Kendi sitelerini gruplara ekle. Alan adı ve alt alan adlarıyla eşleşen mevcut ve yeni bağlantılar bu grupta görünür.")).font(.caption).foregroundStyle(.secondary)
                        ForEach(catalog.customs) { source in
                            HStack(spacing: 12) {
                                Image(systemName: "globe").foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(source.name).font(.subheadline.weight(.medium))
                                    Text(source.domains.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    do { try catalog.remove(source); sourceError = nil } catch { sourceError = error }
                                } label: { Image(systemName: "trash") }.buttonStyle(.borderless).help(localization.text("Kaynağı kaldır; kayıtları koru"))
                            }.padding(12).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(localization.text("Kaynak adı (ör. Tasarım blogum)"), text: $sourceName).textFieldStyle(.roundedBorder)
                                .accessibilityLabel(localization.text("Kaynak adı"))
                            TextField(localization.text("Alan adları (ör. example.com, example.org)"), text: $domainsText, axis: .vertical)
                                .lineLimit(2...3).textFieldStyle(.roundedBorder).accessibilityLabel(localization.text("Kaynak alan adları"))
                            HStack {
                                Text(localization.text("Birden fazla alan adını virgülle ayırabilirsin.")).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button(localization.text("Kaynak ekle"), action: addSource).buttonStyle(.borderedProminent)
                                    .disabled(sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || domainsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            if let message = sourceError?.localizedDescription ?? catalog.errorMessage { Text(message).font(.caption).foregroundStyle(.red) }
                            else if sourceAdded { Label(localization.text("Kaynak eklendi"), systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green) }
                        }
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Label(localization.text("Saklama süresi"), systemImage: "clock").font(.headline)
                        Picker(localization.text("Saklama süresi"), selection: Binding(get: { store.retention }, set: { pendingRetention = $0; confirmRetention = true })) {
                            ForEach(Retention.allCases, id: \.self) { Text(localization.text($0.rawValue)).tag($0) }
                        }.pickerStyle(.segmented)
                        Text(localization.text("Süre dolduğunda içerikler otomatik silinir. Sabitlenen öğeler de bu süreye dahildir.")).font(.caption).foregroundStyle(.secondary)
                    }
                    Divider()
                    Toggle(localization.text("Bağlantı önizlemelerini yükle"), isOn: $previews)
                    Text(localization.text("Önizlemeler açıldığında bağlantıların sitelerine ağ isteği yapılır. Bazı siteler önizleme sağlamayabilir.")).font(.caption).foregroundStyle(.secondary)
                    Text(localization.text("İçerikler bu Mac’te saklanır. Gizli olarak işaretlenen kopyalar atlanır; diğer hassas metinleri kopyalamadan önce takibi duraklatabilirsin.")).font(.caption).foregroundStyle(.secondary)
                }.padding(24)
            }
            Divider()
            HStack {
                Button(localization.text("Geçmişi temizle"), role: .destructive) { confirmClear = true }
                Spacer()
                Button(localization.text("Tamam")) { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(20)
        }.frame(width: 540, height: min(680, (NSScreen.main?.visibleFrame.height ?? 800) - 100))
            .preferredColorScheme(AppearanceMode(rawValue: appearance)?.colorScheme)
            .confirmationDialog(localization.text("Tüm geçmiş kalıcı olarak silinsin mi?"), isPresented: $confirmClear) {
                Button(localization.text("Tümünü sil"), role: .destructive) { store.clear() }
                Button(localization.text("Vazgeç"), role: .cancel) {}
            }
            .confirmationDialog(localization.text("Saklama süresi %@ olsun mu? Süre dışında kalan öğeler hemen silinir.", localization.text(pendingRetention.rawValue)), isPresented: $confirmRetention) {
                Button(localization.text("Uygula"), role: .destructive) { store.retention = pendingRetention }
                Button(localization.text("Vazgeç"), role: .cancel) {}
            }
    }
    private func addSource() {
        do {
            try catalog.add(name: sourceName, domainsText: domainsText)
            sourceName = ""; domainsText = ""; sourceError = nil; sourceAdded = true
        } catch { sourceError = error; sourceAdded = false }
    }
}
