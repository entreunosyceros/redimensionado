#!/usr/bin/env bash
# =============================================================================
# build-deb.sh — genera el paquete Debian de reDIMENSIONado (v2+)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_NAME="redimensionado"
APP_NAME="reDIMENSIONado"
ICON_NAME="redimensionado"
VERSION="2.0.0"
ARCH="all"
SRC_LOGO="${SCRIPT_DIR}/img/logo.png"
BUILD_ROOT="${SCRIPT_DIR}/build/${PKG_NAME}_${VERSION}_${ARCH}"
OUT_DIR="${SCRIPT_DIR}/dist"
DEB_FILE="${OUT_DIR}/${PKG_NAME}_${VERSION}_${ARCH}.deb"
ICON_SIZES=(16 24 32 48 64 128 256 512)
SHARE="/usr/share/${PKG_NAME}"

if [ ! -f "$SRC_LOGO" ]; then
  echo "ERROR: falta $SRC_LOGO" >&2
  exit 1
fi
if ! command -v convert >/dev/null 2>&1 && ! command -v magick >/dev/null 2>&1; then
  echo "ERROR: ImageMagick requerido para iconos." >&2
  exit 1
fi
command -v dpkg-deb >/dev/null 2>&1 || {
  echo "ERROR: dpkg-deb requerido." >&2
  exit 1
}

if command -v convert >/dev/null 2>&1; then IM=(convert); else IM=(magick); fi

echo "==> Empaquetando ${APP_NAME} ${VERSION}"
rm -rf "$BUILD_ROOT"
mkdir -p \
  "${BUILD_ROOT}/DEBIAN" \
  "${BUILD_ROOT}${SHARE}/lib" \
  "${BUILD_ROOT}${SHARE}/scripts" \
  "${BUILD_ROOT}/usr/share/nautilus-python/extensions" \
  "${BUILD_ROOT}/usr/share/applications" \
  "${BUILD_ROOT}/usr/share/pixmaps" \
  "${BUILD_ROOT}/usr/share/doc/${PKG_NAME}" \
  "${BUILD_ROOT}/etc/skel/.local/share/nautilus/scripts"

# Librería y scripts principales
install -m 644 "${SCRIPT_DIR}/lib/redimensionado-common.sh" \
  "${BUILD_ROOT}${SHARE}/lib/redimensionado-common.sh"
install -m 755 "${SCRIPT_DIR}/scripts/reDIMENSIONado" \
  "${BUILD_ROOT}${SHARE}/scripts/reDIMENSIONado"
install -m 755 "${SCRIPT_DIR}/scripts/reDIMENSIONado-preferencias" \
  "${BUILD_ROOT}${SHARE}/scripts/reDIMENSIONado-preferencias"
install -m 755 "${SCRIPT_DIR}/scripts/reDIMENSIONado-rapido.sh" \
  "${BUILD_ROOT}${SHARE}/scripts/reDIMENSIONado-rapido.sh"

# Submenú Scripts de Nautilus (carpeta completa)
cp -a "${SCRIPT_DIR}/nautilus-scripts/reDIMENSIONado" \
  "${BUILD_ROOT}${SHARE}/nautilus-scripts-reDIMENSIONado"
# skel + se enlazará en postinst a ~/.local/share/nautilus/scripts/
cp -a "${SCRIPT_DIR}/nautilus-scripts/reDIMENSIONado" \
  "${BUILD_ROOT}/etc/skel/.local/share/nautilus/scripts/reDIMENSIONado"

# Extensión Python (menú contextual nativo)
install -m 644 "${SCRIPT_DIR}/nautilus-extension/redimensionado.py" \
  "${BUILD_ROOT}/usr/share/nautilus-python/extensions/redimensionado.py"

install -m 644 "$SRC_LOGO" "${BUILD_ROOT}${SHARE}/logo.png"
install -m 644 "${SCRIPT_DIR}/config.example" "${BUILD_ROOT}${SHARE}/config.example"
install -m 644 "$SRC_LOGO" "${BUILD_ROOT}/usr/share/pixmaps/${ICON_NAME}.png"

for size in "${ICON_SIZES[@]}"; do
  dir="${BUILD_ROOT}/usr/share/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$dir"
  "${IM[@]}" "$SRC_LOGO" -resize "${size}x${size}" -background none -gravity center \
    -extent "${size}x${size}" "$dir/${ICON_NAME}.png"
done

cat > "${BUILD_ROOT}/usr/share/applications/${ICON_NAME}.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=${APP_NAME}
Comment=Redimensiona imágenes para web desde Nautilus
Exec=${SHARE}/scripts/reDIMENSIONado-preferencias
Icon=${ICON_NAME}
Categories=Graphics;Photography;RasterGraphics;
Keywords=imagen;redimensionar;resize;web;nautilus;webp;
Terminal=false
StartupNotify=true
EOF

