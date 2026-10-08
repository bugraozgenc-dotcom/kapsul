# GitHub üzerinden güncelleme yayımlama

Kapsül 0.5.0 ve sonrası Sparkle ile uygulama içinden güncelleme kontrolü yapar.
Düğme Ayarlar, Kapsül menüsü ve menü çubuğu panelindedir. Otomatik kontrol
başlangıçta kapalıdır; kullanıcı Ayarlar’dan açabilir. İndirme ve yükleme Sparkle
penceresinden onaylanır. Pano geçmişi uygulama paketinin dışında kalır.

## İlk kurulum

Güncelleme anahtarı bu Mac’in giriş Anahtar Zinciri’nde `kapsul` hesabıyla
saklanır. `Config/updates.json` yalnızca açık anahtarı içerir. Özel anahtarı
kaybetme; Apple Developer ID olmadan anahtar değişimi mevcut kullanıcılar için
elle kurulum gerektirir. Anahtarı kaynak depoya veya bir Release’e yükleme.

Yerel yayımlama için GitHub Actions gizli anahtarı gerekmez:

```sh
scripts/check.sh
scripts/build-app.sh --release --universal
scripts/package-dmg.sh
scripts/prepare-update.sh
```

GitHub’da `v0.5.0` Release oluştur, DMG ve `.sha256` dosyasını, `dist/updates/`
içindeki ZIP ve `appcast.xml` dosyasını ekle. Kararlı sürüm olarak yayımla.
`appcast.xml` dosyası **latest Release** üzerinden okunur; ZIP bağlantısı belirli
sürüm etiketine bağlıdır. Başka bir sürümü en güncel olarak işaretlersen o
Release de geçerli `appcast.xml` içermelidir. İlk yayın yapılana kadar uygulama
güncelleme sunucusuna erişim hatası gösterebilir.

## GitHub Actions ile paketleme

1. Anahtarı geçici, depo dışındaki bir dosyaya aktar:

   ```sh
   "$HOME/Library/Caches/CopyGlass/build/artifacts/sparkle/Sparkle/bin/generate_keys" \
     --account kapsul -x "$HOME/Library/Caches/CopyGlass/kapsul-update-private.txt"
   chmod 600 "$HOME/Library/Caches/CopyGlass/kapsul-update-private.txt"
   ```

2. Dosyanın içeriğini GitHub deposunda **Settings → Secrets and variables →
   Actions → New repository secret** altında `SPARKLE_PRIVATE_KEY` adıyla sakla.
   Aktarım bitince geçici dosyayı sil. Anahtar zincirindeki anahtarı koru.
3. **Actions → Prepare Kapsul release → Run workflow** seç. Sürümü `0.5.0`,
   build numarasını `5` yap. Sonraki her sürümde ikisini de artır (ör. `0.5.1`, `6`).
4. Workflow kontrolleri, universal derlemeyi, DMG’yi ve imzalı güncelleme paketini
   hazırlar; GitHub’da taslak Release oluşturur. Dosyaları ve sürüm notlarını
   kontrol edip **Publish release** seç.

Kod push etmek tek başına yayın yapmaz. Workflow aynı etikette mevcut Release
varsa onu değiştirmek yerine hata verir. Release yayımlandığında uygulamalar
güncellemeyi bulur. Sparkle henüz bulunmayan bir build numarasını daha yeni
sürüm olarak karşılaştırır; build numarasını tekrar kullanma veya düşürme.

## Doğrulama

`scripts/prepare-update.sh` universal mimariyi, uygulama kod imzasını, appcast
imzasını uygulamaya gömülü açık anahtarla doğrular, değiştirilmiş arşivin
reddedildiğini sınar ve arşiv boyutunu denetler. Sparkle ZIP’in EdDSA imzasını
çıkarma işleminden önce doğrular. Gerçek indirme/kurulum testi için güncelleme
sistemini içeren eski bir sürümü Applications’a kur ve daha yüksek build
numaralı Release yayımla. Güncelleme sonrası geçmiş ve ayarların kaldığını doğrula.

Mevcut 0.4.0 kullanıcıları 0.5.0’ı elle kurar. Apple Developer ID / noter onayı
bu akışa eklenmemiştir; dağıtım mevcut ad hoc imzayla devam eder.
