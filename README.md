# Odium Studio – REAPER Dublaj Uzantısı

Bu deponun aktif ürünü artık yalnızca **REAPER** için geliştirilen native dublaj uzantısıdır.

Ana kod ve kurulum:

```text
reaper/Odium_Reaper_Extension.lua
reaper/INSTALL.bat
reaper/README.md
```

Yeni sürüm Adobe CEP/CSXS veya Audition ExtendScript kullanmaz. REAPER ReaScript API, ReaImGui ve FFmpeg üzerinde çalışır.

## Başlıca özellikler

- Seslendirme sanatçısı ve mixçi için ayrı üç adımlı akış
- Orijinal sesleri timeline’a otomatik yerleştirme
- Kayıt item’larını pozisyon veya sıra ile eşleme
- Çok parçalı repliklerde boşlukları koruma
- `.audub/project.json` proje/paket uyumluluğu
- `.rpp` + medya + rapor + ZIP paketi
- Tek mixdown dosyasını repliklere bölme
- Orijinal isimlerle preset tabanlı toplu export
- Orijinal ortalama dB seviyesine kayıt eşitleme ve -1 dBFS tepe koruması

Ayrıntılı kurulum ve kullanım için [`reaper/README.md`](reaper/README.md), mimari geçiş için [`reaper/docs/MIGRATION.md`](reaper/docs/MIGRATION.md) dosyasına bakın.

> `AU-Dub-Panel/` klasörü yalnız eski Audition kaynağını karşılaştırma amacıyla tutulmaktadır. Yeni kurucu bu klasörü yüklemez ve Adobe yazılımlarına bağımlı değildir.
