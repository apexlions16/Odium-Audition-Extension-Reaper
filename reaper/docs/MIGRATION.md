# Audition ↔ REAPER geçiş notları

## Güncel mimari

v2.1.0 ile iş akışı tek DAW'a zorlanmaz:

- **Kayıt / replik yerleştirme:** REAPER + ReaScript/ReaImGui
- **Mix teslimi:** Adobe Audition `.sesx`
- **Ortak veri modeli:** `.audub/project.json`

| Katman | Uygulama / format |
|---|---|
| Eski panel UI | Audition CEP / CEF HTML |
| Yeni kayıt UI | REAPER ReaImGui |
| Eski ExtendScript host | `host.jsx` |
| Yeni kayıt host adapter | `odium_reaper.lua` / REAPER ReaScript API |
| Yerel kaynak proje | `.rpp` |
| Mixçiye teslim edilen proje | `.sesx` |
| Ortak proje metadata'sı | `.audub/project.json` |

REAPER `.rpp` dosyası artık Audition'a dönüştürülmeye çalışılan bir dosya değildir; yalnız seslendirmenin yerel kaynak projesidir. Teslim sırasında Odium proje modelinden yeni bir Audition SESX session üretir.

## SESX üretimi

`reaper/lib/odium_sesx.lua` iki Audition audio track'i oluşturur:

- `ORIGINAL_REF`: orijinal referans sesler
- `DUB_TAKE`: REAPER'da eşlenmiş kayıtlar

Dosya referansları paket köküne göre göreli yazılır. Böylece mixçi ZIP'i farklı drive/kullanıcı klasöründe açsa da session aynı paket içindeki `Audio/` medyasını kullanır.

## Veri uyumluluğu

`.audub/project.json` korunur. REAPER tarafında `schemaVersion: 3`, item kaynak offset'i, play rate ve `segments` bilgisi bulunur. SESX paket kopyasında medya yolları paket içindeki dosyalara yeniden bağlanır; eski Audition paneli temel `lines`, `takes`, `selectedTakeId`, `mixStart` ve `mixEnd` alanlarını kullanmaya devam edebilir.

## Timeline güvenliği

- REAPER orijinalleri `ODIUM - Originals` track'ine yerleştirir.
- Kayıtlar `ODIUM - Recordings` track'inden okunur.
- Yönetilen item'lar `P_EXT:ODIUM_ROLE` ve `P_EXT:ODIUM_LINE_ID` metadata alanlarıyla işaretlenir.
- Temizleme yalnız Odium metadata'sı taşıyan item'lara uygulanır.

## Çok parçalı kayıtlar

Bir repliğe ait birden fazla REAPER kayıt item'ı `segments` dizisinde tutulur. SESX paketi hazırlanırken her segment kaynak offset'inden kesilir; play-rate hesaba katılır ve item'lar arasındaki timeline boşluğu FFmpeg ile sessizlik olarak korunur. Sonuç Audition'ın doğrudan okuyacağı tek taşınabilir take dosyasıdır.

## Düzey eşitleme

Orijinal ve kayıt dosyaları `volumedetect` ile ölçülür:

```text
hedef_gain = original_mean_dB - recording_mean_dB
uygulanan_gain = min(hedef_gain, -1 dBFS - recording_peak_dB)
```

Bu işlem yalnız SESX paketindeki take kopyasına uygulanır; REAPER kaynak kayıtlarına dokunulmaz.

## UI yaşam döngüsü

Action List'e artık doğrudan `Odium_Reaper_Extension.lua` değil `Odium_Reaper_Launcher.lua` kaydedilir. Launcher aynı eylemin ikinci kez çalıştırılmasını engeller ve ReaImGui 0.10 `Begin/End` yaşam döngüsünü güvenli hale getirir.

## Eski Audition klasörünün durumu

`AU-Dub-Panel/` veri uyumluluğu ve eski paneli kullanan mixçiler için referans olarak repoda tutulur. REAPER kurucusu Adobe klasörlerine dosya yüklemez; `.sesx` teslim paketi Audition'ın açacağı normal session + medya dosyalarıdır.
