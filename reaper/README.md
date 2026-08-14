# Odium Studio – REAPER Dublaj Uzantısı v2.1.0

Odium, kayıt ve replik yerleştirme tarafında REAPER içinde çalışan native **Lua ReaScript + ReaImGui** uygulamasıdır. Mix teslim hedefi v2.1.0'dan itibaren **Adobe Audition `.sesx`** formatıdır.

> Normal kullanımda doğrudan `Odium_Reaper_Extension.lua` çalıştırmayın. `Register-Odium.lua`, Action List'e **`Odium_Reaper_Launcher.lua`** kaydeder. Launcher tek-instance korumasını ve ReaImGui 0.10 yaşam döngüsü uyumluluğunu yönetir.

## Dağıtım paketleri

Her release üç kullanıcı paketi üretir:

| Platform | Dosya | Kurulum tipi |
|---|---|---|
| Windows | `Odium-REAPER-Windows-Setup.exe` | Otomatik / tek-tık |
| macOS | `Odium-REAPER-macOS-manual.zip` | Manuel, yardımcı script dahil |
| Linux | `Odium-REAPER-Linux-manual.tar.gz` | Manuel, yardımcı script dahil |

Aynı release içinde `version.json` ve `SHA256SUMS.txt` yayınlanır. Windows güncelleyicisi indirilen setup dosyasını manifestteki SHA-256 ile doğrular.

## REAPER ve bağımlılık desteği

- **REAPER 6.80+** uyumluluk hedefidir; REAPER 7.x güncel sürümleri desteklenir.
- **ReaImGui 0.10.0.5** dağıtımda sabitlenir ve upstream SHA-256 değerleriyle doğrulanır.
- **FFmpeg**, özellikle çok parçalı REAPER kayıtlarını tek Audition take dosyasına dönüştürmek, item arası boşlukları korumak ve isteğe bağlı düzey eşitleme için gereklidir. Windows setup FFmpeg'i otomatik kurar.
- `js_ReaScriptAPI` yalnız gelişmiş klasör seçim penceresi için isteğe bağlıdır.

## Windows — otomatik kurulum

1. Release içindeki `Odium-REAPER-Windows-Setup.exe` dosyasını çalıştırın.
2. Standart REAPER kurulumu kullanıyorsanız varsayılan hedefi değiştirmeyin.
3. Kurucu Odium scriptlerini, ReaImGui'yi ve FFmpeg'i kurar.
4. `Register-Odium.lua` otomatik çalıştırılır; eski doğrudan `Odium_Reaper_Extension.lua` Action List kaydı kaldırılır ve güvenli launcher kaydedilir.
5. REAPER'ı yeniden açtıktan sonra `Actions > Show action list` içinde `Odium Studio` aratıp ana eylemi çalıştırın.

Launcher açıkken aynı Action'a tekrar basılırsa ikinci bir ReaImGui context oluşturulmaz; mevcut Odium penceresini kullanmanız istenir. Bu davranış ikinci açılışta görülebilen `Missing End()` / invalid context hatalarını önlemek içindir.

### Windows portable REAPER

Kurulum ekranında hedefi portable resource ağacındaki şu konuma değiştirin:

```text
<PORTABLE_REAPER_RESOURCE>\Scripts\Odium Studio
```

Gerekirse setup komut satırında `/REAPEREXE="X:\path\reaper.exe"` verilebilir.

## macOS — manuel paket

Release içindeki `Odium-REAPER-macOS-manual.zip` Apple Silicon/arm64, Intel x86_64 ve eski Intel i386 ReaImGui binary'lerini birlikte taşır.

```bash
chmod +x platform/macos/install.command
./platform/macos/install.command
```

Standart resource yolu `~/Library/Application Support/REAPER` kabul edilir. Custom/portable yol ilk argüman olarak verilebilir. Kurulumdan sonra REAPER'ı yeniden başlatıp `Register-Odium.lua` dosyasını **bir kez** `Actions > New action > Load ReaScript` ile çalıştırın. FFmpeg sistemde bulunmalıdır; Homebrew kullanıyorsanız `brew install ffmpeg` kullanılabilir.

## Linux — manuel paket

Release içindeki `Odium-REAPER-Linux-manual.tar.gz` x86_64, aarch64/arm64, i686 ve armv7l ReaImGui binary'lerini birlikte taşır.

```bash
chmod +x platform/linux/install.sh
./platform/linux/install.sh
```

Varsayılan resource yolu `~/.config/REAPER` kabul edilir. Custom/portable yol ilk argüman olarak verilebilir. FFmpeg sistem paket yöneticisinden kurulmalıdır.

## Seslendirme sanatçısı akışı

1. **Orijinalleri hazırla:** orijinal ses klasörünü seçin. Odium sesleri doğal isim sırasıyla `ODIUM - Originals` track'ine yerleştirir.
2. **Kaydı eşle:** kayıtları `ODIUM - Recordings` track'ine alın ve pozisyon/sıra eşleme çalıştırın. Bir replik birden fazla item'dan oluşabilir.
3. **Mixçiye gönder:** `Adobe Audition .sesx paketi + ZIP oluştur` işlemini çalıştırın.

