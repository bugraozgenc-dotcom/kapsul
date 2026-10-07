<p align="center"><img src="docs/images/app-icon.png" width="116" alt="Kapsül mavi cam kapsül ikonu"></p>

# Kapsül

<img width="1920" height="1440" alt="950_1x_shots_so" src="https://github.com/user-attachments/assets/5d793e3d-40bc-4ed2-bea7-df32b172c595" />

**Kopyala. Sakla. Yeniden bul.** Mac için açık kaynaklı pano geçmişi. Metin, bağlantı ve görsellerini arayabileceğin tek bir panelde, kaynaklarına göre düzenler.

[English](README.en.md) · [DMG indir](https://github.com/bugraozgenc-dotcom/kapsul/releases/latest) · [Türkçe kullanım rehberi](docs/USAGE.tr.md)


## İndir ve başla

macOS **14 veya üzeri** gerekir. Universal paket Apple Silicon ve Intel kodlarını içerir.

1. [Releases](https://github.com/bugraozgenc-dotcom/kapsul/releases/latest) bölümünden **Kapsul-0.4.0-universal.dmg** dosyasını indir.
2. DMG’yi aç, **Kapsül.app** dosyasını **Applications** klasörüne sürükle.
3. Uygulamayı aç ve başka bir uygulamadan içerik kopyala. Kapsül açıkken yeni kayıtlar otomatik görünür.

**Bu sürüm ad hoc imzalıdır; Developer ID imzası ve Apple noter onayı yoktur.** macOS güvenlik uyarısı gösterebilir. [Kurulum rehberi](docs/USAGE.tr.md#kurulum) bu durumu açıklar. Intel çalışma testi henüz yapılmadı.


## Özellikler

- **Aranabilir panel:** ⌘F ile metin veya URL içinde ara; tür ve kaynak gruplarıyla filtrele.
- **Bağlantılar:** Kartı tıklayarak tarayıcıda aç; isteğe bağlı başlık ve küçük görsel önizlemesi kullan.
- **Görseller ve ekran görüntüleri:** Yeni ekran görüntülerini kaydet; üzerine gelerek büyük önizlemeyi aç ve kopyala.
- **Kaynaklar:** LinkedIn, WhatsApp, Facebook, Instagram, YouTube, Behance, Medium, X, TikTok, Reddit, Pinterest, GitHub, Dribbble, Vimeo, Telegram ve Discord. Ayarlardan kendi alan adı gruplarını ekle.
- **Düzenleme:** Tarih ve saat, sabitleme, onayla silme ve yeşil animasyonlu kopyalama geri bildirimi.
- **Saklama süresi:** 1 ay, 3 ay, 1 yıl veya Sonsuz.
- **Görünüm ve dil:** Açık, koyu veya sistem görünümü; Türkçe, English, Français, Deutsch ve Español.
- **Yerel macOS arayüzü:** SwiftUI, cam katmanlar, menü çubuğu erişimi ve duraklatılabilir pano takibi.

## Kullanım ve veriler

[Türkçe rehber](docs/USAGE.tr.md) ve [English guide](docs/USAGE.en.md) kurulum, arama, önizleme, kaynak ekleme ve ayarları adım adım anlatır.

Kayıtlar bu Mac’te `~/Library/Application Support/CopyGlass/` içinde saklanır; ek uygulama şifrelemesi yoktur. Bağlantı önizlemeleri varsayılan olarak kapalıdır; açıldığında hedef sitelere ağ isteği yapılır. Dosyaların içerikleri yerine yolları saklanır. Sabitlenen kayıtlar da saklama süresine tabidir.

Kapsül çalışırken panoyu yaklaşık 0,7 saniyede bir kontrol eder; çok hızlı ardışık kopyalar atlanabilir. Önceden alınmış ekran görüntüleri topluca içe aktarılmaz. Tarayıcıdan kopyalanan düz metnin kaynak sitesi her zaman belirlenemez. Telefon veya bulut eşitlemesi uygulamaya dahil değildir.

## Kaynak koddan derleme

Xcode ve Command Line Tools yüklü bir Mac kullan. Kaynakları Xcode’da `Package.swift` ile de açabilirsin.

```sh
git clone https://github.com/bugraozgenc-dotcom/kapsul.git
cd kapsul
scripts/build-app.sh
open "dist/Kapsül.app"
```

Release uygulaması ve DMG üretmek için:

```sh
scripts/check.sh
scripts/build-app.sh --release --universal
scripts/package-dmg.sh
(cd dist && shasum -a 256 -c Kapsul-0.4.0-universal.dmg.sha256)
```

Çıktılar `dist/` altında oluşur. Geçici dosyalar yerel önbellekte tutulur. `COPYGLASS_VERSION` ve `COPYGLASS_BUILD_NUMBER` ile sürüm değiştirilebilir. Geçerli bir **Developer ID Application** sertifikası varsa `CODE_SIGN_IDENTITY` ile imzalanabilir; noter onayı ayrıca gerekir. Varsayılan imza ad hoc’tur.

GitHub Actions push/PR üzerinde kontrolleri çalıştırır. **Actions → macOS checks → Run workflow** ayrıca universal uygulama ve DMG üretir; dosyalar çalışma artifact’ı olarak indirilir.

## Lisans ve katkı

Kaynak kod [MIT lisanslıdır](LICENSE). Marka simgeleri için [Simple Icons bildirimi](Sources/CopyGlass/Resources/NOTICE.txt) geçerlidir; marka adları ilgili sahiplerine aittir. Hata bildirimleri ve katkılar Issues ve Pull Requests üzerinden gönderilebilir. [0.4.0 sürüm notları](docs/releases/v0.4.0.md).
