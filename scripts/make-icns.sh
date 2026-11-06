#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
OUT="$2"

if [ ! -f "$SRC" ]; then
  echo "erro: $SRC nao existe" >&2
  exit 1
fi

DIMS="$(sips -g pixelWidth -g pixelHeight "$SRC" | awk '/pixel/ {print $2}')"
WIDTH="$(echo "$DIMS" | head -1)"
HEIGHT="$(echo "$DIMS" | tail -1)"

if [ "$WIDTH" != "$HEIGHT" ]; then
  echo "aviso: a imagem e ${WIDTH}x${HEIGHT}, nao quadrada. Vai sair esticada." >&2
fi
if [ "$WIDTH" -lt 1024 ]; then
  echo "aviso: a imagem e ${WIDTH}px. O ideal e 1024x1024 (vai ficar borrada ampliando)." >&2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

resize() { sips -z "$1" "$1" "$SRC" --out "$ICONSET/$2" > /dev/null; }

resize 16   icon_16x16.png
resize 32   icon_16x16@2x.png
resize 32   icon_32x32.png
resize 64   icon_32x32@2x.png
resize 128  icon_128x128.png
resize 256  icon_128x128@2x.png
resize 256  icon_256x256.png
resize 512  icon_256x256@2x.png
resize 512  icon_512x512.png
resize 1024 icon_512x512@2x.png

mkdir -p "$(dirname "$OUT")"
iconutil -c icns "$ICONSET" -o "$OUT"

echo "icone: $OUT ($(du -h "$OUT" | cut -f1))"