REAPER `.rpp` dosyası yalnız **yerel kaynak çalışma projesidir**. Mixçiye gönderilen ZIP'e RPP konmaz.

## Adobe Audition teslim paketinin yapısı

Örnek çıktı:

```text
Game_Dub_Project_AU_Dub_Package_YYYYMMDD_HHMMSS/
├─ Game_Dub_Project.sesx
├─ Audio/
│  ├─ Originals/
│  │  ├─ 0001_line01.wav
│  │  └─ ...
│  └─ Takes/
│     ├─ 0001_line01_DUB.wav
│     └─ ...
├─ .audub/
│  ├─ project.json
│  └─ package-report.json
└─ README_AUDITION_MIX.txt
```

Aynı klasör ayrıca ZIP olarak oluşturulur.

### SESX içindeki track'ler

- **`ORIGINAL_REF`** — orijinal referanslar REAPER'daki timeline konumlarında.
- **`DUB_TAKE`** — eşleşen seslendirme kayıtları kendi gerçek başlangıç konumlarında.
- **Master** — iki track'in varsayılan çıkışı.

SESX medya referansları mutlak `C:\...` veya kullanıcı klasörüne bağlanmaz; `Audio\Originals\...` ve `Audio\Takes\...` biçiminde **göreli yollar** kullanılır. Mixçi ZIP'i açıp `.sesx` dosyasını Adobe Audition ile açabilir.

### Çok parçalı kayıtlar

Bir repliğe ait REAPER item'ları birden fazlaysa Odium bunları FFmpeg ile tek taşınabilir WAV'a dönüştürür. Item'ların kaynak offset/play-rate bilgileri ve timeline'daki aralarındaki sessizlikler mevcut `segments` modeli üzerinden korunur. Böylece mixçinin bilgisayarında REAPER'a özgü item/take bilgisine ihtiyaç kalmaz.

### Düzey eşitleme

`Kayıt düzeyini orijinal ortalama dB seviyesine eşitle` açıksa yalnız **paket kopyası** değiştirilir. Orijinal REAPER kayıt dosyasına dokunulmaz. Hedef gain orijinal/kayıt ortalama seviyesinden hesaplanır ve tepenin -1 dBFS'i aşmaması için sınırlandırılır.

## Audition tarafında kullanım

Mixçi için normal akış:

1. ZIP'i tamamen bir klasöre çıkarın.
2. Paket kökündeki `.sesx` dosyasını Adobe Audition ile açın.
3. `ORIGINAL_REF` ve `DUB_TAKE` track'lerinin online olduğunu kontrol edin.
4. Mix işlemini Audition'da yapın.
5. Eski Odium Audition paneli kullanılıyorsa `.audub/project.json` aynı proje/replik metadata'sını taşır.

## REAPER içindeki mix araçları

REAPER tarafındaki mevcut mixçi yardımcıları geriye dönük olarak korunur: `.audub/project.json` yükleme, tek mixdown'ı replik sınırlarına göre bölme ve orijinal isimlerle toplu export. Ana ekip akışı Audition olduğu için yeni teslim formatı SESX'tir.

## Action List kayıt ve kaldırma

`Register-Odium.lua` idempotent bootstrap'tır. Önce eski doğrudan UI script kaydını kaldırır, ardından `Odium_Reaper_Launcher.lua` ve `Odium Studio - Güncelleme Kontrolü` eylemini `reaper.AddRemoveReaScript` ile kaydeder.

`Unregister-Odium.lua` launcher, eski raw UI ve updater kayıtlarını kaldırır. Windows uninstaller da REAPER kapalıysa aynı üç Action List satırını yedek alarak temizler.

## Güncelleme sistemi

- Windows: yeni setup indirilir, SHA-256 doğrulanır ve kurucu açılır.
- macOS/Linux: yeni manuel paket/release sayfası açılır.

## Güvenli çalışma davranışı

Uzantı yalnız `P_EXT:ODIUM_ROLE` etiketi taşıyan kendi REAPER item'larını temizler veya günceller. Kullanıcının başka track ve item'larına toplu silme uygulanmaz. Timeline işlemleri REAPER Undo bloğu içinde yürütülür.

## Proje dosyası

Varsayılan konum:

```text
<proje-kökü>/.audub/project.json
```

Şema `schemaVersion: 3` kullanır. Eski Audition paketlerindeki temel `lines`, `mixStart`, `mixEnd`, `takes`, `selectedTakeId`, `originalAbsolutePath` ve `originalRelativePath` alanları yüklenirken korunur. SESX paket kopyasında medya yolları paket içindeki dosyalara yeniden yazılır.

## Bilinen sınırlar

- REAPER item fade/crossfade ve item FX zincirleri henüz Audition SESX'e efekt olarak çevrilmez. Seçili kayıtların ses içeriği/segment yapısı taşınır.
- GitHub Actions SESX XML üretimini ve dağıtım paketlerini doğrular; gerçek Adobe Audition uygulamasında açılış kabul testi fiziksel/gerçek bir Audition kurulumu gerektirir.
- macOS/Linux dağıtımları bilinçli olarak manuel kurulumdur.

## Üçüncü taraf bileşenler

Ayrıntılar `THIRD_PARTY_NOTICES.md` dosyasındadır.
