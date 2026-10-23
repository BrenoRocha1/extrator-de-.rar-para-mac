#!/bin/zsh
# Compila o "Extrator RAR.app" nesta pasta.
# O app é "universal": roda em Macs com Apple Silicon (M1, M2...) e com Intel.
set -euo pipefail
cd "$(dirname "$0")"

APP="Extrator RAR.app"
BUILD=".build"

# 7-Zip (7zz), embutido no app para senhas, arquivos em partes e compactação.
# Versão fixa e conferida pelo SHA-256, baixada do repositório oficial do autor (Igor Pavlov).
SEVENZIP_VERSION="26.04"
SEVENZIP_FILE="7z2604-mac.tar.xz"
SEVENZIP_SHA256="bee04358cbcbc7106273cee0e8d72916db2696c48067a3538c34d8cd6fd16578"
VENDOR="vendor/7zip-$SEVENZIP_VERSION"

if [[ ! -x "$VENDOR/7zz" ]]; then
    echo "Baixando o 7-Zip $SEVENZIP_VERSION..."
    mkdir -p "$VENDOR"
    curl -fsSL -o "$VENDOR/$SEVENZIP_FILE" "https://github.com/ip7z/7zip/releases/download/$SEVENZIP_VERSION/$SEVENZIP_FILE"
    echo "$SEVENZIP_SHA256  $VENDOR/$SEVENZIP_FILE" | shasum -a 256 -c - >/dev/null || {
        echo "Erro: o arquivo do 7-Zip baixado não confere com o SHA-256 esperado." >&2
        rm -rf "$VENDOR"
        exit 1
    }
    tar -xJf "$VENDOR/$SEVENZIP_FILE" -C "$VENDOR" 7zz License.txt
    rm "$VENDOR/$SEVENZIP_FILE"
fi

rm -rf "$APP" "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD"

# Compila uma vez para cada processador e junta os dois num binário só
SOURCES=(Sources/ExtratorRAR.swift Sources/Engine.swift Sources/RarWriter.swift)
for arch in arm64 x86_64; do
    swiftc -O -parse-as-library -target "$arch-apple-macos14.0" $SOURCES -o "$BUILD/ExtratorRAR-$arch"
done
lipo -create "$BUILD"/ExtratorRAR-* -output "$APP/Contents/MacOS/ExtratorRAR"
rm -rf "$BUILD"

cp Info.plist "$APP/Contents/Info.plist"
cp "$VENDOR/7zz" "$APP/Contents/MacOS/7zz"
cp "$VENDOR/License.txt" "$APP/Contents/Resources/7-Zip-License.txt"
xattr -cr "$APP"

# Ícone desenhado pelo MakeIcon.swift
swift Sources/MakeIcon.swift "$APP/Contents/Resources/AppIcon.iconset" >/dev/null
iconutil -c icns "$APP/Contents/Resources/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$APP/Contents/Resources/AppIcon.iconset"

codesign --force --deep --sign - "$APP"
echo "Pronto: $(pwd)/$APP"
