#!/bin/zsh
# Compila o "Extrator RAR.app" nesta pasta.
# O app é "universal": roda em Macs com Apple Silicon (M1, M2...) e com Intel.
set -euo pipefail
cd "$(dirname "$0")"

APP="Extrator RAR.app"
BUILD=".build"
rm -rf "$APP" "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD"

# Compila uma vez para cada processador e junta os dois num binário só
for arch in arm64 x86_64; do
    swiftc -O -parse-as-library -target "$arch-apple-macos14.0" Sources/ExtratorRAR.swift -o "$BUILD/ExtratorRAR-$arch"
done
lipo -create "$BUILD"/ExtratorRAR-* -output "$APP/Contents/MacOS/ExtratorRAR"
rm -rf "$BUILD"

cp Info.plist "$APP/Contents/Info.plist"

# Ícone desenhado pelo MakeIcon.swift
swift Sources/MakeIcon.swift "$APP/Contents/Resources/AppIcon.iconset" >/dev/null
iconutil -c icns "$APP/Contents/Resources/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$APP/Contents/Resources/AppIcon.iconset"

codesign --force --deep --sign - "$APP"
echo "Pronto: $(pwd)/$APP"
