#!/usr/bin/env bash
# =============================================================================
# redimensionado-common.sh — lógica compartida de reDIMENSIONado
# -----------------------------------------------------------------------------
# Se carga con: source /ruta/a/redimensionado-common.sh
# No ejecutar directamente.
# =============================================================================

# Evitar doble carga
if [ "${RD_COMMON_LOADED:-0}" = "1" ]; then
  return 0 2>/dev/null || true
fi
RD_COMMON_LOADED=1

RD_APP_NAME="reDIMENSIONado"
RD_PKG_NAME="redimensionado"
RD_ICON="/usr/share/redimensionado/logo.png"
RD_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/redimensionado"
RD_CONFIG_FILE="${RD_CONFIG_DIR}/config"
RD_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/redimensionado"
RD_LOG_FILE="${RD_LOG_DIR}/errores.log"

# Valores por defecto (sobreescribibles por config / CLI)
RD_WIDTH="1200"
RD_FORMAT="keep"          # keep|jpg|png|webp|avif
RD_QUALITY="85"           # 60|75|85|95
RD_RESIZE_MODE="exact"    # exact|shrink_only
RD_CROP="none"            # none|1:1|16:9|4:3|og
RD_STRIP="true"           # true|false
RD_OUTPUT_MODE="copy"     # copy|replace
RD_SUFFIX="_web{W}"       # {W}=ancho
RD_OUTDIR=""              # vacío = misma carpeta; relativo o absoluto
RD_MAX_KB="0"             # 0 = sin límite
RD_NOTIFY="true"
RD_OPEN_RESULT="ask"      # ask|always|never
RD_SHOW_PROGRESS="true"

# Contadores de sesión
RD_OK=0
RD_FAIL=0
RD_SKIP=0
RD_OUTPUTS=()
RD_ERRORS=()

# ---------------------------------------------------------------------------
# ImageMagick
# ---------------------------------------------------------------------------
rd_init_imagemagick() {
  if command -v convert >/dev/null 2>&1; then
    RD_IM=(convert)
  elif command -v magick >/dev/null 2>&1; then
    RD_IM=(magick)
  else
    return 1
  fi
  return 0
}

rd_zenity_opts() {
  RD_ZENITY_OPTS=()
  if [ -f "$RD_ICON" ]; then
    RD_ZENITY_OPTS+=(--window-icon="$RD_ICON")
  fi
}

# ---------------------------------------------------------------------------
# Configuración
# ---------------------------------------------------------------------------
rd_default_config_text() {
  cat <<'EOF'
# Preferencias de reDIMENSIONado
# Puedes editarlas a mano o con: Scripts → reDIMENSIONado → Preferencias

# Ancho por defecto (píxeles) para acciones rápidas
default_width=1200

# Formato de salida: keep | jpg | png | webp | avif
format=keep

# Calidad (formatos con pérdida): 60 | 75 | 85 | 95
quality=85

# exact = forzar ancho (ampliar o reducir)
# shrink_only = solo reducir si es más ancha
resize_mode=exact

# Recorte previo: none | 1:1 | 16:9 | 4:3 | og  (og = 1200x630 Open Graph)
crop=none

# Quitar metadatos EXIF: true | false
strip_exif=true

# copy = crear copia | replace = sobrescribir original
output_mode=copy

# Sufijo del fichero copia. {W} se sustituye por el ancho.
suffix=_web{W}

# Carpeta de salida relativa al original, o ruta absoluta. Vacío = misma carpeta.
# Ejemplo: web   →  ./web/foto_web1200.jpg
output_dir=

# Límite de peso en KB (0 = desactivado). Ajusta calidad hasta cumplir.
max_kb=0

# Notificación de escritorio al terminar: true | false
notify=true

# Tras terminar: ask | always | never  (abrir carpeta del primer resultado)
open_result=ask

# Barra de progreso en lotes: true | false
show_progress=true
EOF
}

