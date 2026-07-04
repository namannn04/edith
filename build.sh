#!/usr/bin/env bash
#
# build.sh — build Edith.app from the Swift package.
#
#   ./build.sh            # build into dist/Edith.app and launch it
#   ./build.sh --install  # also copy to /Applications and launch from there
#
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

# Icon: regenerate only when missing (make-icon.swift draws it locally).
if [ ! -f AppIcon.icns ]; then
  swift make-icon.swift AppIcon.png
  rm -rf AppIcon.iconset && mkdir AppIcon.iconset
  for s in 16 32 128 256 512; do
    sips -z $s $s AppIcon.png --out "AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) AppIcon.png --out "AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns AppIcon.iconset -o AppIcon.icns
  rm -rf AppIcon.iconset AppIcon.png
fi

APP="dist/Edith.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Edith "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp AppIcon.icns "$APP/Contents/Resources/"
# the logo glyph the app loads for the menu bar + header (256px is plenty)
sips -z 256 256 Assets/logo.png --out "$APP/Contents/Resources/Logo.png" >/dev/null
codesign --force --sign - "$APP"

killall Edith 2>/dev/null || true
killall ControlCenter 2>/dev/null || true # pre-rename binary name
if [ "${1:-}" = "--install" ]; then
  rm -rf "/Applications/Edith.app" "/Applications/Control Center.app"
  cp -R "$APP" /Applications/
  open "/Applications/Edith.app"
else
  open "$APP"
fi
