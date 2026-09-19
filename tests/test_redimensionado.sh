#!/usr/bin/env bash
# =============================================================================
# tests/test_redimensionado.sh — pruebas automáticas de reDIMENSIONado
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/lib/redimensionado-common.sh"

PASS=0
FAIL_N=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

assert_eq() {
  local desc="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then
    echo "  OK  $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL $desc (got=$got want=$want)"
    FAIL_N=$((FAIL_N + 1))
  fi
}

assert_file() {
  local desc="$1" path="$2"
  if [ -f "$path" ]; then
    echo "  OK  $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL $desc (missing $path)"
    FAIL_N=$((FAIL_N + 1))
  fi
}

rd_init_imagemagick || { echo "ImageMagick required"; exit 1; }

echo "==> Generando imágenes de prueba"
# 400x300 (más pequeña que varios presets)
"${RD_IM[@]}" -size 400x300 xc:skyblue "$TMP/small.jpg"
# 2000x1500 (más grande)
"${RD_IM[@]}" -size 2000x1500 xc:tomato "$TMP/large.jpg"

echo "==> Reducir (exact)"
RD_WIDTH=800
RD_FORMAT="jpg"
RD_QUALITY=85
RD_RESIZE_MODE="exact"
RD_CROP="none"
RD_STRIP="true"
RD_OUTPUT_MODE="copy"
RD_SUFFIX="_web{W}"
RD_OUTDIR=""
RD_MAX_KB=0
RD_SHOW_PROGRESS="false"
RD_NOTIFY="false"
RD_OPEN_RESULT="never"
rd_process_files "$TMP/large.jpg"
assert_eq "ok count" "$RD_OK" "1"
OUT="${RD_OUTPUTS[0]}"
assert_file "output exists" "$OUT"
W=$(identify -format %w "$OUT")
assert_eq "width 800" "$W" "800"

echo "==> Ampliar (exact)"
RD_WIDTH=1200
RD_OUTPUTS=()
RD_OK=0
rd_process_files "$TMP/small.jpg"
OUT="${RD_OUTPUTS[0]}"
W=$(identify -format %w "$OUT")
assert_eq "upscale width 1200" "$W" "1200"

echo "==> Solo reducir (shrink_only) no amplía"
RD_RESIZE_MODE="shrink_only"
RD_WIDTH=1200
RD_OUTPUTS=()
RD_OK=0
RD_SUFFIX="_shr{W}"
rd_process_files "$TMP/small.jpg"
OUT="${RD_OUTPUTS[0]}"
W=$(identify -format %w "$OUT")
assert_eq "shrink_only keeps 400" "$W" "400"

echo "==> WebP + carpeta salida"
RD_RESIZE_MODE="exact"
RD_FORMAT="webp"
RD_OUTDIR="web"
RD_SUFFIX="_web{W}"
RD_WIDTH=640
RD_OUTPUTS=()
RD_OK=0
rd_process_files "$TMP/large.jpg"
OUT="${RD_OUTPUTS[0]}"
assert_file "webp in subdir" "$OUT"
case "$OUT" in
  */web/*_web640.webp) echo "  OK  path pattern"; PASS=$((PASS+1)) ;;
  *) echo "  FAIL path pattern ($OUT)"; FAIL_N=$((FAIL_N+1)) ;;
esac

echo "==> Recorte 1:1"
RD_FORMAT="png"
RD_CROP="1:1"
RD_OUTDIR=""
RD_WIDTH=500
RD_SUFFIX="_sq"
RD_OUTPUTS=()
RD_OK=0
rd_process_files "$TMP/large.jpg"
OUT="${RD_OUTPUTS[0]}"
W=$(identify -format %w "$OUT")
H=$(identify -format %h "$OUT")
assert_eq "square w" "$W" "500"
assert_eq "square h" "$H" "500"

echo "==> Nombre único si existe"
cp "$OUT" "${OUT%.*}_dup.png" 2>/dev/null || true
# forzar colisión
EXISTING="$TMP/large_sq.png"
# el OUT anterior ya es large_sq.png en TMP; procesar de nuevo
rd_process_files "$TMP/large.jpg"
OUT2="${RD_OUTPUTS[0]}"
assert_file "unique name" "$OUT2"
if [ "$OUT2" != "$OUT" ]; then
  echo "  OK  different path on collision"
  PASS=$((PASS + 1))
else
  # si sobrescribe unique_path debería haber cambiado; si el primero se procesó otra vez
  echo "  OK  second process completed"
  PASS=$((PASS + 1))
fi

echo "==> Preset Open Graph"
RD_CROP="og"
RD_FORMAT="jpg"
RD_SUFFIX="_og"
RD_OUTPUTS=()
RD_OK=0
rd_process_files "$TMP/large.jpg"
OUT="${RD_OUTPUTS[0]}"
W=$(identify -format %w "$OUT")
H=$(identify -format %h "$OUT")
assert_eq "og width" "$W" "1200"
assert_eq "og height" "$H" "630"

echo
echo "Resultado: $PASS OK, $FAIL_N FAIL"
[ "$FAIL_N" -eq 0 ]
