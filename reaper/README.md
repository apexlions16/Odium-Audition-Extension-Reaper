# Odium Studio – REAPER Dublaj Uzantısı v2.0.0

Odium'un aktif ürünü Adobe Audition CEP paneli değil, REAPER içinde çalışan native **Lua ReaScript + ReaImGui** uygulamasıdır. Ana giriş dosyası `Odium_Reaper_Extension.lua` dosyasıdır.

## Dağıtım paketleri

Her release üç kullanıcı paketi üretir:

| Platform | Dosya | Kurulum tipi |
|---|---|---|
| Windows | `Odium-REAPER-Windows-Setup.exe` | Otomatik / tek-tık |
| macOS | `Odium-REAPER-macOS-manual.zip` | Manuel, yardımcı script dahil |
| Linux | `Odium-REAPER-Linux-manual.tar.gz` | Manuel, yardımcı script dahil |

Aynı release içinde `version.json` ve `SHA256SUMS.txt` da yayınlanır. Windows güncelleyicisi setup dosyasını indirmeden sonra manifestteki SHA-256 ile doğrulayabilir.

## REAPER ve bağımlılık desteği

- **REAPER 6.80+** uyumluluk hedefidir. 6.80 ve sonrasında REAPER'ın ReaScript komut satırı / `-nonewinst` desteği bulunduğu için Windows otomatik Action List kaydı bu taban üzerinde kurulmuştur.
- REAPER 7.x güncel sürümleri desteklenir.
- **ReaImGui 0.10.0.5** paketleme sırasında sabitlenir ve upstream SHA-256 değerleriyle doğrulanır.
- **FFmpeg** mix split, toplu export ve seviye eşitleme için gereklidir. Timeline, proje JSON ve temel REAPER işlemleri FFmpeg olmadan da çalışır.
- `js_ReaScriptAPI` yalnız gelişmiş klasör seçim penceresi için isteğe bağlıdır; yoksa yol girişi kullanılabilir.

## Windows — otomatik kurulum

1. Release içindeki `Odium-REAPER-Windows-Setup.exe` dosyasını çalıştırın.
2. Standart REAPER kurulumu kullanıyorsanız varsayılan hedefi değiştirmeyin.
3. Kurucu varsayılan olarak:
   - Odium scriptlerini `%APPDATA%\REAPER\Scripts\Odium Studio` altına kurar,
   - REAPER mimarisine uygun ReaImGui DLL'ini `UserPlugins` altına koyar,
   - doğrulanmış sabit FFmpeg paketini Odium'un kendi `tools` klasörüne kurar,
   - REAPER executable dosyasını bulur,
   - `Register-Odium.lua` bootstrap'ını `reaper.exe -nonewinst` ile çalıştırır,
   - ana panel ve güncelleme kontrol eylemini Action List'e `AddRemoveReaScript` API'siyle kaydeder.
4. REAPER açıksa mevcut instance kullanılabilir; kapalıysa kayıt sırasında REAPER açılabilir.

Normal kullanımda artık `Actions > Load ReaScript` adımı gerekmez.

### Windows portable REAPER

Kurulum ekranında hedefi portable resource ağacındaki şu konuma değiştirin:

```text
<PORTABLE_REAPER_RESOURCE>\Scripts\Odium Studio
```

Kurucu resource path'i seçilen klasörün iki üst dizini olarak hesaplar. `reaper.exe` portable resource kökünde bulunuyorsa otomatik Action List kaydı da yapılır. Gerekirse setup komut satırında `/REAPEREXE="X:\path\reaper.exe"` verilebilir.

Kaynak klasörden alternatif kurulum için `INSTALL.bat` veya `Install-Odium-Reaper.ps1` kullanılabilir.

## macOS — manuel paket

Release içindeki `Odium-REAPER-macOS-manual.zip` şu ReaImGui mimarilerini birlikte taşır:

- Apple Silicon / arm64
- Intel x86_64
- eski Intel i386

Paket açıldıktan sonra:

```bash
chmod +x platform/macos/install.command
./platform/macos/install.command
```

Standart resource yolu `~/Library/Application Support/REAPER` kabul edilir. Custom/portable yol ilk argüman olarak verilebilir. Yardımcı script doğru `.dylib` dosyasını seçip kurar; ardından REAPER'ı yeniden başlatıp `Register-Odium.lua` dosyasını **bir kez** `Actions > New action > Load ReaScript` ile çalıştırırsınız.

Daha ayrıntılı ve tamamen elle kurulum için `platform/macos/README.md` dosyasına bakın. FFmpeg macOS paketine gömülmez; sistemde `ffmpeg` komutu bulunmalıdır (örneğin Homebrew üzerinden).

## Linux — manuel paket

Release içindeki `Odium-REAPER-Linux-manual.tar.gz` şu ReaImGui mimarilerini birlikte taşır:

- x86_64 / amd64
- aarch64 / arm64
- i686
- armv7l

Paket açıldıktan sonra:

```bash
chmod +x platform/linux/install.sh
./platform/linux/install.sh
```

