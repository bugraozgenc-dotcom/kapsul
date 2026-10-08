import AppKit
import SwiftUI

struct FeatureSettingsView: View {
  let page: SettingsPage
  @EnvironmentObject private var store: ClipboardStore
  @EnvironmentObject private var panel: PanelController
  @EnvironmentObject private var localization: AppLocalization
  @AppStorage("automaticOCR") private var automaticOCR = true
  @State private var collectionName = ""
  @State private var pendingCollection: ClipCollection?
  @State private var confirmCollection = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if page == .general {
        SettingsCard {
          VStack(alignment: .leading, spacing: 12) {
            Label(localization.text("Panel kısayolu"), systemImage: "keyboard").font(.headline)
            Picker(localization.text("Panel kısayolu"), selection: $panel.shortcut) {
              Text("⌥ Space").tag("option-space")
              Text("⌘ ⇧ Space").tag("command-shift-space")
              Text("⌃ ⌥ Space").tag("control-option-space")
              Text(localization.text("Kapalı")).tag("disabled")
            }.pickerStyle(.menu)
            if let message = panel.shortcutError {
              Text(message).font(.caption).foregroundStyle(.red)
            }
          }
        }
      }
      if page == .history {
        SettingsCard {
          VStack(alignment: .leading, spacing: 12) {
            Label(localization.text("Görselden metin"), systemImage: "text.viewfinder").font(
              .headline)
            Toggle(localization.text("Yeni görsellerden otomatik metin çıkar"), isOn: $automaticOCR)
            Text(
              localization.text(
                "Metin tanıma bu Mac’te yapılır. Çıkarılan metin aramada bulunur; eski görselleri kart menüsünden tarayabilirsin."
              )
            ).font(.caption).foregroundStyle(.secondary)
          }
        }
      }
      if page == .history {
        SettingsCard {
          VStack(alignment: .leading, spacing: 12) {
            Label(localization.text("Koleksiyonlar"), systemImage: "folder").font(.headline)
            ForEach(store.collections) { collection in
              HStack {
                Text(collection.name)
                Spacer()
                Button {
                  pendingCollection = collection
                  confirmCollection = true
                } label: {
                  Image(systemName: "trash")
                }
                .buttonStyle(.borderless).help(
                  localization.text("Koleksiyonu kaldır; kayıtları koru"))
              }
            }
            HStack {
              TextField(localization.text("Koleksiyon adı"), text: $collectionName).textFieldStyle(
                .roundedBorder)
              Button(localization.text("Oluştur")) {
                if store.addCollection(collectionName) { collectionName = "" }
              }
              .disabled(collectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text(
              localization.text(
                "Kart menüsünden etiket ekle ve koleksiyon seç. Etiketler aramada bulunur.")
            ).font(.caption).foregroundStyle(.secondary)
          }
        }
      }
      if page == .privacy {
        SettingsCard {
          VStack(alignment: .leading, spacing: 12) {
            Label(localization.text("Hariç tutulan uygulamalar"), systemImage: "hand.raised").font(
              .headline)
            ForEach(store.excludedApps) { app in
              HStack {
                VStack(alignment: .leading) {
                  Text(app.name)
                  Text(app.id).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                  store.excludedApps.removeAll { $0.id == app.id }
                } label: {
                  Image(systemName: "minus.circle")
                }.buttonStyle(.borderless)
                  .help(localization.text("Hariç tutmayı kaldır"))
              }
            }
            Button(localization.text("Uygulama seç…")) { LibraryPanels.exclude(store) }
            Text(
              localization.text(
                "Seçili uygulama öndeyken yeni pano kayıtları ve ekran görüntüleri saklanmaz. Mevcut kayıtlar korunur."
              )
            ).font(.caption).foregroundStyle(.secondary)
          }
        }
      }
      if page == .history {
        SettingsCard {
          VStack(alignment: .leading, spacing: 12) {
            Label(localization.text("Yedekleme ve dışa aktarma"), systemImage: "externaldrive")
              .font(.headline)
            HStack {
              Button(localization.text("Geçmişi yedekle")) { LibraryPanels.backup(store) }
              Button(localization.text("Yedeği içe aktar")) { LibraryPanels.restore(store) }
            }.disabled(store.transferring)
            Button(localization.text("Metin olarak dışa aktar")) { LibraryPanels.text(store) }
              .disabled(store.transferring || store.clips.isEmpty)
            if store.transferring {
              ProgressView(localization.text("Dosya işleniyor…")).controlSize(.small)
            }
            Text(
              localization.text(
                "Yedek; kayıtları, görselleri, etiketleri ve koleksiyonları içerir. İçe aktarma mevcut geçmişle birleştirir. Dosya şifrelenmez."
              )
            ).font(.caption).foregroundStyle(.secondary)
            if let notice = store.notice { Text(notice).font(.caption).foregroundStyle(.green) }
          }
        }
      }
      if let error = store.error { Text(error).font(.caption).foregroundStyle(.red) }
    }
    .confirmationDialog(
      localization.text("Koleksiyon kaldırılsın mı? Kayıtlar korunur."),
      isPresented: $confirmCollection
    ) {
      Button(localization.text("Kaldır"), role: .destructive) {
        if let collection = pendingCollection { store.removeCollection(collection) }
      }
      Button(localization.text("Vazgeç"), role: .cancel) {}
    }
  }
}
