# Odium REAPER — Linux manuel kurulum

Bu paket Linux için açık/manual dağıtımdır; sistem paket yöneticisine müdahale etmez ve root yetkisi istemez. Odium dosyaları REAPER resource klasörüne, doğru ReaImGui binary'si `UserPlugins` altına yerleştirilir.

## Destek hedefi

- **REAPER 6.80+** uyumluluk hedefidir; REAPER 7.x güncel sürümleri de desteklenir.
- x86_64 / amd64
- aarch64 / arm64
- i686 / 32-bit x86
- armv7l
- Standart `~/.config/REAPER` ve portable/custom resource klasörleri
- X11 veya Wayland üzerinde REAPER'ın desteklediği masaüstü ortamları

Paket ReaImGui `v0.10.0.5` için dört Linux mimarisini içerir. Binary'ler build aşamasında upstream SHA-256 değerleriyle doğrulanır.

## Runtime bağımlılıkları

ReaImGui'nin Linux build'i için dağıtımınızda aşağıdaki grafik/runtime kütüphaneleri bulunmalıdır:

- Fontconfig
- GTK/GDK 3.22 veya daha yeni uyumlu paketler
- libepoxy

`install.sh`, `ldd` varsa seçilen ReaImGui `.so` dosyasını kontrol eder ve `not found` bağımlılıklarını ekranda gösterir.

## Kurulum — yardımcı script

Paket kökünde:

```bash
chmod +x platform/linux/install.sh
./platform/linux/install.sh
```

Portable veya farklı resource yolu için:

```bash
./platform/linux/install.sh "/mnt/audio/REAPER-resource"
```

Script makine mimarisini otomatik seçer:

```text
x86_64/amd64   -> reaper_imgui-x86_64.so
aarch64/arm64  -> reaper_imgui-aarch64.so
i386..i686     -> reaper_imgui-i686.so
armv7l         -> reaper_imgui-armv7l.so
```

## Tamamen elle kurulum

1. Odium dosyalarını `<REAPER_RESOURCE>/Scripts/Odium Studio/` altına kopyalayın.
2. Mimarinize uygun `vendor/reaimgui/reaper_imgui-*.so` dosyasını `<REAPER_RESOURCE>/UserPlugins/` altına kopyalayın ve çalıştırma izni verin.
3. REAPER'ı tamamen kapatıp açın.
4. `Actions > Show action list > New action > Load ReaScript` ile `Scripts/Odium Studio/Register-Odium.lua` dosyasını bir kez çalıştırın.
5. Ana Odium paneli ve ayrı güncelleme kontrol eylemi Action List'e kaydolur.

## FFmpeg

Odium PATH içindeki `ffmpeg` komutunu otomatik bulur. Örnekler:

```bash
# Debian / Ubuntu
sudo apt install ffmpeg

# Arch Linux
sudo pacman -S ffmpeg
```

Fedora/RHEL tabanlı sistemlerde dağıtımınızın etkin repository'lerinden uygun FFmpeg paketini kullanın. FFmpeg olmadan proje/timeline/JSON özellikleri çalışmaya devam eder; yalnız mix split, toplu export ve ses düzeyi eşitleme işlemleri kullanılamaz.

## Portable REAPER

Portable kurulumlarda kesin resource klasörünü REAPER içindeki `Options > Show REAPER resource path in explorer/finder` benzeri komuttan teyit edin ve `install.sh` scriptine ilk argüman olarak verin.

## Kaldırma

Önce Action List'ten `Unregister-Odium.lua` çalıştırın. Ardından `Scripts/Odium Studio` klasörünü silebilirsiniz. `UserPlugins` altındaki ReaImGui başka ReaScript'ler tarafından da kullanılabileceği için kaldırma işlemi onu otomatik silmez.
