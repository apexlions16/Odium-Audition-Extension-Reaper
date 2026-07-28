# GitHub geliştirme aşamaları

Bu dosya REAPER portunun GitHub üzerinde görünür ilerleme kaydıdır.

## Aşama 1 — Mimari ve taşınabilir çekirdek

- Aktif ürün yönü REAPER olarak tanımlandı.
- `.audub/project.json` için bağımsız JSON katmanı eklendi.
- Doğal sıralama, proje şeması, FFmpeg split/export, düzey eşitleme, paket ve ZIP çekirdeği yazıldı.

## Aşama 2 — REAPER host entegrasyonu

- `MediaTrack`, `MediaItem` ve `MediaItem_Take` üzerinden native timeline erişimi eklendi.
- `ODIUM - Originals` ve `ODIUM - Recordings` track akışı oluşturuldu.
- Pozisyon/sıra eşleme, segment offset/play-rate ve güvenli metadata yönetimi eklendi.

## Aşama 3 — ReaImGui uygulaması

- Seslendirme sanatçısı ve mixçi için ayrı üç adımlı paneller eklendi.
- Proje oluşturma/yükleme, timeline yerleşimi, eşleme, paketleme, mix split, export, sağlık kontrolü ve PIN arayüzü bağlandı.

## Aşama 4 — Dokümantasyon ve geçiş

- Windows kurulum ve kullanım dokümanı yazıldı.
- Audition CEP/ExtendScript karşılıklarının REAPER ReaScript mimarisine eşlemesi belgelendi.

## Aşama 5 — Kurulum ve bağımlılıklar

- `%APPDATA%\REAPER\Scripts\Odium Studio` hedefli kurucu eklendi.
- Windows kurucusu, FFmpeg yardımcısı ve taşınabilir `.rpp` için `SessionMedia` yeniden bağlama eklendi.
- ReaImGui eksikliği kurulum ve çalışma anında açıkça raporlanır.

## Aşama 6 — Doğrulama

- Lua 5.4 sözdizimi kontrolü eklendi.
- JSON, doğal sıralama, eski proje normalizasyonu ve RPP medya yolu yeniden yazma smoke testleri eklendi.
- `version.json` doğrulaması GitHub Actions iş akışına bağlandı.

## Aşama 7 — REAPER içinde kabul testi

GitHub Actions, Lua ve veri katmanını doğrular. Birleştirme öncesinde gerçek REAPER kurulumu üzerinde aşağıdaki kabul senaryoları uygulanmalıdır:

1. Temiz kurulum ve Action List kaydı.
2. Orijinalleri timeline'a yerleştirme.
3. Pozisyon ve sıra eşleme.
4. Çok item'lı tek replik ve boşluk koruma.
5. Taşınabilir `.rpp` + `SessionMedia` + `.audub/project.json` + ZIP paketi.
6. FFmpeg split/export ve düzey eşitleme.
7. Eski Audition `project.json` paketini açma.
