#!/bin/zsh
# Gera o instalador "Extrator-RAR.dmg" para quem não quer compilar o código.
# Ao abrir o .dmg, a pessoa só arrasta o app para a pasta Aplicativos.
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

DMG="Extrator-RAR.dmg"
STAGE=".dmg"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"

ditto "Extrator RAR.app" "$STAGE/Extrator RAR.app"
ln -s /Applications "$STAGE/Aplicativos"

hdiutil create -volname "Extrator RAR" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"
echo "Instalador pronto: $(pwd)/$DMG"
