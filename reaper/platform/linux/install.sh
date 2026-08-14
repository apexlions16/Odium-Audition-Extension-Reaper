#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RESOURCE="${1:-$HOME/.config/REAPER}"
DEST="$RESOURCE/Scripts/Odium Studio"
USERPLUGINS="$RESOURCE/UserPlugins"
IMGUI_API="$RESOURCE/Scripts/ReaTeam Extensions/API"

printf '\nOdium Studio - Linux manuel kurulum yardımcısı\n'
printf 'REAPER resource: %s\n\n' "$RESOURCE"

mkdir -p "$DEST/lib" "$DEST/tools" "$DEST/vendor/reaimgui" "$USERPLUGINS" "$IMGUI_API"

for f in Odium_Reaper_Extension.lua Odium_Check_For_Updates.lua Register-Odium.lua Unregister-Odium.lua README.md version.json THIRD_PARTY_NOTICES.md; do
  [[ -f "$ROOT/$f" ]] && cp -f "$ROOT/$f" "$DEST/$f"
done
cp -f "$ROOT"/lib/*.lua "$DEST/lib/"

if [[ -d "$ROOT/vendor/reaimgui" ]]; then
  cp -R "$ROOT/vendor/reaimgui/." "$DEST/vendor/reaimgui/"
fi

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) IMGUI="reaper_imgui-x86_64.so" ;;
  aarch64|arm64) IMGUI="reaper_imgui-aarch64.so" ;;
  i386|i486|i586|i686) IMGUI="reaper_imgui-i686.so" ;;
  armv7l|armv7*) IMGUI="reaper_imgui-armv7l.so" ;;
  *)
    echo "Desteklenmeyen Linux mimarisi: $ARCH"
    echo "vendor/reaimgui içinden uygun ReaImGui binary'sini elle seçebilirsiniz."
    exit 2
    ;;
esac

if [[ ! -f "$ROOT/vendor/reaimgui/$IMGUI" ]]; then
  echo "ReaImGui binary pakette bulunamadı: $IMGUI"
  exit 3
fi
if [[ ! -f "$ROOT/vendor/reaimgui/api/imgui.lua" ]]; then
  echo "ReaImGui Lua shim pakette bulunamadı: vendor/reaimgui/api/imgui.lua"
  exit 4
fi

cp -f "$ROOT/vendor/reaimgui/$IMGUI" "$USERPLUGINS/$IMGUI"
chmod 755 "$USERPLUGINS/$IMGUI" || true
cp -f "$ROOT/vendor/reaimgui/api/imgui.lua" "$IMGUI_API/imgui.lua"
echo "ReaImGui kuruldu: $USERPLUGINS/$IMGUI"
echo "ReaImGui Lua shim kuruldu: $IMGUI_API/imgui.lua"

if command -v ldd >/dev/null 2>&1; then
  MISSING="$(ldd "$USERPLUGINS/$IMGUI" 2>/dev/null | grep 'not found' || true)"
  if [[ -n "$MISSING" ]]; then
    echo
    echo "UYARI: ReaImGui için eksik Linux runtime kütüphaneleri bulundu:"
    echo "$MISSING"
    echo "Fontconfig, GTK/GDK 3.22+ ve libepoxy paketlerini dağıtımınızdan kurun."
  fi
fi

if command -v ffmpeg >/dev/null 2>&1; then
  echo "FFmpeg hazır: $(command -v ffmpeg)"
else
  echo "UYARI: FFmpeg PATH içinde bulunamadı."
  echo "Debian/Ubuntu: sudo apt install ffmpeg"
  echo "Fedora/RHEL türevleri: dağıtımınızın FFmpeg paketini kurun."
  echo "Arch: sudo pacman -S ffmpeg"
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

Portable/custom REAPER resource klasörü kullanıyorsanız:
  ./install.sh "/path/to/REAPER-resource"

Desteklenen paket mimarileri: x86_64, aarch64/arm64, i686 ve armv7l.
EOF
