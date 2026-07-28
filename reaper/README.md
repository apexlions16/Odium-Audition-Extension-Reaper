# Odium Studio – REAPER Dublaj Uzantısı v2.0.0

Bu sürüm Adobe Audition CEP paneli değildir. Uygulama, REAPER içinde çalışan native bir **Lua ReaScript + ReaImGui** uzantısıdır. Ana giriş dosyası `Odium_Reaper_Extension.lua` dosyasıdır.

## Gereksinimler

- REAPER 7 veya üzeri
- ReaImGui 0.10 veya üzeri; ReaPack’in varsayılan ReaTeam Extensions deposundan kurulabilir
- FFmpeg; Windows kurucusu otomatik yüklemeyi dener
- Klasör seçim penceresi için isteğe bağlı `js_ReaScriptAPI`; yoksa yol elle girilebilir

## Kurulum – Windows

1. `INSTALL.bat` dosyasını çalıştırın.
2. REAPER’da `Actions > Show action list` menüsünü açın.
3. `New action > Load ReaScript` seçin.
4. `%APPDATA%\REAPER\Scripts\Odium Studio\Odium_Reaper_Extension.lua` dosyasını yükleyin.
5. Action List içinde `Odium Studio - REAPER Dublaj Uzantısı` eylemini çalıştırın.

## Seslendirme sanatçısı akışı

1. Orijinal ses klasörünü seçin. Uzantı bütün alt klasörleri tarar, sesleri doğal isim sırasına koyar ve `ODIUM - Originals` track’ine yerleştirir.
2. Kaydı `ODIUM - Recordings` track’ine alın. `Pozisyona göre` veya `Sıraya göre` eşleme çalıştırın.
3. Projeyi kaydedip paketleyin. Paket; taşınabilir `.rpp`, `SessionMedia/`, `.audub/project.json`, orijinaller, hazırlanmış take dosyaları, rapor ve ZIP içerir.

Düzey eşitleme açıksa paket kopyaları, eşleştikleri orijinallerin FFmpeg `volumedetect` ortalama dB değerine getirilir. Kayıt tepesinin -1 dBFS’i aşmasına izin verilmez. Kaynak REAPER medyasına dokunulmaz.

## Mixçi akışı

1. `.audub/project.json` yükleyin. Project JSON yoksa orijinal ve kayıt track numaralarını vererek pozisyonlardan proje oluşturun.
2. Tek parça mixdown dosyasını seçin ve replik sınırlarına göre bölün.
3. İstenen export presetini seçip orijinal dosya adlarıyla toplu export alın.

## Korunan özellikler

- Seslendirme sanatçısı / mixçi rol ayrımı
- Alt klasörler dahil ses tarama ve doğal sıralama
- Timeline yerleşimi ve seçili repliğe gitme
- Pozisyon veya sıra tabanlı take eşleme
- Bir repliğin birden çok item’dan oluşması ve aradaki boşlukların korunması
- `.audub/project.json` okuma/yazma ve eski şema alanlarını normalize etme
- Hazır take klasörünü dosya adına göre bağlama
- FFmpeg ile mix split ve toplu export
- WAV/MP3 oyun, Wwise ve master presetleri
- Paketleme, `.rpp` içindeki medya yollarını `SessionMedia/` klasörüne yeniden bağlama, rapor ve ZIP
- Orijinal ortalama dB seviyesine eşitleme ve -1 dBFS tepe koruması
- Sağlık raporu ve işlem günlüğü
- İsteğe bağlı yerel PIN kilidi

## Güvenli çalışma davranışı

Uzantı yalnızca `P_EXT:ODIUM_ROLE` etiketi taşıyan kendi item’larını temizler veya günceller. Kullanıcının başka track ve item’larına toplu silme uygulanmaz. Timeline işlemleri REAPER Undo bloğu içinde yürütülür.

## Proje dosyası

Varsayılan konum:

```text
<proje-kökü>/.audub/project.json
```

Yeni şema `schemaVersion: 3` kullanır. Eski Audition paketlerindeki temel `lines`, `mixStart`, `mixEnd`, `takes`, `selectedTakeId`, `originalAbsolutePath` ve `originalRelativePath` alanları yüklenirken korunur.

## Bilinen sınırlar

- ReaImGui zorunludur; uzantı eksikse kurulum mesajı gösterir.
- REAPER item fade/crossfade ve item FX ayarları FFmpeg üzerinden hazırlanan take dosyasına henüz basılmaz; taşınabilir `.rpp` içinde korunur.
- macOS/Linux’ta kurulum elle yapılır; Lua kodu ve FFmpeg komutları platform bağımsız hazırlanmıştır.
