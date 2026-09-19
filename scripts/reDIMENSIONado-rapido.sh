#!/usr/bin/env bash
# =============================================================================
# Acciones rápidas: aplica un preset sin diálogo (usa preferencias).
# Uso: reDIMENSIONado-rapido.sh <preset|ancho> [archivos…]
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f /usr/share/redimensionado/lib/redimensionado-common.sh ]; then
  # shellcheck disable=SC1091
  source /usr/share/redimensionado/lib/redimensionado-common.sh
else
  # shellcheck disable=SC1091
  source "$ROOT/lib/redimensionado-common.sh"
fi

PRESET="${1:-}"
shift || true
[ -n "$PRESET" ] || { echo "Uso: $0 <preset|ancho> [archivos…]" >&2; exit 1; }

rd_load_config
rd_preset_width "$PRESET"

rd_files_from_nautilus
if [ "${#RD_FILES[@]}" -eq 0 ]; then
  RD_FILES=("$@")
fi
if [ "${#RD_FILES[@]}" -eq 0 ]; then
  rd_zenity_opts
  zenity "${RD_ZENITY_OPTS[@]}" --error --title="$RD_APP_NAME" \
    --text="No hay archivos seleccionados." 2>/dev/null || true
  exit 1
fi

if [ "$RD_OUTPUT_MODE" = "replace" ]; then
  rd_zenity_opts
  zenity "${RD_ZENITY_OPTS[@]}" --question --title="$RD_APP_NAME" \
    --text="Preferencias: sobrescribir originales.\n¿Continuar?" \
    --ok-label="Sí" --cancel-label="No" || exit 0
fi

rd_process_files "${RD_FILES[@]}"
rd_show_summary