cat > "${BUILD_ROOT}/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Depends: imagemagick, zenity, nautilus, python3-nautilus, python3-gi, libnotify-bin
Recommends: libheif1
Maintainer: ${APP_NAME} <local@localhost>
Description: ${APP_NAME} — redimensionar imágenes para web en Nautilus
 Menú contextual y Scripts de Nautilus para redimensionar, recortar,
 convertir (JPEG/PNG/WebP/AVIF) y optimizar imágenes para publicación web.
EOF

cat > "${BUILD_ROOT}/DEBIAN/postinst" <<EOF
#!/bin/sh
set -e
APP_NAME="${APP_NAME}"
SRC_MENU="${SHARE}/nautilus-scripts-reDIMENSIONado"

link_for_home() {
  home="\$1"
  [ -d "\$home" ] || return 0
  scripts="\$home/.local/share/nautilus/scripts"
  mkdir -p "\$scripts"
  # Quitar enlace/script suelto de versiones antiguas (1.x)
  rm -f "\$scripts/\$APP_NAME"
  # Submenú completo
  rm -rf "\$scripts/\$APP_NAME"
  cp -a "\$SRC_MENU" "\$scripts/\$APP_NAME"
  owner=\$(stat -c '%U:%G' "\$home" 2>/dev/null || true)
  if [ -n "\$owner" ]; then
    chown -R "\$owner" "\$scripts/\$APP_NAME" 2>/dev/null || true
    chown "\$owner" "\$home/.local" "\$home/.local/share" \\
      "\$home/.local/share/nautilus" "\$scripts" 2>/dev/null || true
  fi
}

for home in /home/* /root; do
  link_for_home "\$home"
done

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications >/dev/null 2>&1 || true
fi

echo "\$APP_NAME ${VERSION} instalado."
echo "Reinicia Nautilus: nautilus -q"
echo "Menú: clic derecho en imagen(es) → ${APP_NAME}  (o Scripts → ${APP_NAME})"
exit 0
EOF
chmod 755 "${BUILD_ROOT}/DEBIAN/postinst"

cat > "${BUILD_ROOT}/DEBIAN/postrm" <<EOF
#!/bin/sh
set -e
APP_NAME="${APP_NAME}"
if [ "\$1" = remove ] || [ "\$1" = purge ]; then
  for home in /home/* /root /etc/skel; do
    rm -rf "\$home/.local/share/nautilus/scripts/\$APP_NAME"
    rm -f "\$home/.local/share/nautilus/scripts/\$APP_NAME"
  done
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true
  fi
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications >/dev/null 2>&1 || true
  fi
fi
exit 0
EOF
chmod 755 "${BUILD_ROOT}/DEBIAN/postrm"

cat > "${BUILD_ROOT}/usr/share/doc/${PKG_NAME}/copyright" <<EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: ${APP_NAME}
Files: *
Copyright: local
License: MIT
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software to deal in the Software without restriction.
EOF

cat > "${BUILD_ROOT}/usr/share/doc/${PKG_NAME}/README.Debian" <<EOF
${APP_NAME} ${VERSION}
Ver /usr/share/doc/${PKG_NAME}/ o el README del repositorio.
EOF

find "$BUILD_ROOT" -type d -exec chmod 755 {} +
chmod 644 "${BUILD_ROOT}/DEBIAN/control"
find "${BUILD_ROOT}${SHARE}/nautilus-scripts-reDIMENSIONado" -type f -exec chmod 755 {} +
find "${BUILD_ROOT}/etc/skel/.local/share/nautilus/scripts/reDIMENSIONado" -type f -exec chmod 755 {} +
chmod 644 "${BUILD_ROOT}/usr/share/nautilus-python/extensions/redimensionado.py"
chmod 644 "${BUILD_ROOT}/usr/share/applications/${ICON_NAME}.desktop"
chmod 644 "${BUILD_ROOT}${SHARE}/logo.png"
chmod 644 "${BUILD_ROOT}${SHARE}/lib/redimensionado-common.sh"
find "${BUILD_ROOT}/usr/share/icons" -type f -name '*.png' -exec chmod 644 {} +

mkdir -p "$OUT_DIR"
rm -f "${OUT_DIR}/${PKG_NAME}_"*.deb
dpkg-deb --root-owner-group --build "$BUILD_ROOT" "$DEB_FILE"

echo
echo "Paquete: $DEB_FILE"
echo "Instalar: sudo apt install ./dist/${PKG_NAME}_${VERSION}_${ARCH}.deb"