rd_ensure_config() {
  mkdir -p "$RD_CONFIG_DIR"
  if [ ! -f "$RD_CONFIG_FILE" ]; then
    rd_default_config_text > "$RD_CONFIG_FILE"
  fi
}

rd_load_config() {
  rd_ensure_config
  # shellcheck disable=SC1090
  while IFS='=' read -r key value || [ -n "$key" ]; do
    key="${key%%#*}"
    key="$(echo "$key" | tr -d '[:space:]')"
    [ -z "$key" ] && continue
    value="${value%%#*}"
    value="$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    case "$key" in
      default_width) RD_WIDTH="$value" ;;
      format) RD_FORMAT="$value" ;;
      quality) RD_QUALITY="$value" ;;
      resize_mode) RD_RESIZE_MODE="$value" ;;
      crop) RD_CROP="$value" ;;
      strip_exif) RD_STRIP="$value" ;;
      output_mode) RD_OUTPUT_MODE="$value" ;;
      suffix) RD_SUFFIX="$value" ;;
      output_dir) RD_OUTDIR="$value" ;;
      max_kb) RD_MAX_KB="$value" ;;
      notify) RD_NOTIFY="$value" ;;
      open_result) RD_OPEN_RESULT="$value" ;;
      show_progress) RD_SHOW_PROGRESS="$value" ;;
    esac
  done < "$RD_CONFIG_FILE"
}

rd_save_config() {
  rd_ensure_config
  cat > "$RD_CONFIG_FILE" <<EOF
# Preferencias de reDIMENSIONado (generado automáticamente)
default_width=${RD_WIDTH}
format=${RD_FORMAT}
quality=${RD_QUALITY}
resize_mode=${RD_RESIZE_MODE}
crop=${RD_CROP}
strip_exif=${RD_STRIP}
output_mode=${RD_OUTPUT_MODE}
suffix=${RD_SUFFIX}
output_dir=${RD_OUTDIR}
max_kb=${RD_MAX_KB}
notify=${RD_NOTIFY}
open_result=${RD_OPEN_RESULT}
show_progress=${RD_SHOW_PROGRESS}
EOF
}

# ---------------------------------------------------------------------------
# Utilidades de ficheros
# ---------------------------------------------------------------------------
rd_is_image() {
  local f="${1,,}"
  case "$f" in
    *.jpg|*.jpeg|*.png|*.webp|*.gif|*.tif|*.tiff|*.bmp|*.heic|*.heif|*.avif|*.svg|*.svgz|*.pdf)
      return 0 ;;
    *) return 1 ;;
  esac
}

rd_expand_suffix() {
  local s="$1"
  s="${s//\{W\}/${RD_WIDTH}}"
  s="${s//\{w\}/${RD_WIDTH}}"
  printf '%s' "$s"
}

# Si el destino existe, añade _2, _3, ...
rd_unique_path() {
  local path="$1"
  local dir base name ext candidate n
  if [ ! -e "$path" ]; then
    printf '%s' "$path"
    return
  fi
  dir=$(dirname "$path")
  base=$(basename "$path")
  name="${base%.*}"
  ext="${base##*.}"
  if [ "$name" = "$base" ]; then
    ext=""
  fi
  n=2
  while true; do
    if [ -n "$ext" ] && [ "$name" != "$base" ]; then
      candidate="${dir}/${name}_${n}.${ext}"
    else
      candidate="${dir}/${name}_${n}"
    fi
    if [ ! -e "$candidate" ]; then
      printf '%s' "$candidate"
      return
    fi
    n=$((n + 1))
  done
}

rd_log_error() {
  mkdir -p "$RD_LOG_DIR"
  printf '%s | %s | %s\n' "$(date -Iseconds)" "$1" "$2" >> "$RD_LOG_FILE"
  RD_ERRORS+=("$1: $2")
}

