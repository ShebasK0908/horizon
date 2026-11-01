#!/usr/bin/env bash
# make-ipa.sh — empaqueta un binario iOS de Horizon como .ipa SIN FIRMAR.
#
# Uso:
#   bash packaging-ios/make-ipa.sh <binario-ios> [carpeta-de-recursos] [salida.ipa]
#
#   <binario-ios>        El ejecutable compilado para aarch64-apple-ios,
#                        p. ej. target/aarch64-apple-ios/release/horizon-client
#   [carpeta-de-recursos] Opcional. Si se pasa y existe, su contenido se copia
#                        dentro de Horizon.app/resources/ (los recursos
#                        preparados con horizon-prepare van aquí o, más tarde,
#                        se copiarán al contenedor de la app; NO se inventan
#                        si faltan).
#   [salida.ipa]         Por defecto: Horizon-unsigned.ipa en el directorio
#                        actual.
#
# Honestidad del script: si falta el binario, falta el Info.plist de la
# plantilla o el zip no se crea, el script sale con error (exit != 0).
# Nunca produce un .ipa vacío para simular éxito. El .ipa sale sin firmar:
# lo firma la herramienta de sideload del usuario (LiveContainer/SideStore)
# al instalarlo en su iPhone.

set -euo pipefail

BINARY="${1:-}"
ASSETS_DIR="${2:-}"
OUTPUT="${3:-Horizon-unsigned.ipa}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_SRC="$SCRIPT_DIR/Info.plist"
APP_NAME="Horizon"

fail() {
    echo "make-ipa: ERROR: $*" >&2
    exit 1
}

[ -n "$BINARY" ] || fail "uso: make-ipa.sh <binario-ios> [carpeta-de-recursos] [salida.ipa]"
[ -f "$BINARY" ] || fail "no existe el binario iOS: $BINARY (¿pasó el cargo build para aarch64-apple-ios?)"
[ -f "$PLIST_SRC" ] || fail "no se encuentra la plantilla Info.plist junto al script: $PLIST_SRC"
if [ -n "$ASSETS_DIR" ] && [ ! -d "$ASSETS_DIR" ]; then
    fail "la carpeta de recursos indicada no existe: $ASSETS_DIR"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
APP="$WORK/Payload/$APP_NAME.app"
mkdir -p "$APP"

# El ejecutable dentro de la .app se llama como dice CFBundleExecutable
# (Horizon) en la plantilla Info.plist.
cp "$BINARY" "$APP/$APP_NAME"
chmod +x "$APP/$APP_NAME"
cp "$PLIST_SRC" "$APP/Info.plist"

if [ -n "$ASSETS_DIR" ]; then
    mkdir -p "$APP/resources"
    cp -R "$ASSETS_DIR"/. "$APP/resources/"
    echo "make-ipa: recursos copiados desde $ASSETS_DIR"
fi

OUTPUT_ABS="$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")"
rm -f "$OUTPUT_ABS"
( cd "$WORK" && zip -qr "$OUTPUT_ABS" Payload )

[ -f "$OUTPUT_ABS" ] || fail "el zip no se creó: $OUTPUT_ABS"
SIZE="$(du -h "$OUTPUT_ABS" | cut -f1)"
echo "make-ipa: OK -> $OUTPUT_ABS ($SIZE), sin firmar"
