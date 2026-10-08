# Kütüphane özellikleri

## Panel kısayolu

Varsayılan kısayol **⌥Space**. Ayarlar → Panel kısayolu bölümünden değiştirebilirsin.

## Görsellerden metin çıkarma

Yeni görsel ve ekran görüntülerine Apple Vision ile yerel OCR uygulanır.
Otomatik taramayı Ayarlar’dan kapatabilirsin. Mevcut görselleri kartın
**Görselden metin** düğmesiyle tara. Sonuç penceresinde metni seç, kopyala veya
yeniden tara. Çıkarılan metin ana aramada bulunur. Tanıma doğruluğu görselin
kalitesine ve diline bağlıdır. Görseller OCR için bir sunucuya gönderilmez.

## Çoklu seçim

Ana panelde **Çoklu seçim** düğmesine bas. Seçim daireleri yalnızca bu modda
görünür. Kartlara tıklayarak seç veya **Tümünü seç** ile görünür sonuçları seç.
**Seçilenleri sil** düğmesiyle onaylayarak topluca sil. **Seçimi bitir** veya
Escape ile normal görünüme dön. Filtre değişince görünmeyen kayıtlar seçimden çıkarılır.

## Etiketler ve koleksiyonlar

Ayarlar’dan **Koleksiyonlar** altında grup oluştur. Karttaki üç nokta menüsünde
**Etiketler ve koleksiyonlar** ile virgülle ayrılmış etiketler ekle ve kaydı bir
veya daha fazla koleksiyona yerleştir. Etiketler aramada, koleksiyonlar sol
panelde bulunur. Koleksiyonu kaldırmak içindeki pano kayıtlarını silmez.

## Hariç tutulan uygulamalar

Ayarlar’dan bir veya birden fazla `.app` seç. Seçili uygulama öndeyken yeni pano
kayıtları ve yeni ekran görüntüleri kaydedilmez. Kaynağı bilinen bir kaydın kart
menüsünden de uygulamayı hariç tutabilirsin. Hariç tutmayı kaldırmak mevcut
geçmişi değiştirmez. Pano takibi aralıklıdır: kopyalama ile kontrol arasında
uygulama değişirse kaynak bilgisi yanlış belirlenebilir. Bu özellik hassas
verileri yakalamaya karşı kesin bir güvenlik garantisi değildir; gizli pano
işaretleri ayrıca atlanmaya devam eder.

## Düz metin

Kart menüsünde **Düz metin olarak kopyala** biçimlendirmeyi kaldırır. Yeni
kopyalanan biçimli metinlerde normal Kopyala düğmesi RTF biçimini korur.
Görsellerde düz metin, OCR sonucudur; dosyalarda dosya yoludur. Daha eski
kayıtlarda biçimlendirme saklanmadığı için normal ve düz kopyalama aynı olabilir.

## Yedekleme ve dışa aktarma

Ayarlar → **Yedekleme ve dışa aktarma**:

- **Geçmişi yedekle**: Kayıtlar, görseller, OCR sonuçları, etiketler ve
  koleksiyonlar tek JSON dosyasına kaydedilir.
- **Yedeği içe aktar**: Yedek doğrulanır ve mevcut geçmişle birleştirilir. Aynı
  kayıt kimliği tekrar içe aktarılmaz; mevcut kayıt tercih edilir. Mevcut
  saklama süresinin dışındaki eski kayıtlar alınmaz.
- **Metin olarak dışa aktar**: Metinler ve bağlantılar, görsellerin OCR metni ve
  dosya yolları UTF-8 metin dosyasına kaydedilir.

Yedek üst sınırı 256 MB; toplam görsel boyutu en fazla 160 MB, tek görsel en
fazla 64 MB. Yedek dosyası şifrelenmez. Dışarıdaki dosyaların içerikleri yerine
kayıtlı yolları taşınır. Görünüm tercihleri, uygulama hariç tutma listesi ve özel
kaynak alan adı kuralları bu geçmiş yedeğine dahil değildir.

## Mac açıldığında başlat

Ayarlar → Başlangıç → **Mac açıldığında başlat** seçeneği, macOS’un `SMAppService.mainApp` API’siyle uygulamayı oturum açma öğesi olarak kaydeder. Seçenek macOS’taki gerçek durumu gösterir; kayıt işlemi başarısız olursa hata görünür. macOS onayı gerektiğinde **Oturum Açma Öğeleri’ni aç** düğmesini kullan. Kapsül’ü önce Applications klasörüne taşı; daha sonra başlangıç seçeneğini etkinleştir.