# ---------------------------------------------------------------------------
# Geometría ImageMagick según crop + resize_mode
# ---------------------------------------------------------------------------
# Recorte centrado a ratio, luego redimensionado al ancho.
rd_build_ops() {
  # Rellena RD_OPS para ImageMagick (compatible con IM6 convert).
  # Recorte: resize con ^ (cubrir) + extent centrado al ratio deseado.
  RD_OPS=(-auto-orient)
  local h

  case "$RD_CROP" in
    1:1)
      h=$RD_WIDTH
      RD_OPS+=(-resize "${RD_WIDTH}x${h}^" -gravity center -extent "${RD_WIDTH}x${h}")
      ;;
    16:9)
      h=$((RD_WIDTH * 9 / 16))
      RD_OPS+=(-resize "${RD_WIDTH}x${h}^" -gravity center -extent "${RD_WIDTH}x${h}")
      ;;
    4:3)
      h=$((RD_WIDTH * 3 / 4))
      RD_OPS+=(-resize "${RD_WIDTH}x${h}^" -gravity center -extent "${RD_WIDTH}x${h}")
      ;;
    og)
      # Open Graph 1200×630
      RD_OPS+=(-resize "1200x630^" -gravity center -extent "1200x630")
      ;;
    none|""|*)
      if [ "$RD_RESIZE_MODE" = "shrink_only" ]; then
        RD_OPS+=(-resize "${RD_WIDTH}x>")
      else
        RD_OPS+=(-resize "${RD_WIDTH}x")
      fi
      ;;
  esac

  if [ "$RD_STRIP" = "true" ] || [ "$RD_STRIP" = "1" ] || [ "$RD_STRIP" = "yes" ]; then
    RD_OPS+=(-strip)
  fi

  RD_OPS+=(-quality "$RD_QUALITY")
}

rd_out_extension() {
  local src_ext="$1"
  case "${RD_FORMAT,,}" in
    jpg|jpeg) printf 'jpg' ;;
    png) printf 'png' ;;
    webp) printf 'webp' ;;
    avif) printf 'avif' ;;
    keep|*) printf '%s' "${src_ext,,}" ;;
  esac
}

