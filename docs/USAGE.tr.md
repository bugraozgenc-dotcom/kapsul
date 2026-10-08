# Kapsül kullanım rehberi

[English](USAGE.en.md) · [Proje ana sayfası](../README.md)

Kapsül, Mac’te kopyaladığınız metinleri, bağlantıları ve görselleri arayabileceğiniz bir pano geçmişi panelidir. Uygulama açıkken yeni ekran görüntülerini de kaydeder.

## Kurulum

1. Projenin **Releases** bölümünden `Kapsul-0.4.0-universal.dmg` dosyasını indirin. macOS 14 veya üzeri gerekir; paket Apple silicon ve Intel kodlarını içerir.
2. DMG’yi açın ve **Kapsül.app** dosyasını **Applications** klasörüne sürükleyin.
3. Kapsül’ü **Uygulamalar** klasöründen açın, ardından disk görüntüsünü çıkarın.

Bu sürüm ad hoc imzalıdır; Developer ID imzası ve Apple noter onayı yoktur. macOS indirdiğiniz uygulamayı engelleyebilir. Kaynağa güveniyorsanız açmayı denedikten sonra **Sistem Ayarları → Gizlilik ve Güvenlik → Yine de Aç** yolunu kullanabilirsiniz. Ayrıntılar için [Apple’ın güvenli uygulama açma rehberine](https://support.apple.com/tr-tr/102445) bakın.

## İlk kayıt

Kapsül açıkken başka bir uygulamada bir metin, bağlantı veya görsel kopyalayın. Yeni kayıt panelde görünür. macOS’un ekran görüntüsü araçlarıyla aldığınız yeni görüntüler de **Ekran görüntüsü** grubuna eklenir. Başlangıçtan önce alınmış görüntüler topluca içe aktarılmaz.

Pano yaklaşık 0,7 saniyede bir kontrol edilir. Bu aralıkta çok hızlı art arda kopyalanan içerikler atlanabilir. Uygulama kapalıyken kayıt alınmaz; açık bırakmak için pencereyi kapatabilirsiniz. Menü çubuğundaki pano simgesinden **Geçmiş panelini aç** ile geri dönün. Otomatik başlangıç ayarı uygulamada bulunmaz.

## Bul, aç ve yeniden kopyala

- Sol sütundan **Tümü**, **Sabitlenenler**, içerik türü veya kaynak seçin. Kartların boyutu standarttır; tarih ve saat her kartın altında yer alır.
- Arama alanına bir kelime ya da URL parçası yazın. **⌘F** aramaya odaklanır. Arama seçili gruptaki kayıtların metin ve bağlantı değerlerinde yapılır; görsellerde OCR araması yoktur.
- Bağlantı kartının başlığına veya içeriğine tıklayın; URL varsayılan tarayıcıda açılır.
- **Kopyala**, içeriği panoya geri koyar. Başarılı olduğunda yeşil **Kopyalandı** yazısı ve onay işareti görünür.
- Görsel veya ekran görüntüsüne tıklayın. Büyük önizlemenin altındaki **Kopyala** düğmesi görseli kopyalar.
- Sağ tıklayarak **Sabitle** seçin. Kayıt ayrıca **Sabitlenenler** grubunda görünür. Aynı menüden sabitlemeyi kaldırabilirsiniz.
- Kartın sağ üstündeki **×** düğmesine basın ve onaylayın; kayıt geçmişten silinir. İşlem geri alınamaz.

Bir dosyayı Finder’dan kopyaladığınızda dosyanın yolu kaydedilir. Kapsül dosyanın içeriğini yedeklemez; dosya taşınır veya silinirse eski kayıt çalışmayabilir.

## Kaynak grupları

Yerleşik kaynaklar: **LinkedIn, WhatsApp, Facebook, Instagram, YouTube, Behance, Medium, X, TikTok, Reddit, Pinterest, GitHub, Dribbble, Vimeo, Telegram ve Discord**.

Bağlantılar alan adına göre gruplanır. Desteklenen bazı masaüstü uygulamalarından kopyalanan metin ve görseller için ön plandaki uygulama da kaynak olarak kullanılır. Tarayıcıdan kopyalanan düz metnin hangi siteye ait olduğu her zaman belirlenemez.

Kendi grubunuzu eklemek için **Ayarlar → Kaynaklarım** bölümünde bir ad ve `example.com, example.org` gibi virgülle ayrılmış alan adları girip **Kaynak ekle** seçin. Eşleşen alt alan adları, mevcut ve yeni bağlantılar da bu grupta görünür. Kaynağı kaldırmak geçmiş kayıtlarını silmez. Özel kaynaklar genel bir küre simgesi kullanır.

## Ayarlar

| Ayar | Davranış |
| --- | --- |
| Dil | Türkçe, English, Français, Deutsch veya Español. Panel hemen güncellenir; macOS’un standart menüleri için yeniden açmak gerekebilir. |
| Görünüm | Sistem, Açık veya Koyu. Sistem seçeneği Mac’in ayarını izler. |
| Saklama süresi | 1 ay, 3 ay, 1 yıl veya Sonsuz. Süresi dolan kayıtlar ve saklanan görseller silinir; sabitlenen kayıtlar da süreye dahildir. Daha kısa süreye geçerken onay istenir ve eski kayıtlar hemen silinir. |
| Bağlantı önizlemeleri | Varsayılan olarak kapalıdır. Açıldığında başlık ve küçük görsel için bağlantının sitesine ağ isteği yapılır. Her site önizleme sağlamaz. |
| Geçmişi temizle | Onaydan sonra tüm kayıtları ve Kapsül’ün sakladığı görselleri kalıcı olarak siler. Kaynak gruplarınız korunur. |

Panelin sağ üstündeki duraklatma düğmesi veya menü çubuğundaki **Takibi duraklat** kaydı durdurur. **Takibi sürdür** ile devam edin. Duraklatma sırasında kopyalanan içerikler ve ekran görüntüleri sonradan topluca alınmaz.

## Veriler ve cihazlar

Geçmiş, görseller ve özel kaynaklar bu Mac’te `~/Library/Application Support/CopyGlass/` klasöründe tutulur. Tercihler macOS kullanıcı ayarlarına kaydedilir. Geçmiş ek bir uygulama şifrelemesiyle korunmaz; hassas içerikleri kopyalamadan önce takibi duraklatın. Gizli/geçici olarak işaretlenen pano içerikleri atlanır, ancak tüm uygulamalar bu işaretleri kullanmaz.

Kapsül’ün kendi bulut hesabı veya telefon eşitlemesi yoktur. iPhone’dan kopyaladığınız bir içerik macOS panosuna ulaştığında kaydedilebilir; bu Apple’ın Evrensel Pano özelliğinin koşullarına bağlıdır. Otomatik telefon aktarımı bu sürümde doğrulanmış bir özellik değildir.

Marka adları ve simgeleri ilgili sahiplerine aittir; Kapsül bu hizmetler tarafından desteklenmez. Simge kaynağı için [üçüncü taraf bildirimine](../Sources/CopyGlass/Resources/NOTICE.txt) bakın.
