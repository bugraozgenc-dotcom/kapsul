import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var updater: AppUpdater
  @EnvironmentObject var store: ClipboardStore
  @EnvironmentObject var catalog: SourceCatalog
  @EnvironmentObject private var localization: AppLocalization
  @Environment(\.dismiss) private var dismiss
  @AppStorage("linkPreviews") private var previews = false
  @AppStorage("appearance") private var appearance = AppearanceMode.system.rawValue
  @AppStorage("backgroundTransparency") private var transparency = 75.0
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @StateObject private var launchAtLogin = LaunchAtLogin()
  @State private var page: SettingsPage = .general
  @State private var confirmClear = false
  @State private var pendingRetention: Retention = .month
  @State private var confirmRetention = false
  @State private var sourceName = ""
  @State private var domainsText = ""
  @State private var sourceError: Error?
  @State private var sourceAdded = false
  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Image(systemName: "gearshape.fill").font(.title2).foregroundStyle(.blue)
        Text(localization.text("Ayarlar")).font(.title2.bold())
        Spacer()
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).frame(
            width: 28, height: 28)
        }
        .buttonStyle(.borderless).help(localization.text("Tamam"))
      }.padding(22)
      Divider()
      HStack(alignment: .top, spacing: 0) {
        VStack(spacing: 6) {
          ForEach(SettingsPage.allCases) { item in
            Button {
              page = item
            } label: {
              Label(localization.text(item.title), systemImage: item.icon)
                .font(.system(size: 13, weight: page == item ? .semibold : .regular))
                .foregroundStyle(page == item ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(
                  .vertical, 11
                )
                .background(
                  page == item ? Color.accentColor.opacity(0.14) : .clear,
                  in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).accessibilityAddTraits(page == item ? .isSelected : [])
          }
          Spacer()
        }.padding(14).frame(width: 174).frame(maxHeight: .infinity).background(
          .primary.opacity(0.025))
        Divider()
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            Text(localization.text(page.title)).font(
              .system(size: 25, weight: .bold, design: .rounded)
            ).padding(.bottom, 6)
            switch page {
            case .general:
              languageSettings
              startupSettings
              FeatureSettingsView(page: page)
            case .appearance:
              appearanceSettings
              SidebarAppearanceSettings()
            case .history:
              retentionSettings
              FeatureSettingsView(page: page)
              SettingsCard {
                Button(localization.text("Geçmişi temizle"), role: .destructive) {
                  confirmClear = true
                }
                .frame(maxWidth: .infinity, alignment: .leading)
              }
            case .sources: sourceSettings
            case .privacy:
              FeatureSettingsView(page: page)
              privacySettings
            case .updates: updateSettings
            }
          }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }.id(page)
      }
      Divider()
      HStack {
        Spacer()
        Button(localization.text("Tamam")) { dismiss() }.keyboardShortcut(.cancelAction)
      }.padding(20)
    }.frame(width: 760, height: min(680, (NSScreen.main?.visibleFrame.height ?? 800) - 100))
      .background(GlassWindowSurface())
      .toggleStyle(.switch)
      .onAppear { launchAtLogin.refresh() }
      .onReceive(
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
      ) { _ in launchAtLogin.refresh() }
      .preferredColorScheme(AppearanceMode(rawValue: appearance)?.colorScheme)
      .confirmationDialog(
        localization.text("Tüm geçmiş kalıcı olarak silinsin mi?"), isPresented: $confirmClear
      ) {
        Button(localization.text("Tümünü sil"), role: .destructive) { store.clear() }
        Button(localization.text("Vazgeç"), role: .cancel) {}
      }
      .confirmationDialog(
        localization.text(
          "Saklama süresi %@ olsun mu? Süre dışında kalan öğeler hemen silinir.",
          localization.text(pendingRetention.rawValue)), isPresented: $confirmRetention
      ) {
        Button(localization.text("Uygula"), role: .destructive) {
          store.retention = pendingRetention
        }
        Button(localization.text("Vazgeç"), role: .cancel) {}
      }
  }

  private var updateSettings: some View {
    SettingsCard {
      VStack(alignment: .leading, spacing: 12) {
        Text(localization.text("Mevcut sürüm: %@", updater.version)).font(.caption).foregroundStyle(
          .secondary)
        Button(localization.text("Güncellemeleri kontrol et")) { updater.checkForUpdates() }
          .disabled(!updater.canCheckForUpdates)
        Toggle(
          localization.text("Güncellemeleri otomatik kontrol et"),
          isOn: $updater.automaticallyChecksForUpdates)
        Text(
          localization.text(
            "Yeni sürümler GitHub üzerinden indirilir. Yüklemeden önce onayın istenir.")
        ).font(.caption).foregroundStyle(.secondary)
      }
    }
  }

  private var languageSettings: some View {
    SettingsCard {
      VStack(alignment: .leading, spacing: 12) {
        Label(localization.text("Dil"), systemImage: "character.bubble").font(.headline)
        Picker(localization.text("Dil"), selection: $localization.language) {
          ForEach(AppLanguage.allCases, id: \.self) { language in
            Text(language.nativeName).tag(language)
          }
        }.pickerStyle(.menu)
        Text(localization.text("Dil değişiklikleri hemen uygulanır.")).font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var appearanceSettings: some View {
    SettingsCard {
      VStack(alignment: .leading, spacing: 12) {
        Picker(localization.text("Görünüm"), selection: $appearance) {
          ForEach(AppearanceMode.allCases, id: \.self) {
            Text(localization.text($0.rawValue)).tag($0.rawValue)
          }
        }.pickerStyle(.segmented)
        Text(localization.text("Sistem seçeneği Mac’in görünüm ayarını izler.")).font(.caption)
          .foregroundStyle(.secondary)
        HStack {
          Text(localization.text("Arka plan şeffaflığı"))
          Spacer()
          Text("\(Int(transparency))%").monospacedDigit().foregroundStyle(.secondary)
        }
        Slider(value: $transparency, in: 0...100, step: 5) {
          Text(localization.text("Arka plan şeffaflığı"))
        }.labelsHidden().frame(maxWidth: .infinity).disabled(reduceTransparency)
        HStack {
          Text(localization.text("Opak"))
          Spacer()
          Text(localization.text("Daha şeffaf"))
        }.font(.caption).foregroundStyle(.secondary)
        Text(
          localization.text(
            reduceTransparency
              ? "macOS’ta Şeffaflığı azalt açık olduğu için arka plan opak gösterilir."
              : "Değişiklik hemen uygulanır. Kartlar ve yazılar net kalır.")
        )
        .font(.caption).foregroundStyle(.secondary)
      }
    }
  }

  private var startupSettings: some View {
    SettingsCard {
      VStack(alignment: .leading, spacing: 12) {
        Label(localization.text("Başlangıç"), systemImage: "power").font(.headline)
        Toggle(
          localization.text("Mac açıldığında başlat"),
          isOn: Binding(
            get: { launchAtLogin.enabled }, set: { launchAtLogin.setEnabled($0) }))
        Text(localization.text("Mac’inde oturum açtığında Kapsül otomatik açılır.")).font(.caption)
          .foregroundStyle(.secondary)
        if launchAtLogin.requiresApproval {
          Text(localization.text("Başlatmak için macOS Oturum Açma Öğeleri’nde Kapsül’e izin ver."))
            .font(.caption).foregroundStyle(.secondary)
          Button(localization.text("Oturum Açma Öğeleri’ni aç")) { launchAtLogin.openSettings() }
        }
        if let error = launchAtLogin.error { Text(error).font(.caption).foregroundStyle(.red) }
      }
    }
  }

  private var sourceSettings: some View {
    SettingsCard {
      VStack(alignment: .leading, spacing: 12) {
        Text(
          localization.text(
            "Kendi sitelerini gruplara ekle. Alan adı ve alt alan adlarıyla eşleşen mevcut ve yeni bağlantılar bu grupta görünür."
          )
        ).font(.caption).foregroundStyle(.secondary)
        ForEach(catalog.customs) { source in
          HStack(spacing: 12) {
            Image(systemName: "globe").foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 3) {
              Text(source.name).font(.subheadline.weight(.medium))
              Text(source.domains.joined(separator: ", ")).font(.caption).foregroundStyle(
                .secondary
              ).textSelection(.enabled)
            }
            Spacer()
            Button(role: .destructive) {
              do {
                try catalog.remove(source)
                sourceError = nil
              } catch { sourceError = error }
            } label: {
              Image(systemName: "trash")
            }.buttonStyle(.borderless).help(localization.text("Kaynağı kaldır; kayıtları koru"))
          }.padding(12).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        }
        VStack(alignment: .leading, spacing: 8) {
          TextField(localization.text("Kaynak adı (ör. Tasarım blogum)"), text: $sourceName)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(localization.text("Kaynak adı"))
          TextField(
            localization.text("Alan adları (ör. example.com, example.org)"), text: $domainsText,
            axis: .vertical
          )
          .lineLimit(2...3).textFieldStyle(.roundedBorder).accessibilityLabel(
            localization.text("Kaynak alan adları"))
          HStack {
            Text(localization.text("Birden fazla alan adını virgülle ayırabilirsin.")).font(
              .caption
            ).foregroundStyle(.secondary)
            Spacer()
            Button(localization.text("Kaynak ekle"), action: addSource).buttonStyle(
              .borderedProminent
            )
            .disabled(
              sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || domainsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
          if let message = sourceError?.localizedDescription ?? catalog.errorMessage {
            Text(message).font(.caption).foregroundStyle(.red)
          } else if sourceAdded {
            Label(localization.text("Kaynak eklendi"), systemImage: "checkmark.circle.fill").font(
              .caption
            ).foregroundStyle(.green)
          }
        }
      }
    }
  }

  private var retentionSettings: some View {
    SettingsCard {
      VStack(alignment: .leading, spacing: 12) {
        Label(localization.text("Saklama süresi"), systemImage: "clock").font(.headline)
        Picker(
          localization.text("Saklama süresi"),
          selection: Binding(
            get: { store.retention },
            set: {
              pendingRetention = $0
              confirmRetention = true
            })
        ) {
          ForEach(Retention.allCases, id: \.self) { Text(localization.text($0.rawValue)).tag($0) }
        }.pickerStyle(.segmented)
        Text(
          localization.text(
            "Süre dolduğunda içerikler otomatik silinir. Sabitlenen öğeler de bu süreye dahildir.")
        ).font(.caption).foregroundStyle(.secondary)
      }
    }
  }

  private var privacySettings: some View {
    SettingsCard {
      VStack(alignment: .leading, spacing: 12) {
        Toggle(localization.text("Bağlantı önizlemelerini yükle"), isOn: $previews)
        Text(
          localization.text(
            "Önizlemeler açıldığında bağlantıların sitelerine ağ isteği yapılır. Bazı siteler önizleme sağlamayabilir."
          )
        ).font(.caption).foregroundStyle(.secondary)
        Text(
          localization.text(
            "İçerikler bu Mac’te saklanır. Gizli olarak işaretlenen kopyalar atlanır; diğer hassas metinleri kopyalamadan önce takibi duraklatabilirsin."
          )
        ).font(.caption).foregroundStyle(.secondary)
      }
    }
  }

  private func addSource() {
    do {
      try catalog.add(name: sourceName, domainsText: domainsText)
      sourceName = ""
      domainsText = ""
      sourceError = nil
      sourceAdded = true
    } catch {
      sourceError = error
      sourceAdded = false
    }
  }
}