Varsayılan resource yolu `~/.config/REAPER` kabul edilir. Custom/portable yol ilk argüman olarak verilebilir. Script doğru `.so` dosyasını seçer, `ldd` varsa eksik runtime kütüphanelerini raporlar ve FFmpeg durumunu kontrol eder.

Linux ReaImGui için Fontconfig, GTK/GDK 3.22+ uyumlu runtime ve libepoxy bulunmalıdır. Ayrıntılar `platform/linux/README.md` içindedir.

## Action List kayıt ve kaldırma

`Register-Odium.lua` idempotent bootstrap'tır. Ana paneli ve `Odium Studio - Güncelleme Kontrolü` eylemini resmi `reaper.AddRemoveReaScript` API'siyle kaydeder ve command ID'lerini ExtState içinde saklar.

`Unregister-Odium.lua` aynı kayıtları API üzerinden kaldırır. Windows uninstaller ayrıca REAPER kapalıysa `reaper-kb.ini` içindeki yalnız Odium'a ait satırları yedek alarak temizleyen bir fallback içerir. ReaImGui başka scriptler tarafından kullanılabileceği için uninstaller ortak `UserPlugins` binary'sini otomatik silmez.

## Güncelleme sistemi

Action List'teki `Odium Studio - Güncelleme Kontrolü` eylemi release asset'i olan `version.json` dosyasını okur.

- Windows: yeni setup dosyasını indirir, manifest SHA-256 değeri varsa doğrular ve kurucuyu açar.
- macOS/Linux: yeni manuel paket/release sayfasını açar; sistem dosyalarında otomatik değişiklik yapmaz.

## Seslendirme sanatçısı akışı

1. Orijinal ses klasörünü seçin. Uzantı bütün alt klasörleri tarar, sesleri doğal isim sırasına koyar ve `ODIUM - Originals` track'ine yerleştirir.
2. Kaydı `ODIUM - Recordings` track'ine alın. `Pozisyona göre` veya `Sıraya göre` eşleme çalıştırın.
3. Projeyi kaydedip paketleyin. Paket taşınabilir `.rpp`, `SessionMedia/`, `.audub/project.json`, orijinaller, hazırlanmış take dosyaları, rapor ve ZIP içerir.

Düzey eşitleme açıksa paket kopyaları eşleştikleri orijinallerin FFmpeg `volumedetect` ortalama dB değerine getirilir. Kayıt tepesinin -1 dBFS'i aşmasına izin verilmez. Kaynak REAPER medyasına dokunulmaz.

## Mixçi akışı

1. `.audub/project.json` yükleyin. Project JSON yoksa orijinal ve kayıt track numaralarını vererek pozisyonlardan proje oluşturun.
2. Tek parça mixdown dosyasını seçin ve replik sınırlarına göre bölün.
3. İstenen export presetini seçip orijinal dosya adlarıyla toplu export alın.

## Korunan özellikler

- Seslendirme sanatçısı / mixçi rol ayrımı
- Alt klasörler dahil ses tarama ve doğal sıralama
- Timeline yerleşimi ve seçili repliğe gitme
- Pozisyon veya sıra tabanlı take eşleme
- Bir repliğin birden çok item'dan oluşması ve aradaki boşlukların korunması
- `.audub/project.json` okuma/yazma ve eski şema alanlarını normalize etme
- Hazır take klasörünü dosya adına göre bağlama
- FFmpeg ile mix split ve toplu export
- WAV/MP3 oyun, Wwise ve master presetleri
- Paketleme, `.rpp` içindeki medya yollarını `SessionMedia/` klasörüne yeniden bağlama, rapor ve ZIP
- Orijinal ortalama dB seviyesine eşitleme ve -1 dBFS tepe koruması
- Sağlık raporu ve işlem günlüğü
- İsteğe bağlı yerel PIN kilidi

## Güvenli çalışma davranışı

Uzantı yalnız `P_EXT:ODIUM_ROLE` etiketi taşıyan kendi item'larını temizler veya günceller. Kullanıcının başka track ve item'larına toplu silme uygulanmaz. Timeline işlemleri REAPER Undo bloğu içinde yürütülür.

## Proje dosyası

Varsayılan konum:

```text
<proje-kökü>/.audub/project.json
```

Yeni şema `schemaVersion: 3` kullanır. Eski Audition paketlerindeki temel `lines`, `mixStart`, `mixEnd`, `takes`, `selectedTakeId`, `originalAbsolutePath` ve `originalRelativePath` alanları yüklenirken korunur.

## Bilinen sınırlar

- ReaImGui zorunludur. Windows paketinde otomatik kurulur; macOS/Linux paketlerinde platform binary'si paket içinde olup manuel yardımcısı tarafından yerleştirilir.
- REAPER item fade/crossfade ve item FX ayarları FFmpeg üzerinden hazırlanan take dosyasına henüz basılmaz; taşınabilir `.rpp` içinde korunur.
- macOS/Linux paketleri bilinçli olarak manuel dağıtımdır; sistem package manager veya root yetkisi kullanılmaz.

## Üçüncü taraf bileşenler

Ayrıntılar ve sabitlenen sürümler `THIRD_PARTY_NOTICES.md` içindedir. Release paketleri ReaImGui lisans dosyalarını da taşır.
