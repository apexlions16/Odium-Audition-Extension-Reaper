# Odium Studio – REAPER → Adobe Audition Dublaj Akışı

Bu deponun aktif ürünü kayıt/yerleştirme tarafında REAPER için geliştirilen native dublaj uzantısıdır. **v2.1.0 itibarıyla mix teslim formatı Adobe Audition `.sesx`** olmuştur: seslendirmeci REAPER'da çalışır, mixçi paketi Audition'da açar.

## Release paketleri

Her dağıtım üç platform paketi üretir:

- **Windows:** `Odium-REAPER-Windows-Setup.exe` — otomatik per-user kurulum; Odium, ReaImGui, FFmpeg ve güvenli Action List launcher kaydını hazırlar.
- **macOS:** `Odium-REAPER-macOS-manual.zip` — Apple Silicon, Intel x86_64 ve eski i386 için manuel paket.
- **Linux:** `Odium-REAPER-Linux-manual.tar.gz` — x86_64, aarch64, i686 ve armv7l için manuel paket.

Uyumluluk hedefi **REAPER 6.80+**, paketlenen ReaImGui sürümü `0.10.0.5`'tir.

## Kod yapısı

```text
reaper/Odium_Reaper_Launcher.lua       # tek-instance + ReaImGui 0.10 yaşam döngüsü
reaper/Odium_Reaper_Extension.lua      # ReaImGui ana uygulama
reaper/Register-Odium.lua              # Action List bootstrap
reaper/Odium_Check_For_Updates.lua     # release güncelleme kontrolü
reaper/lib/odium_reaper.lua            # REAPER host adapter
reaper/lib/odium_core.lua              # hosttan bağımsız çekirdek
reaper/lib/odium_package.lua           # teslim paketleme adapter'ı
reaper/lib/odium_sesx.lua              # Adobe Audition SESX üretici/paketleyici
reaper/installer/OdiumReaper.iss       # Windows tek-tık kurucu
```

## Başlıca özellikler

- Orijinal sesleri REAPER timeline'ına otomatik yerleştirme
- Kayıt item'larını pozisyon veya sıra ile eşleme
- Çok parçalı repliklerde boşlukları koruma
- `.audub/project.json` veri uyumluluğu
- **Adobe Audition `.sesx` + `Audio/Originals` + `Audio/Takes` + `.audub/project.json` + ZIP teslimi**
- SESX içinde hazır `ORIGINAL_REF` ve `DUB_TAKE` track'leri
- Çok item'lı REAPER kayıtlarını Audition için taşınabilir tek take'e flatten etme
- Orijinal ortalama dB seviyesine kayıt eşitleme ve -1 dBFS tepe koruması
- Tek-instance launcher ile ikinci açılışta yeni ReaImGui context oluşturmama
- Cross-platform updater ve dağıtım paketleri

REAPER `.rpp` dosyası yerel kaynak çalışma projesi olarak kalır; mixçiye giden ZIP'in proje dosyası `.sesx`'tir.

Ayrıntılı kurulum ve kullanım için [`reaper/README.md`](reaper/README.md) dosyasına bakın.

> `AU-Dub-Panel/` eski Audition kaynak kodunu ve veri uyumluluğu referansını tutar; REAPER uzantısının kurulumu için gerekli değildir.
