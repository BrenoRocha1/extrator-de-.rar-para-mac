#!/bin/zsh
# Compila o "Extrator RAR.app" nesta pasta.
set -euo pipefail
cd "$(dirname "$0")"

APP="Extrator RAR.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -parse-as-library Sources/ExtratorRAR.swift -o "$APP/Contents/MacOS/ExtratorRAR"
cp Info.plist "$APP/Contents/Info.plist"

# Ícone gerado a partir do símbolo "archivebox"
swift Sources/MakeIcon.swift "$APP/Contents/Resources/AppIcon.iconset" >/dev/null
iconutil -c icns "$APP/Contents/Resources/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$APP/Contents/Resources/AppIcon.iconset"

codesign --force --deep --sign - "$APP"
echo "Pronto: $(pwd)/$APP"
