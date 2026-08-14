# Odium Studio – REAPER Dublaj Uzantısı

Bu deponun aktif ürünü REAPER için geliştirilen native dublaj uzantısıdır. Eski Audition/CEP kaynakları karşılaştırma ve veri uyumluluğu referansı olarak tutulur; yeni dağıtım Adobe yazılımlarına bağımlı değildir.

## Release paketleri

Her dağıtım üç platform paketi üretir:

- **Windows:** `Odium-REAPER-Windows-Setup.exe` — otomatik per-user kurulum; Odium, ReaImGui, FFmpeg ve Action List kaydını hazırlar.
- **macOS:** `Odium-REAPER-macOS-manual.zip` — Apple Silicon, Intel x86_64 ve eski i386 için manuel paket.
- **Linux:** `Odium-REAPER-Linux-manual.tar.gz` — x86_64, aarch64, i686 ve armv7l için manuel paket.

Uyumluluk hedefi **REAPER 6.80+**, paketlenen ReaImGui sürümü `0.10.0.5`'tir. Windows'ta standart ve portable resource yolu desteklenir; macOS/Linux paketlerinde custom resource yolu yardımcı scriptlere argüman verilebilir.

## Kod yapısı

```text
reaper/Odium_Reaper_Extension.lua      # ReaImGui ana uygulama
reaper/Register-Odium.lua              # Action List bootstrap
reaper/Odium_Check_For_Updates.lua     # release güncelleme kontrolü
reaper/lib/odium_reaper.lua            # REAPER host adapter
reaper/lib/odium_core.lua              # hosttan bağımsız çekirdek
reaper/lib/odium_package.lua           # RPP/SessionMedia/ZIP paketleme
reaper/installer/OdiumReaper.iss       # Windows tek-tık kurucu
reaper/platform/macos/                 # macOS manuel dağıtım
reaper/platform/linux/                 # Linux manuel dağıtım
```

## Başlıca özellikler

- Seslendirme sanatçısı ve mixçi için ayrı üç adımlı akış
- Orijinal sesleri timeline'a otomatik yerleştirme
- Kayıt item'larını pozisyon veya sıra ile eşleme
- Çok parçalı repliklerde boşlukları koruma
- `.audub/project.json` proje/paket uyumluluğu
- `.rpp` + medya + rapor + ZIP paketi
- Tek mixdown dosyasını repliklere bölme
- Orijinal isimlerle preset tabanlı toplu export
- Orijinal ortalama dB seviyesine kayıt eşitleme ve -1 dBFS tepe koruması
- Cross-platform güncelleme manifesti ve Windows'ta SHA-256 doğrulamalı updater

Ayrıntılı kurulum, platform notları ve kullanım için [`reaper/README.md`](reaper/README.md) dosyasına bakın. Mimari geçiş notları `reaper/docs/` altındadır.

> `AU-Dub-Panel/` yalnız eski Audition kaynağını karşılaştırma amacıyla tutulmaktadır. Yeni kurucu bu klasörü yüklemez.
