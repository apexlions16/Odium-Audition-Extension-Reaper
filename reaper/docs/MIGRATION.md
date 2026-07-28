# Audition → REAPER geçiş notları

## Mimari değişiklik

| Eski Audition yapısı | Yeni REAPER karşılığı |
|---|---|
| CEP / CEF HTML panel | ReaImGui paneli |
| `CSXS/manifest.xml` | Action List’e kayıtlı Lua ReaScript |
| ExtendScript `host.jsx` | Native REAPER ReaScript API çağrıları |
| `.sesx` | `.rpp` |
| Audition track/clip API | `MediaTrack`, `MediaItem`, `MediaItem_Take` |
| CEP Node.js dosya sistemi | Lua `io` + REAPER dosya enumerasyonu |
| PowerShell/Node FFmpeg scriptleri | Lua tarafından doğrudan oluşturulan FFmpeg komutları |

## Veri uyumluluğu

Proje modeli tamamen sıfırlanmadı. `.audub/project.json` kavramı korunarak REAPER’a özgü `schemaVersion: 3`, track adları, item kaynak offset’i, play rate ve segment bilgileri eklendi. Eski paketler yüklenirken eksik alanlar varsayılanlarla tamamlanır.

## Timeline güvenliği

- Orijinaller `ODIUM - Originals` track’ine yerleştirilir.
- Kayıtlar `ODIUM - Recordings` track’inden okunur.
- Yönetilen item’lar `P_EXT:ODIUM_ROLE` ve `P_EXT:ODIUM_LINE_ID` metadata alanlarıyla işaretlenir.
- Temizleme yalnız Odium metadata’sı taşıyan item’lara uygulanır.

## Çok parçalı kayıtlar

Bir repliğe ait birden fazla kayıt item’ı `segments` dizisinde tutulur. Export sırasında her segment kendi kaynak offset’inden kesilir; item’lar arasındaki timeline boşluğu FFmpeg `anullsrc` ile yeniden oluşturulur ve `concat` ile tek dosyaya alınır.

## Düzey eşitleme

Orijinal ve kayıt dosyaları `volumedetect` ile ölçülür. Uygulanacak gain:

```text
hedef_gain = original_mean_dB - recording_mean_dB
uygulanan_gain = min(hedef_gain, -1 dBFS - recording_peak_dB)
```

Bu işlem yalnız oluşturulan paket/export kopyalarına uygulanır.

## Audition klasörünün durumu

`AU-Dub-Panel/` eski kaynak karşılaştırması ve geri dönüş ihtimali için dalda tutulur; yeni README, kurucu ve çalışma yolu yalnız `reaper/` klasörünü kullanır. REAPER sürümü CEP, CSXS veya Adobe klasörlerine hiçbir şey kurmaz.
