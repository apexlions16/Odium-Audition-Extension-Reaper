#!/bin/bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RESOURCE="${1:-$HOME/Library/Application Support/REAPER}"
DEST="$RESOURCE/Scripts/Odium Studio"
USERPLUGINS="$RESOURCE/UserPlugins"

printf '\nOdium Studio - macOS manuel kurulum yardımcısı\n'
printf 'REAPER resource: %s\n\n' "$RESOURCE"

mkdir -p "$DEST/lib" "$DEST/tools" "$DEST/vendor/reaimgui" "$USERPLUGINS"

for f in Odium_Reaper_Extension.lua Odium_Check_For_Updates.lua Register-Odium.lua Unregister-Odium.lua README.md version.json THIRD_PARTY_NOTICES.md; do
  [ -f "$ROOT/$f" ] && cp -f "$ROOT/$f" "$DEST/$f"
done
cp -f "$ROOT"/lib/*.lua "$DEST/lib/"

if [ -d "$ROOT/vendor/reaimgui" ]; then
  cp -f "$ROOT"/vendor/reaimgui/* "$DEST/vendor/reaimgui/" 2>/dev/null || true
fi

ARCH="$(uname -m)"
case "$ARCH" in
  arm64|aarch64) IMGUI="reaper_imgui-arm64.dylib" ;;
  x86_64|amd64) IMGUI="reaper_imgui-x86_64.dylib" ;;
  i386|i686)     IMGUI="reaper_imgui-i386.dylib" ;;
  *)
    echo "Desteklenmeyen macOS mimarisi: $ARCH"
    echo "vendor/reaimgui içinden uygun ReaImGui dylib dosyasını elle seçebilirsiniz."
    exit 2
    ;;
esac

if [ ! -f "$ROOT/vendor/reaimgui/$IMGUI" ]; then
  echo "ReaImGui binary pakette bulunamadı: $IMGUI"
  exit 3
fi

cp -f "$ROOT/vendor/reaimgui/$IMGUI" "$USERPLUGINS/$IMGUI"
chmod 755 "$USERPLUGINS/$IMGUI" || true

echo "ReaImGui kuruldu: $USERPLUGINS/$IMGUI"

if command -v ffmpeg >/dev/null 2>&1; then
  echo "FFmpeg hazır: $(command -v ffmpeg)"
else
  echo "UYARI: FFmpeg PATH içinde bulunamadı. Homebrew kullanıyorsanız: brew install ffmpeg"
  echo "FFmpeg olmadan timeline/JSON özellikleri çalışır; mix split, export ve seviye eşitleme çalışmaz."
fi

cat <<EOF

Dosyalar kopyalandı: $DEST

Son manuel kayıt adımı:
1. REAPER'ı yeniden başlatın (ReaImGui'nin yüklenmesi için).
2. Actions > Show action list > New action > Load ReaScript
3. Şu dosyayı bir kez seçin:
   $DEST/Register-Odium.lua
4. Register script ana paneli ve "Odium Studio - Güncelleme Kontrolü" eylemini kaydeder.

Portable REAPER kullanıyorsanız bu scripti resource klasörünü argüman vererek çalıştırın:
  ./install.command "/path/to/REAPER-resource"

Apple Silicon, Intel x86_64 ve eski i386 ReaImGui binary'leri paket içinde tutulur; script mevcut makinenin mimarisini seçer.
EOF
