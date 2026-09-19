# reDIMENSIONado

<p align="center">
<img width="1182" height="855" alt="logo" src="https://github.com/user-attachments/assets/5edcda50-a3ad-49e7-b619-f3b826610505" />
</p>

**reDIMENSIONado** redimensiona, recorta y convierte imágenes para publicar en web, desde el menú contextual de **Nautilus** (Archivos) en Ubuntu / GNOME.

Versión del paquete: **2.0.0**

## Qué puede hacer

| Función | Detalle |
|---------|---------|
| Redimensionar | Anchos 640–1920 o personalizado; ampliar o solo reducir |
| Formatos de salida | Mantener original, JPEG, PNG, WebP, AVIF |
| Calidad | 60 / 75 / 85 / 95 |
| Recorte | 1:1, 16:9, 4:3, Open Graph 1200×630 |
| Presets | Blog, web, Instagram, favicon, OG, etc. |
| Salida | Copia o sobrescribir; sufijo y carpeta configurables |
| Peso máximo | Límite en KB (ajusta calidad) |
| Privacidad | Opción de quitar EXIF (`-strip`) |
| Lotes | Barra de progreso, notificación y abrir carpeta |
| Entrada | JPG, PNG, WebP, GIF, TIFF, BMP, HEIC, SVG, PDF (1ª página) |
| Preferencias | `~/.config/redimensionado/config` |
| Menú | Extensión Nautilus nativa + submenú Scripts |

Los originales no se modifican salvo que elijas **replace** (con confirmación).

## Requisitos

- Ubuntu / GNOME con Nautilus
- Al instalar el `.deb`, `apt` resuelve: `imagemagick`, `zenity`, `nautilus`, `python3-nautilus`, `python3-gi`, `libnotify-bin`

## Instalación

```bash
./build-deb.sh
sudo apt install ./dist/redimensionado_2.0.0_all.deb
nautilus -q
```

Desinstalación:

```bash
sudo apt remove redimensionado
```

## Uso

> Selecciona **una o más imágenes** (el menú no aparece en el fondo vacío).

### Menú contextual nativo

Clic derecho → **reDIMENSIONado** →

- Interfaz completa…
- Miniatura / Blog / Web / Retina / Full HD
- Instagram, Open Graph, Favicon
- Preferencias…

### Scripts de Nautilus

Clic derecho → **Scripts** → **reDIMENSIONado** → (mismas entradas)

### Interfaz completa

1. Elige preset o ancho personalizado  
2. Ajusta formato, calidad, modo (exact / solo reducir), recorte, copia o reemplazo, sufijo, carpeta y máx. KB  
3. Al terminar: resumen, notificación y opción de abrir la carpeta  

### Preferencias

Valores por defecto en:

```text
~/.config/redimensionado/config
```

Errores detallados en:

```text
~/.local/state/redimensionado/errores.log
```

## Desarrollo

```bash
# Pruebas automáticas
./tests/test_redimensionado.sh

# Empaquetar
./build-deb.sh
```

CI (GitHub Actions): al publicar un tag `v*` construye el `.deb`, sube el artefacto y lo adjunta al release.

## Estructura

| Ruta | Descripción |
|------|-------------|
| `lib/redimensionado-common.sh` | Lógica compartida |
| `scripts/reDIMENSIONado` | Interfaz completa (Zenity) |
| `scripts/reDIMENSIONado-preferencias` | Editor de preferencias |
| `scripts/reDIMENSIONado-rapido.sh` | Acciones rápidas / presets |
| `nautilus-scripts/reDIMENSIONado/` | Entradas del menú Scripts |
| `nautilus-extension/redimensionado.py` | Extensión Python del menú contextual |
| `tests/` | Pruebas |
| `.github/workflows/` | CI / release `.deb` |
| `img/logo.png` | Icono |
| `build-deb.sh` | Generador del paquete |

## Nombres

| Contexto | Nombre |
|----------|--------|
| Visible | **reDIMENSIONado** |
| Paquete apt | `redimensionado` |
| Icono | `redimensionado` |
