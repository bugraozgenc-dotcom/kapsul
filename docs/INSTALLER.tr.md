# DMG kurulum tasarımı

`./scripts/package-dmg.sh` Kapsül simgesi ve Applications kısayolu için 760 × 500 boyutunda bir Finder penceresi hazırlar. Açık mavi/lavanta arka plan, cam görünümlü alanlar ve sürükleme oku `scripts/render-dmg-background.swift` ile oluşturulur. Retina PNG 1520 × 1000 piksel, görüntü boyutu 760 × 500 noktadır.

Yerleşim `.DS_Store` dosyasına `scripts/style-dmg.py` ile yazılır; arka plan bağlantısı takılı HFS+ disk üzerinde üretilir. Paketleme önbelleğinde ayrı bir Python ortamına `ds-store==1.3.1` ve `mac-alias==2.2.2` kurulur. İlk çalıştırma internet gerektirir; bu bağımlılıklar uygulamaya eklenmez. Son DMG sıkıştırılır, sağlama toplamı ve uygulama imzası doğrulanır.

Önizlemeyi üretmek için:

```sh
xcrun swift scripts/render-dmg-background.swift Assets/Installer/background.png Assets/Installer/preview.png
```

İki görünür öğenin yanında kurulum notları gizli `.background/Kurulum - Installation.txt` dosyasında bulunur.
