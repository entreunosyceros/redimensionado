#!/usr/bin/env python3
# =============================================================================
# Extensión Nautilus: menú contextual nativo «reDIMENSIONado»
# -----------------------------------------------------------------------------
# Se instala en:
#   /usr/share/nautilus-python/extensions/redimensionado.py
# Requiere: python3-nautilus, python3-gi
#
# Añade un submenú directo (sin pasar por Scripts) con presets rápidos
# e interfaz completa.
# =============================================================================

from __future__ import annotations

import os
import subprocess
from urllib.parse import unquote

from gi.repository import GObject, Nautilus

APP = "reDIMENSIONado"
BIN_GUI = "/usr/share/redimensionado/scripts/reDIMENSIONado"
BIN_QUICK = "/usr/share/redimensionado/scripts/reDIMENSIONado-rapido.sh"
BIN_PREFS = "/usr/share/redimensionado/scripts/reDIMENSIONado-preferencias"
ICON = "redimensionado"

IMAGE_EXTS = {
    ".jpg", ".jpeg", ".png", ".webp", ".gif", ".tif", ".tiff", ".bmp",
    ".heic", ".heif", ".avif", ".svg", ".svgz", ".pdf",
}


def _uri_to_path(uri: str) -> str:
    if uri.startswith("file://"):
        return unquote(uri[7:])
    return unquote(uri)


def _is_image_file(path: str) -> bool:
    _, ext = os.path.splitext(path.lower())
    return ext in IMAGE_EXTS and os.path.isfile(path)


class ReDimensionadoExtension(GObject.GObject, Nautilus.MenuProvider):
    """Proveedor del menú contextual reDIMENSIONado."""

    def _run(self, _menu, paths: list[str], mode: str) -> None:
        env = os.environ.copy()
        # Compatibilidad con scripts que leen la variable de Nautilus
        env["NAUTILUS_SCRIPT_SELECTED_FILE_PATHS"] = "\n".join(paths) + "\n"
        if mode == "gui":
            cmd = [BIN_GUI]
        elif mode == "prefs":
            cmd = [BIN_PREFS]
        else:
            cmd = [BIN_QUICK, mode]
        subprocess.Popen(cmd, env=env, start_new_session=True)

    def _item(self, name: str, label: str, tip: str, paths: list[str], mode: str):
        item = Nautilus.MenuItem(
            name=f"ReDimensionadoExtension::{name}",
            label=label,
            tip=tip,
            icon=ICON,
        )
        item.connect("activate", self._run, paths, mode)
        return item

    def _build_menu(self, paths: list[str]):
        root = Nautilus.MenuItem(
            name="ReDimensionadoExtension::Root",
            label=APP,
            tip="Redimensionar imágenes para web",
            icon=ICON,
        )
        submenu = Nautilus.Menu()
        root.set_submenu(submenu)

        entries = [
            ("gui", "Interfaz completa…", "Diálogo con todas las opciones"),
            ("640", "Miniatura 640 px", "Ancho 640 px"),
            ("800", "Blog 800 px", "Ancho 800 px"),
            ("1200", "Web 1200 px", "Ancho 1200 px"),
            ("1600", "Retina 1600 px", "Ancho 1600 px"),
            ("1920", "Full HD 1920 px", "Ancho 1920 px"),
            ("instagram", "Instagram 1080 (1:1)", "Cuadrado centrado"),
            ("og", "Open Graph 1200×630", "Imagen para redes / SEO"),
            ("favicon", "Favicon 32×32", "PNG cuadrado pequeño"),
            ("prefs", "Preferencias…", "Valores por defecto"),
        ]
        for mode, label, tip in entries:
            submenu.append_item(self._item(mode, label, tip, paths, mode))
        return root

    def get_file_items(self, *args):
        """Nautilus 4: get_file_items(files) o (window, files)."""
        files = args[-1]
        paths = []
        for f in files:
            try:
                uri = f.get_uri()
            except Exception:
                continue
            path = _uri_to_path(uri)
            if _is_image_file(path):
                paths.append(path)
        if not paths:
            return []
        return [self._build_menu(paths)]

    # Algunas versiones también consultan el fondo; no mostramos menú ahí.
    def get_background_items(self, *args):
        return []
