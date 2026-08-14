# Odium REAPER — macOS manuel kurulum

Bu paket otomatik `.pkg`/`.dmg` kurucusu değildir. Amaç, mümkün olduğunca geniş macOS/REAPER kombinasyonunda dosyaları açık ve geri alınabilir biçimde yerleştirmektir.

## Destek hedefi

- **REAPER 6.80+** önerilen tabandır. 6.80, ReaScript'i komut satırından çalıştırma desteğini getiren sürümdür; Odium'un kullandığı temel ReaScript API'leri bu tabanla uyumludur.
- REAPER 7.x güncel sürümleri desteklenir.
- **Apple Silicon (arm64)** desteklenir.
- **Intel 64-bit (x86_64)** desteklenir.
- **Eski Intel 32-bit (i386)** ReaImGui binary'si paket içinde tutulur; yalnız 32-bit uygulama çalıştırabilen eski macOS/REAPER ortamları içindir.
- Standart ve portable/custom REAPER resource klasörleri desteklenir.

Paket, ReaImGui `v0.10.0.5` için üç macOS mimarisini içerir ve build sırasında upstream SHA-256 değerleri doğrulanır.

## Standart resource yolu

```text
~/Library/Application Support/REAPER
```

REAPER içinden kesin yolu görmek için `Options > Show REAPER resource path in explorer/finder` seçeneğini kullanabilirsiniz.

## Kurulum — yardımcı script

Terminal'de paket köküne gidip:

```bash
chmod +x platform/macos/install.command
./platform/macos/install.command
```

Portable/custom resource için:

```bash
./platform/macos/install.command "/Volumes/AudioTools/REAPER"
```

Script Odium dosyalarını `Scripts/Odium Studio` altına, doğru ReaImGui `.dylib` dosyasını `UserPlugins` altına kopyalar. FFmpeg sistemde varsa kullanılır; yoksa yalnız FFmpeg gerektiren split/export/seviye işlemleri devre dışı kalır.

## Tamamen elle kurulum

1. Paket içindeki Odium `.lua`, `lib/`, `version.json` ve dokümantasyon dosyalarını `<REAPER_RESOURCE>/Scripts/Odium Studio/` altına kopyalayın.
2. Mimarinize uygun ReaImGui dosyasını `<REAPER_RESOURCE>/UserPlugins/` altına kopyalayın:
   - Apple Silicon: `reaper_imgui-arm64.dylib`
   - Intel 64-bit: `reaper_imgui-x86_64.dylib`
   - Eski Intel 32-bit: `reaper_imgui-i386.dylib`
3. REAPER'ı tamamen kapatıp açın.
4. `Actions > Show action list > New action > Load ReaScript` ile `Register-Odium.lua` dosyasını bir kez çalıştırın.
5. Action List içinde ana Odium paneli ve güncelleme kontrol eylemi görünür.

## FFmpeg

Homebrew varsa:

```bash
brew install ffmpeg
```

Odium `ffmpeg` komutunu PATH üzerinden bulur. İsterseniz kendi binary'nizi `Scripts/Odium Studio/tools/ffmpeg` yoluna da koyabilirsiniz.

## Gatekeeper / quarantine

GitHub'dan indirilen arşivlerde macOS üçüncü taraf `.dylib` dosyasına quarantine etiketi uygulayabilir. REAPER ReaImGui'yi yüklemiyorsa önce dosyanın upstream ReaImGui `v0.10.0.5` binary'si olduğunu ve paket SHA-256 doğrulamasını kontrol edin. Gerekirse yalnız bu dosya için quarantine etiketini kullanıcı olarak kaldırabilirsiniz:

```bash
xattr -d com.apple.quarantine "$HOME/Library/Application Support/REAPER/UserPlugins/reaper_imgui-arm64.dylib"
```

Intel kullanıyorsanız dosya adını kendi mimarinize göre değiştirin. Bu komut otomatik çalıştırılmaz.

## Linux'tan farklı macOS notları

- Apple Silicon ve Intel binary'leri ayrı tutulur; universal tek ReaImGui dosyasına güvenilmez.
- FFmpeg paket içine gömülmez; sistem kurulumu tercih edilir.
- Odium'un Lua çekirdeği platformdan bağımsızdır; platforma özel bölüm esas olarak ReaImGui binary'si, dosya yolları ve shell komutlarıdır.
