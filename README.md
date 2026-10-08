<p align="center"><img src="docs/images/app-icon.png" width="116" alt="Kapsül uygulama ikonu"></p>

# Kapsül

Az önce kopyaladığın bağlantı neredeydi? Ya dün aldığın ekran görüntüsü?

Kapsül’ü, Mac’te kopyaladığımız şeyleri tekrar aramak zorunda kalmayalım diye yaptık. Metinleri, bağlantıları ve görselleri bir arada tutuyor; ihtiyacın olduğunda arayıp yeniden kopyalayabiliyorsun. Küçük, ücretsiz ve açık kaynaklı bir pano arkadaşı.

[DMG indir](https://github.com/bugraozgenc-dotcom/kapsul/releases/latest) · [English](README.en.md) · [Kullanım rehberi](docs/USAGE.tr.md)

![Kapsül 0.6.0 — çalışan uygulamadaki bağlantı kartları](docs/images/screenshots/links.png)

*Bu sayfadaki ekran görüntüleri çalışan Kapsül 0.6.0 uygulamasından alındı.*

## Hemen başlayalım

Mac’inde **macOS 14 veya üzeri** olması yeterli.

1. [Son sürümden](https://github.com/bugraozgenc-dotcom/kapsul/releases/latest) **Kapsul-0.6.0-universal.dmg** dosyasını indir. Apple Silicon ve Intel kodları aynı pakette.
2. DMG’yi açıp **Kapsül.app** simgesini **Applications** klasörüne sürükle.
3. Kapsül’ü aç, bir şey kopyala. Artık geçmişinde bulabilirsin. **⌥ Space** ile paneli çağır, **⌘ F** ile ara.

Paket şu an ad hoc imzalı; Developer ID imzası ve Apple noter onayı bulunmuyor. Bu yüzden macOS açılışta güvenlik uyarısı gösterebilir. Ayrıntılar [kurulum rehberinde](docs/USAGE.tr.md#kurulum). Intel üzerinde çalışma testi henüz yapılmadı.

## Neler yapabiliyor?

- **Kopyaladıklarını bul:** Metin, bağlantı, görsel, ekran görüntüsü ve dosya yolu kayıtlarını ara; türlerine veya kaynaklarına göre filtrele.
- **Kaynakları takip et:** Grupların yanında kayıt sayısını gör. En son kopyaladığın kaynak üstte olsun; istersen kendi alan adı gruplarını ekle.
- **Görselden metin çıkar:** Yerel OCR ile görseldeki yazıyı bul, ara ve kopyala. Büyük görsel önizlemesi yalnızca tıklayınca açılır.
- **Geçmişini düzenle:** Önemli kayıtları sabitle, etiket ve koleksiyon ekle. Çoklu seçimle istemediklerini topluca sil.
- **Görünümü kendine göre ayarla:** Açık, koyu veya sistem temasını seç; cam arka planın şeffaflığını değiştir. Sol menünün rengini, şeffaflığını ve genişliğini de ayarlayabilirsin.
- **Günlük kullanımı kolaylaştır:** Mac açıldığında başlatmayı aç, panel kısayolunu değiştir, metni biçimiyle veya düz metin olarak kopyala.
- **Kontrol sende olsun:** Pano takibini duraklat, belirli uygulamaları hariç tut, saklama süresini seç. Geçmişini görselleriyle birlikte yedekleyip geri yükle.
- **Güncel kal:** Ayarlar’dan güncellemeleri kontrol et; Sparkle ile yayımlanan yeni sürümü indirip yükle.

Türkçe, İngilizce, Fransızca, Almanca ve İspanyolca arayüz desteği var.

![Kapsül’de kaynak grubu ve kayıt sayıları](docs/images/screenshots/source-github.png)

![Kapsül’ün güncel görünüm, renk ve şeffaflık ayarları](docs/images/screenshots/appearance.png)

## Veriler nerede duruyor?

Geçmişin bu Mac’te, `~/Library/Application Support/CopyGlass/` klasöründe tutuluyor. Uygulamaya özel ek şifreleme veya Kapsül’e ait bulut/telefon eşitlemesi yok. Dosyaların içeriği yerine yolları saklanıyor.

OCR cihazda çalışıyor. Bağlantı önizlemeleri varsayılan olarak kapalı; açarsan hedef sitelere önizleme almak için istek gönderiliyor. Güncelleme kontrolü GitHub’a bağlanıyor.

Kapsül açıkken panoyu yaklaşık 0,7 saniyede bir kontrol ediyor; çok hızlı ardışık kopyalar atlanabilir. Eski ekran görüntülerini topluca içe aktarmıyor. Tarayıcıdan kopyalanan düz metnin hangi siteden geldiği her zaman anlaşılmayabilir. Sabitlenen kayıtlar da seçtiğin saklama süresine tabi.

## Birlikte geliştirelim

Kapsül hâlâ gelişiyor. Bir şey takılırsa [Issues](https://github.com/bugraozgenc-dotcom/kapsul/issues) bölümüne yaz; ne yaptığını ve ne beklediğini anlatman çok işimize yarar. Fikirler ve pull request’ler de hoş gelir.

Daha ayrıntılı anlatım için [pano araçları](docs/LIBRARY.tr.md), [güncellemeler](docs/UPDATES.tr.md) ve [0.6.0 sürüm notlarına](docs/releases/v0.6.0.md) bakabilirsin.

## Kaynak koddan çalıştırmak istersen

Xcode ve Command Line Tools yüklü bir Mac’te:

```sh
git clone https://github.com/bugraozgenc-dotcom/kapsul.git
cd kapsul
scripts/build-app.sh
open "dist/Kapsül.app"
```

Universal dağıtım paketi hazırlamak için:

```sh
scripts/check.sh
scripts/build-app.sh --release --universal
scripts/package-dmg.sh
(cd dist && shasum -a 256 -c Kapsul-0.6.0-universal.dmg.sha256)
```

Çıktılar `dist/` klasörüne gelir. Xcode’da `Package.swift` dosyasını da açabilirsin. Sürüm için `COPYGLASS_VERSION` ve `COPYGLASS_BUILD_NUMBER`, geçerli Developer ID sertifikasıyla imzalamak için `CODE_SIGN_IDENTITY` kullanılabilir. Noter onayı ayrıca yapılır. İmzalı Sparkle paketi için [güncelleme rehberine](docs/UPDATES.tr.md) bak.

Kaynak kod [MIT lisanslı](LICENSE). Marka simgeleri için [Simple Icons bildirimi](Sources/CopyGlass/Resources/NOTICE.txt) geçerli; marka adları sahiplerine ait.
