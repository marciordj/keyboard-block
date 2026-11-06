#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
IDENTITY="${CODESIGN_IDENTITY:--}"
APP="build/KeyboardBlock.app"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/KeyboardBlock"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/KeyboardBlock"
cp Resources/Info.plist "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" > /dev/null

if [ -f Resources/AppIcon.png ]; then
  ./scripts/make-icns.sh Resources/AppIcon.png "$APP/Contents/Resources/AppIcon.icns"
elif [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
  echo "icone: Resources/AppIcon.icns"
else
  echo "sem icone (Resources/AppIcon.png) — usando o icone generico do sistema"
fi

if [ "$IDENTITY" = "-" ]; then
  codesign --force --sign - "$APP"
  echo "Assinado ad-hoc."
  echo "Aviso: a cada rebuild o macOS pode pedir a permissão de Acessibilidade de novo."
  echo "Para evitar isso, use uma identidade estavel:"
  echo "  CODESIGN_IDENTITY=\"Apple Development: voce@exemplo.com (XXXXXXXXXX)\" ./scripts/build-app.sh"
else
  codesign --force --sign "$IDENTITY" --options runtime "$APP"
  echo "Assinado com: $IDENTITY"
fi

# Faz o LaunchServices perceber o bundle novo.
touch "$APP"

echo
echo "Pronto: $APP"
echo "Rodar agora: open \"$APP\""
