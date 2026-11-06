#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/build-app.sh

DEST="/Applications/KeyboardBlock.app"
rm -rf "$DEST"
cp -R "build/KeyboardBlock.app" "$DEST"
touch "$DEST"

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST" 2>/dev/null || true

echo
echo "Instalado em $DEST"
echo "Abrir: open -a KeyboardBlock"
echo
echo "Se o ícone antigo insistir em cache: killall Finder"
echo
echo "Se o macOS reclamar de permissao, rode: sudo chown -R \"\$USER\":admin \"$DEST\""