rd_resolve_outdir() {
  local src_dir="$1"
  if [ -z "$RD_OUTDIR" ]; then
    printf '%s' "$src_dir"
    return
  fi
  case "$RD_OUTDIR" in
    /*) printf '%s' "$RD_OUTDIR" ;;
    *) printf '%s/%s' "$src_dir" "$RD_OUTDIR" ;;
  esac
}

# Reduce calidad hasta cumplir max_kb (solo jpg/webp/avif)
rd_enforce_max_kb() {
  local file="$1"
  local max_kb="$RD_MAX_KB"
  [ "${max_kb:-0}" -gt 0 ] 2>/dev/null || return 0

  local q="$RD_QUALITY"
  local size_kb
  while [ "$q" -ge 40 ]; do
    size_kb=$(du -k "$file" | awk '{print $1}')
    if [ "$size_kb" -le "$max_kb" ]; then
      return 0
    fi
    q=$((q - 5))
    "${RD_IM[@]}" "$file" -quality "$q" "$file" 2>/dev/null || return 1
  done
  return 0
}

# ---------------------------------------------------------------------------
# Procesar un fichero
# ---------------------------------------------------------------------------
rd_process_one() {
  local FILE="$1"
  local DIR BASE NAME EXT OUT_EXT OUT_DIR OUT SUFFIX INPUT_SPEC

  if [ ! -f "$FILE" ]; then
    RD_SKIP=$((RD_SKIP + 1))
    rd_log_error "$FILE" "no es un fichero regular"
    return 1
  fi
  if ! rd_is_image "$FILE"; then
    RD_SKIP=$((RD_SKIP + 1))
    return 1
  fi

  DIR=$(dirname "$FILE")
  BASE=$(basename "$FILE")
  NAME="${BASE%.*}"
  EXT="${BASE##*.}"

  # PDF / SVG: rasterizar (primera página del PDF)
  INPUT_SPEC="$FILE"
  case "${EXT,,}" in
    pdf) INPUT_SPEC="${FILE}[0]" ;;
  esac

  OUT_EXT=$(rd_out_extension "$EXT")
  # PDF/SVG sin formato elegido → png
  if [ "${RD_FORMAT}" = "keep" ]; then
    case "${EXT,,}" in
      pdf|svg|svgz) OUT_EXT="png" ;;
      heic|heif) OUT_EXT="jpg" ;;
    esac
  fi

  OUT_DIR=$(rd_resolve_outdir "$DIR")
  mkdir -p "$OUT_DIR" || {
    RD_FAIL=$((RD_FAIL + 1))
    rd_log_error "$FILE" "no se pudo crear carpeta $OUT_DIR"
    return 1
  }

  SUFFIX=$(rd_expand_suffix "$RD_SUFFIX")

  if [ "$RD_OUTPUT_MODE" = "replace" ]; then
    # Sustituye el original (misma ruta si extensión coincide; si no, nuevo + borrar)
    if [ "${EXT,,}" = "$OUT_EXT" ]; then
      OUT="$FILE"
    else
      OUT="${DIR}/${NAME}.${OUT_EXT}"
      OUT=$(rd_unique_path "$OUT")
    fi
  else
    OUT="${OUT_DIR}/${NAME}${SUFFIX}.${OUT_EXT}"
    OUT=$(rd_unique_path "$OUT")
  fi

  rd_build_ops

  local tmp
  tmp=$(mktemp --suffix=".${OUT_EXT}")
  # shellcheck disable=SC2068
  if ! "${RD_IM[@]}" "$INPUT_SPEC" ${RD_OPS[@]+"${RD_OPS[@]}"} "$tmp" 2>/tmp/rd-im-err.$$; then
    RD_FAIL=$((RD_FAIL + 1))
    rd_log_error "$FILE" "$(tr '\n' ' ' </tmp/rd-im-err.$$ 2>/dev/null | head -c 200)"
    rm -f "$tmp" /tmp/rd-im-err.$$
    return 1
  fi
  rm -f /tmp/rd-im-err.$$

  rd_enforce_max_kb "$tmp" || true

  if [ "$RD_OUTPUT_MODE" = "replace" ] && [ "$OUT" = "$FILE" ]; then
    mv -f "$tmp" "$OUT"
  elif [ "$RD_OUTPUT_MODE" = "replace" ]; then
    mv -f "$tmp" "$OUT"
    # Borrar original solo si la ruta cambió (otro formato)
    if [ "$OUT" != "$FILE" ]; then
      rm -f "$FILE"
    fi
  else
    mv -f "$tmp" "$OUT"
  fi

  RD_OK=$((RD_OK + 1))
  RD_OUTPUTS+=("$OUT")
  return 0
}

# ---------------------------------------------------------------------------
# Procesar lista de ficheros (con progreso opcional)
# ---------------------------------------------------------------------------
rd_process_files() {
  local files=("$@")
  local total=${#files[@]}
  local i=0
  local f

  RD_OK=0
  RD_FAIL=0
  RD_SKIP=0
  RD_OUTPUTS=()
  RD_ERRORS=()

  if ! rd_init_imagemagick; then
    rd_log_error "-" "ImageMagick no disponible"
    return 1
  fi

  if [ "$total" -eq 0 ]; then
    return 1
  fi

  if [ "$RD_SHOW_PROGRESS" = "true" ] && [ "$total" -gt 1 ] && command -v zenity >/dev/null 2>&1; then
    rd_zenity_opts
    # Process substitution: el bucle sigue en este shell (no pierde contadores).
    exec 3> >(zenity "${RD_ZENITY_OPTS[@]}" --progress \
        --title="$RD_APP_NAME" \
        --text="Procesando imágenes…" \
        --percentage=0 \
        --auto-close \
        --auto-kill 2>/dev/null)
    for f in "${files[@]}"; do
      i=$((i + 1))
      percent=$((i * 100 / total))
      echo "$percent" >&3 || true
      echo "# ($i/$total) $(basename "$f")" >&3 || true
      rd_process_one "$f" || true
    done
    echo "100" >&3 || true
    echo "# Listo" >&3 || true
    exec 3>&-
  else
    for f in "${files[@]}"; do
      rd_process_one "$f" || true
    done
  fi
}

# ---------------------------------------------------------------------------
# Notificación y post-acciones
# ---------------------------------------------------------------------------
rd_notify_done() {
  local msg="Creados: ${RD_OK}  |  Errores: ${RD_FAIL}  |  Omitidos: ${RD_SKIP}"
  if [ "$RD_NOTIFY" = "true" ] && command -v notify-send >/dev/null 2>&1; then
    local icon_arg=()
    [ -f "$RD_ICON" ] && icon_arg=(-i "$RD_ICON")
    notify-send "${icon_arg[@]}" "$RD_APP_NAME" "$msg" || true
  fi
}

rd_maybe_open_result() {
  local first="${RD_OUTPUTS[0]:-}"
  [ -n "$first" ] || return 0
  local dir
  dir=$(dirname "$first")

  local do_open=false
  case "$RD_OPEN_RESULT" in
    always) do_open=true ;;
    never) do_open=false ;;
    ask)
      if command -v zenity >/dev/null 2>&1; then
        rd_zenity_opts
        if zenity "${RD_ZENITY_OPTS[@]}" --question --title="$RD_APP_NAME" \
          --text="¿Abrir la carpeta del resultado?" --ok-label="Abrir" --cancel-label="No"; then
          do_open=true
        fi
      fi
      ;;
  esac

  if [ "$do_open" = true ]; then
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$dir" >/dev/null 2>&1 &
    elif command -v nautilus >/dev/null 2>&1; then
      nautilus "$dir" >/dev/null 2>&1 &
    fi
  fi
}

rd_show_summary() {
  local msg="Proceso terminado.\n\nCreados: ${RD_OK}\nErrores: ${RD_FAIL}\nOmitidos: ${RD_SKIP}"
  if [ "${#RD_ERRORS[@]}" -gt 0 ]; then
    msg+="\n\nDetalle de errores en:\n${RD_LOG_FILE}"
  fi
  if command -v zenity >/dev/null 2>&1; then
    rd_zenity_opts
    if [ "$RD_FAIL" -gt 0 ]; then
      zenity "${RD_ZENITY_OPTS[@]}" --warning --title="$RD_APP_NAME" --text="$msg" || true
    else
      zenity "${RD_ZENITY_OPTS[@]}" --info --title="$RD_APP_NAME" --text="$msg" --timeout=4 || true
    fi
  fi
  rd_notify_done
  rd_maybe_open_result
}

# Presets de ancho con nombre
rd_preset_width() {
  case "$1" in
    thumbnail|miniatura) RD_WIDTH=640 ;;
    blog) RD_WIDTH=800 ;;
    web|estandar) RD_WIDTH=1200 ;;
    retina) RD_WIDTH=1600 ;;
    fullhd|hero) RD_WIDTH=1920 ;;
    instagram) RD_WIDTH=1080; RD_CROP="1:1" ;;
    og|opengraph) RD_WIDTH=1200; RD_CROP="og" ;;
    favicon) RD_WIDTH=32; RD_CROP="1:1"; RD_FORMAT="png" ;;
    *) RD_WIDTH="$1" ;;
  esac
}

# Leer rutas desde Nautilus
rd_files_from_nautilus() {
  RD_FILES=()
  local line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    RD_FILES+=("$line")
  done <<< "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS:-}"
}
