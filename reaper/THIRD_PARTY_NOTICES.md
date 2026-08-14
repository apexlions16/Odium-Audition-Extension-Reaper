# Third-party notices

Odium Studio REAPER dağıtımı, aşağıdaki üçüncü taraf bileşenlerle birlikte çalışır veya paketleme sırasında bunların resmi runtime dosyalarını indirir.

## ReaImGui

- Proje: **ReaImGui** — ReaScript binding and REAPER backend for Dear ImGui
- Sabitlenen dağıtım sürümü: `v0.10.0.5`
- Kaynak: `cfillion/reaimgui` (proje 2026'da Codeberg'e taşınmıştır; bu sürümün GitHub release/runtime dosyaları sabitlenmiştir)
- Lisans: LGPL-3.0/GPL-3.0 bileşenleri. Dağıtım paketleri build sırasında upstream `COPYING` ve `COPYING.LESSER` dosyalarını da içerir.
- Native binary dosyaları upstream release SHA-256 değerleriyle doğrulanır.
- ReaImGui 0.10 Lua shim dosyası `shims/imgui.lua` da sabitlenir ve SHA-256 `b73dac959d973e2d8fb47ea73588e84f81d4a3c7fb962c327d08427c2454b093` ile doğrulanır.

Odium, ReaImGui runtime dosyalarını değiştirmez. Native binary REAPER `UserPlugins` dizinine, `imgui.lua` ise upstream runtime düzeniyle uyumlu olarak `Scripts/ReaTeam Extensions/API/imgui.lua` yoluna kurulur. macOS/Linux manuel paketleri desteklenen mimarilerin upstream native binary'lerini birlikte taşır.

## FFmpeg

- Proje: **FFmpeg**
- Windows otomatik kurulum kaynağı: Gyan Doshi'nin FFmpeg Windows builds dağıtımı
- Sabitlenen paket: `ffmpeg-8.1.2-essentials_build.zip`
- SHA-256: `db580001caa24ac104c8cb856cd113a87b0a443f7bdf47d8c12b1d740584a2ec`
- Paket lisansı upstream build özelliklerine göre GPLv3'tür.

Windows kurucusu FFmpeg'i yalnız Odium'un kendi `tools` klasörüne koyar; sistem PATH'ini değiştirmez. macOS ve Linux manuel paketlerinde FFmpeg binary'si yeniden dağıtılmaz; kullanıcı sistem paket yöneticisinden veya mevcut kurulumundan `ffmpeg` sağlamalıdır.

## REAPER

REAPER Cockos ürünüdür ve Odium dağıtımına dahil edilmez. Odium, REAPER ReaScript API'sini kullanır.
