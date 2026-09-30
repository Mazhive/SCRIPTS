"""
ColorStack — 3D Print Color Layer Splitter — V1.0.8
---------------------------------------------------
ColorStack: 3D Print Color Layer Splitter

Splitst een afbeelding in kleurlagen (KMeans + LAB), exporteert die lagen
als SVG (1 gecombineerd bestand of losse bestanden) en kan diezelfde lagen
ook direct als geëxtrudeerde 3D OBJ meshes wegschrijven.

Talen: English (standaard), Nederlands, Español

Gebruik als GUI:
    python ColorStack.py

Gebruik als CLI (SVG -> OBJ):
    python ColorStack.py input.svg output.obj --height 0.2
"""

import argparse
import sys
import gc
import json
import os
import cv2
import numpy as np
from pathlib import Path
from sklearn.cluster import KMeans
import svgwrite
import trimesh
from shapely.geometry import Polygon, MultiPolygon
from shapely.ops import unary_union
from shapely import affinity
from svgpathtools import svg2paths2, parse_path

from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QPushButton, QVBoxLayout,
    QHBoxLayout, QWidget, QFileDialog, QLabel,
    QTextEdit, QSlider, QScrollArea, QSplitter, QFrame,
    QProgressBar, QMenuBar, QMenu, QCheckBox, QDoubleSpinBox,
    QGroupBox, QMessageBox
)
from PyQt6.QtCore import Qt, QThread, pyqtSignal
from PyQt6.QtGui import QImage, QPixmap, QAction


APP_NAME = "ColorStack"
APP_VERSION = "V1.0.8"

# Taal waarin de app opstart
DEFAULT_LANG = "en"

# Namespace voor Inkscape-laagattributen (moet gedeclareerd zijn anders is de SVG ongeldig)
INKSCAPE_NSMAP = {'inkscape': 'http://www.inkscape.org/namespaces/inkscape'}

# Achtervoegsel in de id van L-hoekmarkers, zodat svg_to_obj ze kan overslaan
MARKER_SUFFIX = "_markers"


TRANSLATIONS = {
    "nl": {
        "title": "ColorStack — 3D Print Kleurlagen Splitser",
        "menu_file": "Bestand",
        "menu_save_preset": "Preset Opslaan...",
        "menu_load_preset": "Preset Laden...",
        "menu_lang": "Taal",
        "lang_nl": "Nederlands",
        "lang_en": "English",
        "lang_es": "Español",
        "left_header": "<b>Gekleurde Lagen Overzicht</b>",
        "center_header": "<b>Origineel vs. Gescheiden Lagen Preview</b>",
        "orig_title": "Geïmporteerde Afbeelding:",
        "no_image": "Geen afbeelding ingeladen",
        "layer_title_default": "Geselecteerde Laag / Totaalbeeld:",
        "no_processing": "Geen verwerking uitgevoerd",
        "btn_select": "Selecteer Afbeelding",
        "no_file": "Geen bestand gekozen",
        "slider_colors": "Aantal Kleuren (2-32):",
        "slider_sat": "Kleurversterking (Sat. Boost):",
        "slider_luma": "Helderheid Gewicht (Luma):",
        "slider_blur": "Nuance Filter (Vervaging):",
        "slider_area": "Detaillering (Min. Vlekgrootte):",
        "btn_apply": "🔄 Herberekenen / Toepassen",
        "chk_single_file": "Exporteer alle lagen in 1 bestand (behoudt positie)",
        "btn_export": "⬇ Exporteer Lagen als SVG",
        "obj_group": "OBJ 3D-opties (SVG ➜ 3D)",
        "slider_obj_height": "Laagdikte (mm):",
        "slider_obj_samples": "Pad-resolutie (samples):",
        "lbl_obj_scale": "Schaal (mm per pixel):",
        "chk_obj_flip_y": "Y-as omkeren (SVG heeft Y naar beneden)",
        "chk_obj_colors": "3D-kleuren meeschrijven (vertex colors)",
        "btn_export_obj": "⬆ Exporteer Lagen als OBJ (3D)",
        "right_header": "<b>Logbestand & Status</b>",
        "total_overview": "Totaaloverzicht van alle lagen:",
        "preview_layer": "Preview Laag",
        "layer": "Laag",
        "processing": "\nBezig met verwerken...",
        "waiting": "Wachten op vorige berekening...",
        "loaded": "Ingeladen",
        "preset_saved": "Preset succesvol opgeslagen:",
        "preset_loaded": "Preset geladen:",
        "err_save_preset": "<b>FOUT bij opslaan preset:</b>",
        "err_load_preset": "<b>FOUT bij laden preset:</b>",
        "err_processing": "<b>FOUT:</b>",
        "success_processed": "Succesvol verwerkt: {count} lagen gegenereerd.",
        "selected": "Geselecteerd:",
        "export_dialog": "Selecteer Map / Bestand voor SVG Export",
        "saved_file": "Opgeslagen:",
        "export_done": "\n✅ Alle SVG lagen zijn succesvol geëxporteerd met L-hoekmarkers!",
        "obj_exporting": "\nBezig met 3D (OBJ) export...",
        "obj_export_dialog": "Selecteer Map / Bestand voor OBJ Export",
        "obj_progress": "3D: laag {cur}/{tot} — {name}",
        "obj_done_single": "\n✅ OBJ opgeslagen: {name} ({meshes} meshes, {layers} lagen gestapeld)",
        "obj_done_multi": "\n✅ {count} OBJ-bestanden opgeslagen ({meshes} meshes totaal)",
        "obj_empty": "  (laag overgeslagen: geen bruikbare vlakken)",
        "obj_err": "<b>FOUT bij OBJ-export:</b>",
        "obj_no_meshes": "Geen bruikbare geometrie gevonden (verhoog de resolutie of verlaag de vlekgrootte).",
        "exclude_layer": "Uitsluiten van export",
        "volume_warning": "Volume {vol:.1f}mm³ < 9mm³ — PrusaSlicer kan 'inches' waarschuwing geven",
        "about_description": (
            "ColorStack splitst een afbeelding in kleurlagen met KMeans-clustering in LAB-kleurruimte. "
            "Elke laag wordt geëxporteerd als:<br><br>"
            "• SVG — met mm-afmetingen, viewBox en een 0,3 mm omlijstend kader voor uitlijning in slicers<br>"
            "• OBJ — geëxtrudeerde 3D-lagen (standaard 0,2 mm hoogte), gestapeld op Z of apart voor multi-color print<br><br>"
            "Belangrijkste functies:<br>"
            "- Interactieve sliders voor aantal kleuren, saturatie, luminance-gewicht, vervaging en detaildrempel<br>"
            "- Live preview van geselecteerde laag of totaalbeeld<br>"
            "- Per-laag uitsluiten via vinkje (handig voor te kleine lagen)<br>"
            "- Automatische volume-check: waarschuwing als laag < 9 mm³ (PrusaSlicer 'inches' limiet)<br>"
            "- CLI-ondersteuning: <code>python ColorStack.py input.svg output.obj --height 0.2</code><br><br>"
            "Doel: Snelle, correct geschaalde multi-kleur 3D-printbestanden zonder handmatige schaalcorrecties in de slicer."
        ),
        "menu_help": "Help",
        "menu_about": "Over...",
        "about_title": "Over",
        "about_version": "Versie:",
        "about_ok": "OK",
    },
    "en": {
        "title": "ColorStack — 3D Print Color Layer Splitter",
        "menu_file": "File",
        "menu_save_preset": "Save Preset...",
        "menu_load_preset": "Load Preset...",
        "menu_lang": "Language",
        "lang_nl": "Nederlands",
        "lang_en": "English",
        "lang_es": "Español",
        "left_header": "<b>Colored Layers Overview</b>",
        "center_header": "<b>Original vs. Separated Layers Preview</b>",
        "orig_title": "Imported Image:",
        "no_image": "No image loaded",
        "layer_title_default": "Selected Layer / Combined View:",
        "no_processing": "No processing executed",
        "btn_select": "Select Image",
        "no_file": "No file selected",
        "slider_colors": "Number of Colors (2-32):",
        "slider_sat": "Color Boost (Sat. Boost):",
        "slider_luma": "Luminance Weight (Luma):",
        "slider_blur": "Nuance Filter (Blur):",
        "slider_area": "Detailing (Min. Spot Size):",
        "btn_apply": "🔄 Recalculate / Apply",
        "chk_single_file": "Export all layers in 1 file (preserves alignment)",
        "btn_export": "⬇ Export Layers as SVG",
        "obj_group": "OBJ 3D options (SVG ➜ 3D)",
        "slider_obj_height": "Layer Height (mm):",
        "slider_obj_samples": "Path Resolution (samples):",
        "lbl_obj_scale": "Scale (mm per pixel):",
        "chk_obj_flip_y": "Flip Y axis (SVG Y points down)",
        "chk_obj_colors": "Write 3D colors (vertex colors)",
        "btn_export_obj": "⬆ Export Layers as OBJ (3D)",
        "right_header": "<b>Log File & Status</b>",
        "total_overview": "Combined overview of all layers:",
        "preview_layer": "Preview Layer",
        "layer": "Layer",
        "processing": "\nProcessing...",
        "waiting": "Waiting for previous task...",
        "loaded": "Loaded",
        "preset_saved": "Preset successfully saved:",
        "preset_loaded": "Preset loaded:",
        "err_save_preset": "<b>ERROR saving preset:</b>",
        "err_load_preset": "<b>ERROR loading preset:</b>",
        "err_processing": "<b>ERROR:</b>",
        "success_processed": "Successfully processed: {count} layers generated.",
        "selected": "Selected:",
        "export_dialog": "Select Directory / File for SVG Export",
        "saved_file": "Saved:",
        "export_done": "\n✅ All SVG layers were successfully exported with L corner markers!",
        "obj_exporting": "\nExporting 3D (OBJ)...",
        "obj_export_dialog": "Select Directory / File for OBJ Export",
        "obj_progress": "3D: layer {cur}/{tot} — {name}",
        "obj_done_single": "\n✅ OBJ saved: {name} ({meshes} meshes, {layers} layers stacked)",
        "obj_done_multi": "\n✅ {count} OBJ files saved ({meshes} meshes in total)",
        "obj_empty": "  (layer skipped: no usable polygons)",
        "obj_err": "<b>ERROR during OBJ export:</b>",
        "obj_no_meshes": "No usable geometry found (raise resolution or lower the minimum spot size).",
        "exclude_layer": "Exclude from export",
        "volume_warning": "Volume {vol:.1f}mm³ < 9mm³ — PrusaSlicer may show 'inches' warning",
        "about_description": (
            "ColorStack splits an image into color layers using KMeans clustering in LAB color space. "
            "Each layer is exported as:<br><br>"
            "• SVG — with mm dimensions, viewBox, and a 0.3 mm perimeter frame for slicer alignment<br>"
            "• OBJ — extruded 3D layers (default 0.2 mm height), stacked on Z or separate for multi-color print<br><br>"
            "Key features:<br>"
            "- Interactive sliders for color count, saturation, luminance weight, blur, and detail threshold<br>"
            "- Live preview of selected layer or combined view<br>"
            "- Per-layer exclusion via checkbox (useful for too-small layers)<br>"
            "- Automatic volume check: warning if layer < 9 mm³ (PrusaSlicer 'inches' limit)<br>"
            "- CLI support: <code>python ColorStack.py input.svg output.obj --height 0.2</code><br><br>"
            "Goal: Fast, correctly scaled multi-color 3D print files without manual scale fixes in the slicer."
        ),
        "menu_help": "Help",
        "menu_about": "About...",
        "about_title": "About",
        "about_version": "Version:",
        "about_ok": "OK",
    },
    "es": {
        "title": "ColorStack — Separador de Capas SVG/OBJ para Impresión 3D",
        "menu_file": "Archivo",
        "menu_save_preset": "Guardar preajuste...",
        "menu_load_preset": "Cargar preajuste...",
        "menu_lang": "Idioma",
        "lang_nl": "Nederlands",
        "lang_en": "English",
        "lang_es": "Español",
        "left_header": "<b>Resumen de capas de color</b>",
        "center_header": "<b>Original vs. vista previa de capas separadas</b>",
        "orig_title": "Imagen importada:",
        "no_image": "No hay imagen cargada",
        "layer_title_default": "Capa seleccionada / vista total:",
        "no_processing": "No se ha realizado ningún procesado",
        "btn_select": "Seleccionar imagen",
        "no_file": "No se ha elegido ningún archivo",
        "slider_colors": "Número de colores (2-32):",
        "slider_sat": "Realce de color (Sat. Boost):",
        "slider_luma": "Peso de luminosidad (Luma):",
        "slider_blur": "Filtro de matices (desenfoque):",
        "slider_area": "Detalle (tamaño mín. de mancha):",
        "btn_apply": "🔄 Recalcular / Aplicar",
        "chk_single_file": "Exportar todas las capas en 1 archivo (conserva la posición)",
        "btn_export": "⬇ Exportar capas como SVG",
        "obj_group": "Opciones 3D OBJ (SVG ➜ 3D)",
        "slider_obj_height": "Altura de capa (mm):",
        "slider_obj_samples": "Resolución de trazo (muestras):",
        "lbl_obj_scale": "Escala (mm por píxel):",
        "chk_obj_flip_y": "Invertir eje Y (en SVG la Y apunta hacia abajo)",
        "chk_obj_colors": "Escribir colores 3D (colores de vértice)",
        "btn_export_obj": "⬆ Exportar capas como OBJ (3D)",
        "right_header": "<b>Registro y estado</b>",
        "total_overview": "Vista general combinada de todas las capas:",
        "preview_layer": "Vista previa de la capa",
        "layer": "Capa",
        "processing": "\nProcesando...",
        "waiting": "Esperando la tarea anterior...",
        "loaded": "Cargado",
        "preset_saved": "Preajuste guardado correctamente:",
        "preset_loaded": "Preajuste cargado:",
        "err_save_preset": "<b>ERROR al guardar el preajuste:</b>",
        "err_load_preset": "<b>ERROR al cargar el preajuste:</b>",
        "err_processing": "<b>ERROR:</b>",
        "success_processed": "Procesado correcto: {count} capas generadas.",
        "selected": "Seleccionada:",
        "export_dialog": "Selecciona carpeta / archivo para la exportación SVG",
        "saved_file": "Guardado:",
        "export_done": "\n✅ ¡Todas las capas SVG se han exportado correctamente con marcas de esquina en L!",
        "obj_exporting": "\nExportando 3D (OBJ)...",
        "obj_export_dialog": "Selecciona carpeta / archivo para la exportación OBJ",
        "obj_progress": "3D: capa {cur}/{tot} — {name}",
        "obj_done_single": "\n✅ OBJ guardado: {name} ({meshes} mallas, {layers} capas apiladas)",
        "obj_done_multi": "\n✅ {count} archivos OBJ guardados ({meshes} mallas en total)",
        "obj_empty": "  (capa omitida: no hay polígonos utilizables)",
        "obj_err": "<b>ERROR durante la exportación OBJ:</b>",
        "obj_no_meshes": "No se encontró geometría utilizable (aumenta la resolución o reduce el tamaño mínimo de mancha).",
        "exclude_layer": "Excluir de exportación",
        "volume_warning": "Volumen {vol:.1f}mm³ < 9mm³ — PrusaSlicer puede avisar de 'pulgadas'",
        "about_description": (
            "ColorStack separa una imagen en capas de color usando clustering KMeans en espacio de color LAB. "
            "Cada capa se exporta como:<br><br>"
            "• SVG — con dimensiones en mm, viewBox y un marco perimetral de 0,3 mm para alineación en slicers<br>"
            "• OBJ — capas 3D extruidas (altura por defecto 0,2 mm), apiladas en Z o separadas para multi-color<br><br>"
            "Funciones principales:<br>"
            "- Deslizadores interactivos para número de colores, saturación, peso de luminancia, desenfoque y umbral de detalle<br>"
            "- Vista previa en vivo de la capa seleccionada o vista combinada<br>"
            "- Exclusión por capa mediante casilla — útil para capas demasiado pequeñas<br>"
            "- Comprobación automática de volumen: aviso si capa < 9 mm³ (límite de 'pulgadas' en PrusaSlicer)<br>"
            "- Soporte CLI: <code>python ColorStack.py input.svg output.obj --height 0.2</code><br><br>"
            "Objetivo: Archivos de impresión 3D multi-color rápidos y correctamente escalados sin correcciones manuales en el slicer."
        ),
        "menu_help": "Ayuda",
        "menu_about": "Acerca de...",
        "about_title": "Acerca de",
        "about_version": "Versión:",
        "about_ok": "Aceptar",
    }
}


# ----------------------------------------------------------------------------
# Afbeelding -> lagen
# ----------------------------------------------------------------------------

def _rasterize_svg(svg_bytes):
    """Rasteriseert SVG-bytes naar een numpy BGR-array op viewBox-resolutie."""
    try:
        from PyQt6.QtSvg import QSvgRenderer
        from PyQt6.QtGui import QImage, QPainter
        from PyQt6.QtCore import Qt, QBuffer, QByteArray, QIODevice
    except ImportError:
        return None

    renderer = QSvgRenderer(svg_bytes)
    if not renderer.isValid():
        return None

    vb = renderer.viewBoxF()
    if vb.width() <= 0 or vb.height() <= 0:
        size = renderer.defaultSize()
        w, h = max(1, size.width()), max(1, size.height())
    else:
        w, h = max(1, int(vb.width())), max(1, int(vb.height()))

    img = QImage(w, h, QImage.Format.Format_RGB888)
    img.fill(Qt.GlobalColor.white)
    painter = QPainter(img)
    renderer.render(painter)
    painter.end()

    ba = QByteArray()
    buf = QBuffer(ba)
    buf.open(QIODevice.OpenModeFlag.WriteOnly)
    img.save(buf, "PNG")
    buf.close()
    png = np.frombuffer(ba.data(), dtype=np.uint8)
    return cv2.imdecode(png, cv2.IMREAD_COLOR)


def read_image_utf8(image_path):
    try:
        with open(image_path, "rb") as f:
            chunk = f.read()
        if Path(image_path).suffix.lower() in (".svg", ".svgz"):
            return _rasterize_svg(chunk)
        chunk_arr = np.frombuffer(chunk, dtype=np.uint8)
        img = cv2.imdecode(chunk_arr, cv2.IMREAD_COLOR)
        return img
    except Exception:
        return None


def generate_frame_path(w, h, frame_width=10):
    """Genereert een SVG pad voor een kader om de volledige canvas.
    
    frame_width: breedte van het kader in user units (px).
    Retourneert een pad-string met een buitenkader en een inwendig kader
    (fill-rule="evenodd" maakt het een hol kader).
    """
    fw = frame_width
    # Buitenkader (clockwise) + inwendig kader (counter-clockwise) = hol kader via evenodd
    return (f"M 0,0 L {w},0 L {w},{h} L 0,{h} Z "
            f"M {fw},{fw} L {w-fw},{fw} L {w-fw},{h-fw} L {fw},{h-fw} Z")


def contour_to_path_data(cnt):
    """Zet een OpenCV-contour om naar een SVG pad-string."""
    if len(cnt) < 3:
        return ""
    p_str = f"M {cnt[0][0][0]},{cnt[0][0][1]} "
    for pt in cnt[1:]:
        p_str += f"L {pt[0][0]},{pt[0][1]} "
    return p_str + "Z "


def collect_contour_shapes(contours, hierarchy, min_area=0.0):
    """
    Groepeer contouren in vormen: buitencontour plus de bijbehorende gaten.
    OpenCV RETR_CCOMP geeft per index een quadruple
    [next, previous, first_child, parent]; parent == -1 betekent buitencontour.
    """
    if contours is None or len(contours) == 0:
        return []

    # OpenCV 4 geeft hierarchy als numpy-array van shape (N, 4); normaliseren naar lijsten
    if hierarchy is None or len(hierarchy) == 0:
        hierarchy = [[-1, -1, -1, -1] for _ in contours]
    elif isinstance(hierarchy, np.ndarray):
        hierarchy = [[int(v) for v in row] for row in hierarchy.reshape(-1, 4)]
    else:
        hierarchy = [[int(v) for v in row] for row in hierarchy]

    # kinderen per index
    children = {i: [] for i in range(len(contours))}
    outers = []
    for idx, hier in enumerate(hierarchy):
        parent = hier[3]
        if parent == -1:
            outers.append(idx)
        else:
            children.setdefault(parent, []).append(idx)

    shapes = []
    for idx in outers:
        outer = contours[idx]
        if cv2.contourArea(outer) < min_area:
            continue
        shape_contours = [outer]
        for child in children.get(idx, []):
            if cv2.contourArea(contours[child]) >= min_area and len(contours[child]) >= 3:
                shape_contours.append(contours[child])
        shapes.append({'contours': shape_contours})

    return shapes


def process_image_layers(image_path, num_colors, blur_radius, min_area, sat_boost=1.5, luma_weight=0.3):
    img = read_image_utf8(image_path)
    if img is None:
        raise ValueError("Kan het bestand niet openen. Controleer of het pad of het bestand geldig is.")

    max_dim = 1200
    h, w = img.shape[:2]
    if max(h, w) > max_dim:
        scale = max_dim / float(max(h, w))
        img = cv2.resize(img, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)

    if blur_radius > 0:
        ksize = blur_radius if blur_radius % 2 == 1 else blur_radius + 1
        img = cv2.GaussianBlur(img, (ksize, ksize), 0)

    if sat_boost != 1.0:
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV).astype(np.float32)
        hsv[:, :, 1] = np.clip(hsv[:, :, 1] * sat_boost, 0, 255)
        img = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2BGR)

    lab_img = cv2.cvtColor(img, cv2.COLOR_BGR2LAB).astype(np.float32)
    lab_img[:, :, 0] = lab_img[:, :, 0] * luma_weight

    height, width, _ = lab_img.shape
    pixels = lab_img.reshape((-1, 3))

    kmeans = KMeans(n_clusters=num_colors, random_state=42, n_init=5)
    labels = kmeans.fit_predict(pixels)

    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    rgb_pixels = img_rgb.reshape((-1, 3))

    centers_rgb = np.zeros((num_colors, 3), dtype=np.uint8)
    for i in range(num_colors):
        mask_cluster = (labels == i)
        if np.any(mask_cluster):
            centers_rgb[i] = np.mean(rgb_pixels[mask_cluster], axis=0).astype(np.uint8)

    segmented_labels = labels.reshape((height, width))
    combined_preview = np.ones((height, width, 3), dtype=np.uint8) * 255
    layer_results = []

    for i in range(num_colors):
        color_rgb = centers_rgb[i]
        hex_color = f"#{color_rgb[0]:02x}{color_rgb[1]:02x}{color_rgb[2]:02x}"

        mask = np.uint8(segmented_labels == i) * 255

        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)

        contours, hierarchy = cv2.findContours(mask, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)

        # Gaten (kinderen in de hierarchy) horen bij hun buitencontour, anders worden
        # ze los geëxporteerd en als gevuld vlak geëxtrudeerd.
        shapes = collect_contour_shapes(contours, hierarchy, min_area)

        layer_img = np.ones((height, width, 3), dtype=np.uint8) * 255
        path_data_list = []

        if shapes:
            draw_contours = [c for shape in shapes for c in shape['contours']]
            cv2.drawContours(layer_img, draw_contours, -1, color_rgb.tolist(), -1)
            cv2.drawContours(combined_preview, draw_contours, -1, color_rgb.tolist(), -1)

            # Alle contouren van een laag in één pad: buitencontour gevolgd door zijn
            # gaten. Met fill-rule="evenodd" blijft de het gebied dan leeg.
            p_str = "".join(contour_to_path_data(c) for c in draw_contours)
            path_data_list.append(p_str)

        layer_results.append({
            'index': i + 1,
            'hex': hex_color,
            'rgb': color_rgb,
            'layer_img': layer_img,
            'paths': path_data_list,
            'width': width,
            'height': height,
            'excluded': False
        })

    return img_rgb, combined_preview, layer_results


# ----------------------------------------------------------------------------
# SVG / pad -> 3D OBJ  (basis: svg_to_obj script)
# ----------------------------------------------------------------------------

def split_path_subpaths(path):
    """Splitst een svgpathtools-pad in losse gesloten subpaden (M...Z per stuk)."""
    chains = []
    current = []
    prev_end = None

    for seg in path:
        if prev_end is None or seg.start != prev_end:
            if current:
                chains.append(current)
            current = [seg]
        else:
            current.append(seg)
        prev_end = seg.end
    if current:
        chains.append(current)

    subpaths = []
    for chain in chains:
        pts = [chain[0].start] + [s.end for s in chain]
        if len(pts) < 3:
            continue
        pts = [(p.real, p.imag) for p in pts]
        if pts[0] != pts[-1]:
            pts.append(pts[0])
        subpaths.append(pts)
    return subpaths


def _simple_polygons(points):
    """Maakt geldige, eenvoudige Polygon(s) van een puntenlijst."""
    poly = Polygon(points)
    if not poly.is_valid:
        poly = poly.buffer(0)
    if poly.is_empty:
        return []
    if isinstance(poly, Polygon):
        return [poly]
    if isinstance(poly, MultiPolygon):
        return [g for g in poly.geoms if not g.is_empty]
    return []


def polygons_with_holes(simple_polys):
    """
    Zet een lijst overlappende/nested simple polygons om naar buitencontour + gaten.
    Even diepte = buitenkant, oneven diepte = gat (zelfde regel als fill-rule="evenodd").
    """
    if not simple_polys:
        return []

    parent = [-1] * len(simple_polys)
    for i, p in enumerate(simple_polys):
        if p.is_empty:
            continue
        pminx, pminy, pmaxx, pmaxy = p.bounds
        candidates = []
        for j, q in enumerate(simple_polys):
            if j == i or q.is_empty:
                continue
            # Een gat is altijd kleiner dan wat het omhult; anders zouden twee
            # concentrische vlakken elkaar als ouder aanwijzen.
            if q.area <= p.area:
                continue
            qminx, qminy, qmaxx, qmaxy = q.bounds
            if qminx > pminx or qminy > pminy or qmaxx < pmaxx or qmaxy < pmaxy:
                continue
            if q.contains(p):
                candidates.append(j)
        if candidates:
            parent[i] = min(candidates, key=lambda j: simple_polys[j].area)

    depth = [0] * len(simple_polys)
    for i in range(len(simple_polys)):
        d, k = 0, parent[i]
        seen = set()
        while k != -1 and k not in seen:
            seen.add(k)
            d += 1
            k = parent[k]
        depth[i] = d

    result = []
    for i, p in enumerate(simple_polys):
        if depth[i] % 2 != 0 or p.is_empty:
            continue  # even diepte is een gat: wordt aan zijn ouder gehangen
        holes = []
        for j in range(len(simple_polys)):
            if parent[j] == i and depth[j] == depth[i] + 1:
                holes.append(simple_polys[j].exterior.coords)
        try:
            with_holes = Polygon(p.exterior.coords, holes)
            if not with_holes.is_valid:
                with_holes = with_holes.buffer(0)
            result.append(with_holes)
        except Exception:
            result.append(p)
    return result


def path_to_polygons(path, num_samples=100):
    """
    Converteert een SVG-pad (met eventueel meerdere subpads) naar een lijst Polygonen,
    waarbij geneste subpads als gaten in het buitenvlak terechtkomen.
    """
    simple = []
    for pts in split_path_subpaths(path):
        simple.extend(_simple_polygons(pts))

    if not simple:
        return []

    # Eerst per subpad fixen, daarna pas de gaten toewijzen
    flat = []
    for poly in simple:
        flat.extend(_simple_polygons(list(poly.exterior.coords)))
    return polygons_with_holes(flat)


def _path_to_points(path, num_samples=100):
    """Haalt punten uit een svgpathtools-pad (exact bij rechte lijnen, sampling bij curves)."""
    segments = list(path)
    if not segments:
        return []

    # Rechte lijn-segmenten: alle hoekpunten gebruiken (scherper en veel sneller)
    if all(type(seg).__name__ == "Line" for seg in segments):
        pts = [segments[0].start] + [seg.end for seg in segments]
        return [(p.real, p.imag) for p in pts]

    # Curven: evenredig samplen langs de booglengte
    points = []
    for i in range(num_samples):
        t = i / float(num_samples)
        point = path.point(t)
        points.append((point.real, point.imag))
    return points


def path_data_to_polygons(path_data, num_samples=100):
    """Zet een SVG pad-string (zoals uit de export) om naar Polygonen met gaten."""
    try:
        path = parse_path(path_data)
    except Exception:
        return []
    return path_to_polygons(path, num_samples=num_samples)


def hex_to_rgba(hex_color, alpha=255):
    h = hex_color.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    try:
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    except ValueError:
        r = g = b = 255
    return np.array([r, g, b, alpha], dtype=np.uint8)


def _layer_polygons(layer, num_samples=100):
    """Verzamelt alle bruikbare polygonen van één laag, inclusief gaten."""
    polygons = []
    for path_data in layer.get('paths', []):
        polygons.extend(path_data_to_polygons(path_data, num_samples=num_samples))
    return [p for p in polygons if p is not None and not p.is_empty]


def transform_polygon(p, scale=1.0, flip_y=True, ref_y=None):
    """
    Schaal en spiegel een polygoon.
    flip_y spiegelt om de horizontale middellijn van de hele afbeelding (ref_y),
    dus alle vlakken blijven onderling op dezelfde plek staan.
    """
    if flip_y:
        origin_y = (ref_y / 2.0) if ref_y else 0.0
        p = affinity.scale(p, xfact=1.0, yfact=-1.0, origin=(0.0, origin_y))
    if scale != 1.0:
        p = affinity.scale(p, xfact=scale, yfact=scale, origin=(0.0, 0.0))
    return p


def reference_height(layers, polygons_by_layer=None):
    """Hoogte (px) waartegen gespiegeld wordt: afbeeldingshoogte indien bekend."""
    heights = [l.get('height') for l in layers if l.get('height')]
    if heights:
        return float(max(heights))
    if polygons_by_layer:
        maxy = 0.0
        for polys in polygons_by_layer:
            for p in polys:
                if not p.is_empty:
                    maxy = max(maxy, float(p.bounds[3]))
        return maxy
    return None


def _polygons_to_meshes(poly_list, layer_height, scale=1.0, flip_y=True, ref_y=None,
                        hex_color=None, vertex_colors=False, layer_id=""):
    """Extruud een lijst Shapely-polygonen naar trimesh-volumes."""
    meshes = []
    for p in poly_list:
        if p.is_empty or len(p.exterior.coords) < 3:
            continue
        try:
            p = transform_polygon(p, scale=scale, flip_y=flip_y, ref_y=ref_y)
            mesh = trimesh.creation.extrude_polygon(p, height=layer_height)
            if vertex_colors and hex_color:
                mesh.visual = trimesh.visual.ColorVisuals(
                    mesh=mesh, vertex_colors=hex_to_rgba(hex_color))
            meshes.append(mesh)
        except Exception as e:
            print(f"Waarschuwing: Kon polygoon in laag '{layer_id}' niet extruderen: {e}")
    return meshes


# PrusaSlicer volume threshold (from PrusaSlicer source: volume_threshold_inches = 9.0)
PRUSA_VOLUME_THRESHOLD_MM3 = 9.0


def _estimate_layer_volume(layer, img_w, img_h, scale, layer_height, frame_width=0.3):
    """Schatting van totale volume (kader + content) voor één laag in mm³."""
    W, H = img_w * scale, img_h * scale
    frame_vol = 2 * frame_width * layer_height * (W + H)
    
    polys = _layer_polygons(layer, num_samples=200)
    content_vol = 0.0
    for p in polys:
        if not p.is_empty:
            x0, y0, x1, y1 = p.bounds
            content_vol += (x1 - x0) * (y1 - y0) * scale * scale * layer_height
    
    return frame_vol + content_vol


def _frame_mesh(img_w, img_h, scale, layer_height, frame_width=1.0,
                hex_color=None, vertex_colors=False):
    """Maakt een rechthoekig kader om de volledige voetafdruk (na transform).
    
    frame_width: breedte van het kader in mm.
    Zorgt voor voldoende volume (>9 mm³) om PrusaSlicer's 'inches' waarschuwing te voorkomen.
    """
    W, H = img_w * scale, img_h * scale
    fw = frame_width  # frame_width is al in mm
    if fw <= 0:
        return []
    
    # Vier rechthoeken: boven, onder, links, rechts
    rects = [
        Polygon([(0, 0), (W, 0), (W, fw), (0, fw)]),           # onder
        Polygon([(0, H-fw), (W, H-fw), (W, H), (0, H)]),       # boven
        Polygon([(0, 0), (fw, 0), (fw, H), (0, H)]),           # links
        Polygon([(W-fw, 0), (W, 0), (W, H), (W-fw, H)]),       # rechts
    ]
    meshes = []
    for rect in rects:
        try:
            mesh = trimesh.creation.extrude_polygon(rect, height=layer_height)
            if vertex_colors and hex_color:
                mesh.visual = trimesh.visual.ColorVisuals(
                    mesh=mesh, vertex_colors=hex_to_rgba(hex_color))
            meshes.append(mesh)
        except Exception:
            pass
    return meshes


def layers_to_mesh(layers, layer_height=0.2, num_samples=200, scale=1.0, flip_y=True,
                   vertex_colors=False, stack=True, progress_cb=None):
    """
    Bouwt één trimesh uit één of meerdere lagen.
    stack=True : elke laag komt op een eigen Z-hoogte (0, h, 2h, ...)
    Geeft terug: (mesh of None, aantal sub-meshes)
    """
    scene_meshes = []
    current_z = 0.0
    total = len(layers)

    # Eerst alle lagen uitrekenen zodat de spiegelas over de hele afbeelding ligt
    layer_polys = [_layer_polygons(layer, num_samples=num_samples) for layer in layers]
    ref_y = reference_height(layers, layer_polys)

    # Volledige voetafdruk voor de L-hoekmarkers (uitlijningsreferentie)
    img_w = max((l.get('width', 0) for l in layers), default=0)
    img_h = max((l.get('height', 0) for l in layers), default=0)

    for i, layer in enumerate(layers):
        polygons = layer_polys[i]
        if progress_cb is not None:
            progress_cb(i, total)

        if not polygons:
            continue

        # Voeg overlappende of meerdere polygonen in dezelfde laag samen
        merged_poly = unary_union(polygons)
        if merged_poly.is_empty:
            continue

        if isinstance(merged_poly, Polygon):
            poly_list = [merged_poly]
        elif isinstance(merged_poly, MultiPolygon):
            poly_list = list(merged_poly.geoms)
        else:
            continue

        new_meshes = _polygons_to_meshes(
            poly_list, layer_height,
            scale=scale, flip_y=flip_y, ref_y=ref_y,
            hex_color=layer.get('hex'), vertex_colors=vertex_colors,
            layer_id=layer.get('index', i + 1)
        )
        if not new_meshes:
            continue

        # Kader om de volledige voetafdruk: elke laag krijgt dezelfde
        # bounding box, zodat slicers de losse lagen op elkaar uitlijnen.
        # Zorgt ook voor voldoende volume (>9 mm³) om PrusaSlicer's 'inches' waarschuwing te voorkomen.
        if img_w and img_h:
            new_meshes.extend(_frame_mesh(
                img_w, img_h, scale, layer_height,
                frame_width=0.3,
                hex_color=layer.get('hex'), vertex_colors=vertex_colors))

        if stack:
            for m in new_meshes:
                m.apply_translation([0, 0, current_z])
            current_z += layer_height

        scene_meshes.extend(new_meshes)

    if progress_cb is not None:
        progress_cb(total, total)

    if not scene_meshes:
        return None, 0
    return trimesh.util.concatenate(scene_meshes), len(scene_meshes)


def svg_to_obj(input_svg, output_obj, layer_height=0.2, num_samples=200, scale=1.0,
               flip_y=True, vertex_colors=False):
    """
    Exporteert een (gelaagd) SVG-bestand naar een geëxtrudeerde 3D OBJ mesh.
    Paden worden per laag-id gegroepeerd en op Z gestapeld.
    """
    paths, attributes, svg_attributes = svg2paths2(input_svg)

    # Groepeer paden per laag (of op id/volgorde als er geen expliciete lagen zijn)
    layers = {}
    for idx, (path, attr) in enumerate(zip(paths, attributes)):
        layer_id = attr.get('id', attr.get('class', f'layer_{idx}'))
        # L-hoekmarkers zijn hulplijnen, geen vlakken -> niet mee-extruderen
        if MARKER_SUFFIX in str(layer_id):
            continue
        layers.setdefault(layer_id, []).append(path)

    # Hoogte uit het SVG-bestand voor een consistente Y-flip over alle lagen.
    # Bij een viewBox zijn de user units expliciet; img_w/img_h (user units)
    # bepalen de voetafdruk voor de L-hoekmarkers.
    ref_y = None
    img_w = img_h = 0
    try:
        vb = str(svg_attributes.get('viewBox', '')).strip()
        if vb:
            parts = vb.replace(',', ' ').split()
            if len(parts) == 4:
                ref_y = float(parts[3])
                img_w = float(parts[2])
                img_h = float(parts[3])
    except (TypeError, ValueError):
        ref_y = None

    # Eerst alle lagen uitrekenen zodat de spiegelas over de hele tekening ligt
    layer_polys = []
    for layer_paths in layers.values():
        polys = []
        for path in layer_paths:
            polys.extend(path_to_polygons(path, num_samples=num_samples))
        layer_polys.append(polys)

    # Zonder viewBox zijn width/height fysieke eenheden (mm), geen user units:
    # voetafdruk en spiegelas dan afleiden uit de polygonen zelf, zodat markers
    # en content in hetzelfde coördinatenstelsel staan.
    if ref_y is None or not img_w or not img_h:
        minx = miny = float('inf')
        maxx = maxy = float('-inf')
        for polys in layer_polys:
            for p in polys:
                if p.is_empty:
                    continue
                x0, y0, x1, y1 = p.bounds
                minx = min(minx, x0)
                miny = min(miny, y0)
                maxx = max(maxx, x1)
                maxy = max(maxy, y1)
        if ref_y is None and maxy != float('-inf'):
            ref_y = maxy
        if not img_w and maxx != float('-inf'):
            img_w = maxx
        if not img_h and maxy != float('-inf'):
            img_h = maxy

    if ref_y is None:
        ref_y = reference_height([], layer_polys)

    scene_meshes = []
    current_z = 0.0

    for (layer_id, layer_paths), polygons in zip(layers.items(), layer_polys):
        if not polygons:
            continue

        merged_poly = unary_union(polygons)
        if merged_poly.is_empty:
            continue

        if isinstance(merged_poly, Polygon):
            poly_list = [merged_poly]
        elif isinstance(merged_poly, MultiPolygon):
            poly_list = list(merged_poly.geoms)
        else:
            continue

        new_meshes = _polygons_to_meshes(
            poly_list, layer_height,
            scale=scale, flip_y=flip_y, ref_y=ref_y,
            vertex_colors=vertex_colors, layer_id=layer_id
        )

        # Kader om de volledige voetafdruk: elke laag krijgt dezelfde
        # bounding box, zodat slicers de losse lagen op elkaar uitlijnen.
        # Zorgt ook voor voldoende volume (>9 mm³) om PrusaSlicer's 'inches' waarschuwing te voorkomen.
        if img_w and img_h:
            new_meshes.extend(_frame_mesh(
                img_w, img_h, scale, layer_height,
                frame_width=0.3,
                hex_color=None, vertex_colors=vertex_colors))

        for m in new_meshes:
            m.apply_translation([0, 0, current_z])
        scene_meshes.extend(new_meshes)

        # Stapel de volgende laag er bovenop op de Z-as
        if new_meshes:
            current_z += layer_height

    if not scene_meshes:
        raise ValueError("Geen geldige paden gevonden om te converteren.")

    # CLI volume warnings
    for (layer_id, layer_paths), polygons in zip(layers.items(), layer_polys):
        if not polygons:
            continue
        frame_vol = 2 * 0.3 * layer_height * (img_w * scale + img_h * scale)
        content_vol = 0.0
        for p in polygons:
            if not p.is_empty:
                x0, y0, x1, y1 = p.bounds
                content_vol += (x1 - x0) * (y1 - y0) * scale * scale * layer_height
        total_vol = frame_vol + content_vol
        if total_vol < PRUSA_VOLUME_THRESHOLD_MM3:
            print(f"WARNING: Layer {layer_id} volume {total_vol:.1f}mm³ < 9mm³ (PrusaSlicer threshold)", 
                  file=sys.stderr)

    combined_mesh = trimesh.util.concatenate(scene_meshes)
    combined_mesh.export(output_obj)
    return len(scene_meshes)


# ----------------------------------------------------------------------------
# Workers
# ----------------------------------------------------------------------------

class ProcessingThread(QThread):
    finished_signal = pyqtSignal(object, object, object)
    error_signal = pyqtSignal(str)

    def __init__(self, image_path, num_colors, blur_radius, min_area, sat_boost, luma_weight):
        super().__init__()
        self.image_path = image_path
        self.num_colors = num_colors
        self.blur_radius = blur_radius
        self.min_area = min_area
        self.sat_boost = sat_boost
        self.luma_weight = luma_weight

    def run(self):
        try:
            gc.collect()
            orig, comb, layers = process_image_layers(
                self.image_path,
                self.num_colors,
                self.blur_radius,
                self.min_area,
                self.sat_boost,
                self.luma_weight
            )
            self.finished_signal.emit(orig, comb, layers)
        except Exception as e:
            self.error_signal.emit(str(e))


class ObjExportThread(QThread):
    """Voert de SVG -> OBJ conversie uit zonder de GUI te blokkeren."""
    progress_signal = pyqtSignal(str)                 # statusregel
    done_signal = pyqtSignal(int, int, object)        # jobs_ok, meshes, job_names
    error_signal = pyqtSignal(str)

    def __init__(self, jobs, layer_height, num_samples, scale, flip_y, vertex_colors):
        super().__init__()
        self.jobs = jobs  # [{'layers': [...], 'path': str, 'stack': bool, 'name': str}, ...]
        self.layer_height = layer_height
        self.num_samples = num_samples
        self.scale = scale
        self.flip_y = flip_y
        self.vertex_colors = vertex_colors

    def run(self):
        try:
            gc.collect()
            meshes_total = 0
            done_names = []
            total_jobs = len(self.jobs)

            for job_idx, job in enumerate(self.jobs):
                out_path = job['path']

                mesh, count = layers_to_mesh(
                    job['layers'],
                    layer_height=self.layer_height,
                    num_samples=self.num_samples,
                    scale=self.scale,
                    flip_y=self.flip_y,
                    vertex_colors=self.vertex_colors,
                    stack=job.get('stack', True),
                    progress_cb=lambda cur, tot, j=job, ji=job_idx: self.progress_signal.emit(
                        f"[{ji + 1}/{total_jobs}] {j['name']} :: {cur}/{tot}"
                    )
                )

                if mesh is None:
                    self.progress_signal.emit(f"{job['name']} :: leeg")
                    continue

                Path(out_path).parent.mkdir(parents=True, exist_ok=True)
                mesh.export(out_path)
                meshes_total += count
                done_names.append(job['name'])
                self.progress_signal.emit(f"{job['name']} :: {count} meshes")

            self.done_signal.emit(len(done_names), meshes_total, done_names)
        except Exception as e:
            self.error_signal.emit(str(e))


# ----------------------------------------------------------------------------
# Hoofdvenster
# ----------------------------------------------------------------------------

class SVGLayerSplitterApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.current_lang = DEFAULT_LANG
        self.setGeometry(100, 100, 1300, 900)

        self.image_path = None
        self.current_layers = []
        self.worker_thread = None
        self.obj_thread = None

        self.init_menu()
        self.init_ui()
        self.retranslate_ui()

    def tr(self, key):
        return TRANSLATIONS[self.current_lang].get(key, key)

    def init_menu(self):
        self.menubar = self.menuBar()

        # Bestand Menu
        self.file_menu = self.menubar.addMenu("")

        self.save_preset_action = QAction("", self)
        self.save_preset_action.triggered.connect(self.save_preset)
        self.file_menu.addAction(self.save_preset_action)

        self.load_preset_action = QAction("", self)
        self.load_preset_action.triggered.connect(self.load_preset)
        self.file_menu.addAction(self.load_preset_action)

        # Taal Menu
        self.lang_menu = self.menubar.addMenu("")

        self.action_lang_nl = QAction("Nederlands", self)
        self.action_lang_nl.triggered.connect(lambda: self.change_language("nl"))
        self.lang_menu.addAction(self.action_lang_nl)

        self.action_lang_en = QAction("English", self)
        self.action_lang_en.triggered.connect(lambda: self.change_language("en"))
        self.lang_menu.addAction(self.action_lang_en)

        self.action_lang_es = QAction("Español", self)
        self.action_lang_es.triggered.connect(lambda: self.change_language("es"))
        self.lang_menu.addAction(self.action_lang_es)

        # Help Menu
        self.help_menu = self.menubar.addMenu("")

        self.about_action = QAction("", self)
        self.about_action.triggered.connect(self.show_about)
        self.help_menu.addAction(self.about_action)

    def change_language(self, lang_code):
        if self.current_lang != lang_code and lang_code in TRANSLATIONS:
            self.current_lang = lang_code
            self.retranslate_ui()

    def show_about(self):
        box = QMessageBox(self)
        box.setWindowTitle(self.tr("about_title"))
        box.setIcon(QMessageBox.Icon.Information)
        box.setTextFormat(Qt.TextFormat.RichText)
        box.setText(
            f"<div style='text-align: center;'>"
            f"<b>ColorStack</b><br>"
            f"{self.tr('about_version')} {APP_VERSION}<br><br>"
            f"</div>"
            f"{self.tr('about_description')}<br><br>"
            f"<div style='text-align: center;'>"
            f"Mazhive Productions (2026)"
            f"</div>"
        )
        box.setStandardButtons(QMessageBox.StandardButton.Ok)
        box.button(QMessageBox.StandardButton.Ok).setText(self.tr("about_ok"))
        box.exec()

    def retranslate_ui(self):
        self.setWindowTitle(f"{self.tr('title')} — {APP_VERSION}")

        # Menus
        self.file_menu.setTitle(self.tr("menu_file"))
        self.save_preset_action.setText(self.tr("menu_save_preset"))
        self.load_preset_action.setText(self.tr("menu_load_preset"))
        self.lang_menu.setTitle(self.tr("menu_lang"))
        self.help_menu.setTitle(self.tr("menu_help"))
        self.about_action.setText(self.tr("menu_about"))

        # Headers
        self.lbl_left_header.setText(self.tr("left_header"))
        self.lbl_center_header.setText(self.tr("center_header"))
        self.lbl_orig_title.setText(self.tr("orig_title"))
        self.lbl_right_header.setText(self.tr("right_header"))

        if not self.image_path:
            self.lbl_orig_preview.setText(self.tr("no_image"))
            self.lbl_file_name.setText(self.tr("no_file"))

        if not self.current_layers:
            self.lbl_layer_title.setText(self.tr("layer_title_default"))
            self.lbl_layer_preview.setText(self.tr("no_processing"))
        else:
            self.lbl_layer_title.setText(self.tr("total_overview"))

        # Sliders, Checkbox & Buttons
        self.lbl_slider_colors.setText(self.tr("slider_colors"))
        self.lbl_slider_sat.setText(self.tr("slider_sat"))
        self.lbl_slider_luma.setText(self.tr("slider_luma"))
        self.lbl_slider_blur.setText(self.tr("slider_blur"))
        self.lbl_slider_area.setText(self.tr("slider_area"))

        self.btn_select.setText(self.tr("btn_select"))
        self.btn_apply.setText(self.tr("btn_apply"))
        self.chk_single_file.setText(self.tr("chk_single_file"))
        self.btn_export.setText(self.tr("btn_export"))

        # OBJ
        self.obj_group.setTitle(self.tr("obj_group"))
        self.lbl_slider_obj_height.setText(self.tr("slider_obj_height"))
        self.lbl_slider_obj_samples.setText(self.tr("slider_obj_samples"))
        self.lbl_obj_scale.setText(self.tr("lbl_obj_scale"))
        self.chk_obj_flip_y.setText(self.tr("chk_obj_flip_y"))
        self.chk_obj_colors.setText(self.tr("chk_obj_colors"))
        self.btn_export_obj.setText(self.tr("btn_export_obj"))

        if self.current_layers:
            self.rebuild_thumbnails()

    def init_ui(self):
        main_widget = QWidget()
        main_layout = QHBoxLayout(main_widget)

        splitter = QSplitter(Qt.Orientation.Horizontal)

        # ------------------- LINKER PANEEL -------------------
        left_container = QWidget()
        left_layout = QVBoxLayout(left_container)
        self.lbl_left_header = QLabel()
        left_layout.addWidget(self.lbl_left_header)

        self.scroll_area = QScrollArea()
        self.scroll_area.setWidgetResizable(True)
        self.scroll_content = QWidget()
        self.layer_list_layout = QVBoxLayout(self.scroll_content)
        self.layer_list_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        self.scroll_area.setWidget(self.scroll_content)

        left_layout.addWidget(self.scroll_area)
        left_container.setMinimumWidth(230)
        splitter.addWidget(left_container)

        # ------------------- MIDDEN PANEEL -------------------
        center_container = QWidget()
        center_layout = QVBoxLayout(center_container)

        self.lbl_center_header = QLabel()
        center_layout.addWidget(self.lbl_center_header)

        previews_hbox = QHBoxLayout()

        # Original Preview
        orig_box = QVBoxLayout()
        self.lbl_orig_title = QLabel()
        orig_box.addWidget(self.lbl_orig_title)
        self.lbl_orig_preview = QLabel()
        self.lbl_orig_preview.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_orig_preview.setStyleSheet("border: 1px solid #ccc; background: #f9f9f9;")
        orig_box.addWidget(self.lbl_orig_preview, 1)
        previews_hbox.addLayout(orig_box)

        # Layer / Combined Preview
        layer_box = QVBoxLayout()
        self.lbl_layer_title = QLabel()
        layer_box.addWidget(self.lbl_layer_title)
        self.lbl_layer_preview = QLabel()
        self.lbl_layer_preview.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_layer_preview.setStyleSheet("border: 1px solid #ccc; background: #ffffff;")
        layer_box.addWidget(self.lbl_layer_preview, 1)
        previews_hbox.addLayout(layer_box)

        center_layout.addLayout(previews_hbox, 1)

        # Controls
        controls_frame = QFrame()
        controls_frame.setFrameShape(QFrame.Shape.StyledPanel)
        controls_layout = QVBoxLayout(controls_frame)

        # File Select
        file_btn_layout = QHBoxLayout()
        self.btn_select = QPushButton()
        self.btn_select.clicked.connect(self.select_file)
        self.lbl_file_name = QLabel()
        file_btn_layout.addWidget(self.btn_select)
        file_btn_layout.addWidget(self.lbl_file_name)
        controls_layout.addLayout(file_btn_layout)

        # Slider 1: Colors (10)
        color_layout = QHBoxLayout()
        self.lbl_slider_colors = QLabel()
        color_layout.addWidget(self.lbl_slider_colors)
        self.slider_colors = QSlider(Qt.Orientation.Horizontal)
        self.slider_colors.setRange(2, 32)
        self.slider_colors.setValue(10)
        self.lbl_colors_val = QLabel("10")
        self.slider_colors.valueChanged.connect(lambda v: self.lbl_colors_val.setText(str(v)))
        color_layout.addWidget(self.slider_colors)
        color_layout.addWidget(self.lbl_colors_val)
        controls_layout.addLayout(color_layout)

        # Slider 2: Saturation (1.5x)
        sat_layout = QHBoxLayout()
        self.lbl_slider_sat = QLabel()
        sat_layout.addWidget(self.lbl_slider_sat)
        self.slider_sat = QSlider(Qt.Orientation.Horizontal)
        self.slider_sat.setRange(10, 30)
        self.slider_sat.setValue(15)
        self.lbl_sat_val = QLabel("1.5x")
        self.slider_sat.valueChanged.connect(lambda v: self.lbl_sat_val.setText(f"{v/10:.1f}x"))
        sat_layout.addWidget(self.slider_sat)
        sat_layout.addWidget(self.lbl_sat_val)
        controls_layout.addLayout(sat_layout)

        # Slider 3: Luma (0.3)
        luma_layout = QHBoxLayout()
        self.lbl_slider_luma = QLabel()
        luma_layout.addWidget(self.lbl_slider_luma)
        self.slider_luma = QSlider(Qt.Orientation.Horizontal)
        self.slider_luma.setRange(1, 10)
        self.slider_luma.setValue(3)
        self.lbl_luma_val = QLabel("0.3")
        self.slider_luma.valueChanged.connect(lambda v: self.lbl_luma_val.setText(f"{v/10:.1f}"))
        luma_layout.addWidget(self.slider_luma)
        luma_layout.addWidget(self.lbl_luma_val)
        controls_layout.addLayout(luma_layout)

        # Slider 4: Blur (1)
        blur_layout = QHBoxLayout()
        self.lbl_slider_blur = QLabel()
        blur_layout.addWidget(self.lbl_slider_blur)
        self.slider_blur = QSlider(Qt.Orientation.Horizontal)
        self.slider_blur.setRange(0, 10)
        self.slider_blur.setValue(1)
        self.lbl_blur_val = QLabel("1")
        self.slider_blur.valueChanged.connect(lambda v: self.lbl_blur_val.setText(str(v)))
        blur_layout.addWidget(self.slider_blur)
        blur_layout.addWidget(self.lbl_blur_val)
        controls_layout.addLayout(blur_layout)

        # Slider 5: Detail Area (38px)
        area_layout = QHBoxLayout()
        self.lbl_slider_area = QLabel()
        area_layout.addWidget(self.lbl_slider_area)
        self.slider_area = QSlider(Qt.Orientation.Horizontal)
        self.slider_area.setRange(1, 100)
        self.slider_area.setValue(38)
        self.lbl_area_val = QLabel("38 px")
        self.slider_area.valueChanged.connect(lambda v: self.lbl_area_val.setText(f"{v} px"))
        area_layout.addWidget(self.slider_area)
        area_layout.addWidget(self.lbl_area_val)
        controls_layout.addLayout(area_layout)

        # Recalculate Button
        self.btn_apply = QPushButton()
        self.btn_apply.setStyleSheet("font-weight: bold; background-color: #285DA3; color: white; padding: 6px;")
        self.btn_apply.clicked.connect(self.start_processing)
        self.btn_apply.setEnabled(False)
        controls_layout.addWidget(self.btn_apply)

        # Progress bar
        self.progress_bar = QProgressBar()
        self.progress_bar.setRange(0, 0)
        self.progress_bar.setVisible(False)
        controls_layout.addWidget(self.progress_bar)

        center_layout.addWidget(controls_frame)

        # ------------------- EXPORT PANEEL (SVG + OBJ) -------------------
        export_layout = QVBoxLayout()

        self.chk_single_file = QCheckBox()
        self.chk_single_file.setChecked(True)
        self.chk_single_file.setStyleSheet("font-weight: bold; margin-bottom: 4px;")
        export_layout.addWidget(self.chk_single_file)

        # SVG
        self.btn_export = QPushButton()
        self.btn_export.setStyleSheet("background-color: #28A048; color: white; font-size: 14px; padding: 8px;")
        self.btn_export.clicked.connect(self.export_svgs)
        self.btn_export.setEnabled(False)
        export_layout.addWidget(self.btn_export)

        # OBJ 3D opties
        self.obj_group = QGroupBox()
        obj_layout = QVBoxLayout(self.obj_group)

        # Laagdikte (0.2 mm)
        height_layout = QHBoxLayout()
        self.lbl_slider_obj_height = QLabel()
        height_layout.addWidget(self.lbl_slider_obj_height)
        self.slider_obj_height = QSlider(Qt.Orientation.Horizontal)
        self.slider_obj_height.setRange(1, 100)
        self.slider_obj_height.setValue(2)
        self.lbl_obj_height_val = QLabel("0.2 mm")
        self.slider_obj_height.valueChanged.connect(
            lambda v: self.lbl_obj_height_val.setText(f"{v/10:.1f} mm"))
        height_layout.addWidget(self.slider_obj_height)
        height_layout.addWidget(self.lbl_obj_height_val)
        obj_layout.addLayout(height_layout)

        # Schaal (mm per pixel)
        scale_layout = QHBoxLayout()
        self.lbl_obj_scale = QLabel()
        scale_layout.addWidget(self.lbl_obj_scale)
        self.spin_obj_scale = QDoubleSpinBox()
        self.spin_obj_scale.setRange(0.005, 5.0)
        self.spin_obj_scale.setSingleStep(0.01)
        self.spin_obj_scale.setDecimals(3)
        self.spin_obj_scale.setValue(0.1)
        self.spin_obj_scale.setSuffix(" mm/px")
        scale_layout.addWidget(self.spin_obj_scale, 1)
        obj_layout.addLayout(scale_layout)

        # Pad-resolutie (samples)
        samples_layout = QHBoxLayout()
        self.lbl_slider_obj_samples = QLabel()
        samples_layout.addWidget(self.lbl_slider_obj_samples)
        self.slider_obj_samples = QSlider(Qt.Orientation.Horizontal)
        self.slider_obj_samples.setRange(10, 500)
        self.slider_obj_samples.setValue(200)
        self.lbl_obj_samples_val = QLabel("200")
        self.slider_obj_samples.valueChanged.connect(
            lambda v: self.lbl_obj_samples_val.setText(str(v)))
        samples_layout.addWidget(self.slider_obj_samples)
        samples_layout.addWidget(self.lbl_obj_samples_val)
        obj_layout.addLayout(samples_layout)

        self.chk_obj_flip_y = QCheckBox()
        self.chk_obj_flip_y.setChecked(True)
        obj_layout.addWidget(self.chk_obj_flip_y)

        self.chk_obj_colors = QCheckBox()
        self.chk_obj_colors.setChecked(False)
        obj_layout.addWidget(self.chk_obj_colors)

        export_layout.addWidget(self.obj_group)

        # OBJ export knop
        self.btn_export_obj = QPushButton()
        self.btn_export_obj.setStyleSheet(
            "background-color: #E07B00; color: white; font-size: 14px; font-weight: bold; padding: 8px;")
        self.btn_export_obj.clicked.connect(self.export_objs)
        self.btn_export_obj.setEnabled(False)
        export_layout.addWidget(self.btn_export_obj)

        center_layout.addLayout(export_layout)

        splitter.addWidget(center_container)

        # ------------------- RECHTER PANEEL -------------------
        right_container = QWidget()
        right_layout = QVBoxLayout(right_container)
        self.lbl_right_header = QLabel()
        right_layout.addWidget(self.lbl_right_header)
        self.log_box = QTextEdit()
        self.log_box.setReadOnly(True)
        right_layout.addWidget(self.log_box)
        right_container.setMinimumWidth(200)
        splitter.addWidget(right_container)

        splitter.setSizes([230, 720, 250])
        main_layout.addWidget(splitter)
        self.setCentralWidget(main_widget)

    # ------------------- Presets -------------------

    def save_preset(self):
        preset_data = {
            "num_colors": self.slider_colors.value(),
            "sat_boost": self.slider_sat.value(),
            "luma_weight": self.slider_luma.value(),
            "blur_radius": self.slider_blur.value(),
            "min_area": self.slider_area.value(),
            "obj_layer_height": self.slider_obj_height.value(),
            "obj_scale": self.spin_obj_scale.value(),
            "obj_samples": self.slider_obj_samples.value(),
            "obj_flip_y": self.chk_obj_flip_y.isChecked(),
            "obj_vertex_colors": self.chk_obj_colors.isChecked(),
            "export_single_file": self.chk_single_file.isChecked()
        }

        file_path, _ = QFileDialog.getSaveFileName(
            self, self.tr("menu_save_preset"), "default_preset.json", "JSON (*.json)"
        )
        if file_path:
            try:
                with open(file_path, "w", encoding="utf-8") as f:
                    json.dump(preset_data, f, indent=4)
                self.log_box.append(f"{self.tr('preset_saved')} {Path(file_path).name}")
            except Exception as e:
                self.log_box.append(f"{self.tr('err_save_preset')} {str(e)}")

    def load_preset(self):
        file_path, _ = QFileDialog.getOpenFileName(
            self, self.tr("menu_load_preset"), "", "JSON (*.json)"
        )
        if file_path:
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    preset_data = json.load(f)

                if "num_colors" in preset_data:
                    self.slider_colors.setValue(preset_data["num_colors"])
                if "sat_boost" in preset_data:
                    self.slider_sat.setValue(preset_data["sat_boost"])
                if "luma_weight" in preset_data:
                    self.slider_luma.setValue(preset_data["luma_weight"])
                if "blur_radius" in preset_data:
                    self.slider_blur.setValue(preset_data["blur_radius"])
                if "min_area" in preset_data:
                    self.slider_area.setValue(preset_data["min_area"])
                if "obj_layer_height" in preset_data:
                    self.slider_obj_height.setValue(int(preset_data["obj_layer_height"]))
                if "obj_scale" in preset_data:
                    self.spin_obj_scale.setValue(float(preset_data["obj_scale"]))
                if "obj_samples" in preset_data:
                    self.slider_obj_samples.setValue(int(preset_data["obj_samples"]))
                if "obj_flip_y" in preset_data:
                    self.chk_obj_flip_y.setChecked(bool(preset_data["obj_flip_y"]))
                if "obj_vertex_colors" in preset_data:
                    self.chk_obj_colors.setChecked(bool(preset_data["obj_vertex_colors"]))
                if "export_single_file" in preset_data:
                    self.chk_single_file.setChecked(bool(preset_data["export_single_file"]))

                self.log_box.append(f"{self.tr('preset_loaded')} {Path(file_path).name}")
            except Exception as e:
                self.log_box.append(f"{self.tr('err_load_preset')} {str(e)}")

    # ------------------- Image verwerking -------------------

    def select_file(self):
        file_path, _ = QFileDialog.getOpenFileName(
            self, self.tr("btn_select"), "", "Images (*.png *.jpg *.jpeg *.bmp *.svg)"
        )
        if file_path:
            self.image_path = file_path
            self.lbl_file_name.setText(Path(file_path).name)
            self.btn_apply.setEnabled(True)
            self.log_box.append(f"{self.tr('loaded')}: {file_path}")
            self.start_processing()

    def start_processing(self):
        if not self.image_path:
            return

        if self.worker_thread and self.worker_thread.isRunning():
            self.log_box.append(self.tr("waiting"))
            return

        self.btn_apply.setEnabled(False)
        self.btn_export.setEnabled(False)
        self.btn_export_obj.setEnabled(False)
        self.progress_bar.setVisible(True)
        self.log_box.append(self.tr("processing"))

        num_colors = self.slider_colors.value()
        blur_radius = self.slider_blur.value()
        min_area = self.slider_area.value()
        sat_boost = self.slider_sat.value() / 10.0
        luma_weight = self.slider_luma.value() / 10.0

        self.worker_thread = ProcessingThread(
            self.image_path, num_colors, blur_radius, min_area, sat_boost, luma_weight
        )
        self.worker_thread.finished_signal.connect(self.on_processing_finished)
        self.worker_thread.error_signal.connect(self.on_processing_error)
        self.worker_thread.start()

    def on_processing_finished(self, orig_rgb, comb_rgb, layers):
        self.progress_bar.setVisible(False)
        self.btn_apply.setEnabled(True)
        self.btn_export.setEnabled(True)
        self.btn_export_obj.setEnabled(True)
        self.current_layers = layers

        self.set_pixmap_to_label(self.lbl_orig_preview, orig_rgb)
        self.set_pixmap_to_label(self.lbl_layer_preview, comb_rgb)
        self.lbl_layer_title.setText(self.tr("total_overview"))

        self.rebuild_thumbnails()

        msg = self.tr("success_processed").format(count=len(layers))
        self.log_box.append(msg)
        gc.collect()

    def rebuild_thumbnails(self):
        self.clear_layer_thumbnails()
        # Get export params for volume calculation
        scale = self.spin_obj_scale.value()
        layer_height = self.slider_obj_height.value() / 10.0
        frame_width = 0.3
        img_w = self.current_layers[0]['width']
        img_h = self.current_layers[0]['height']
        
        for idx, layer in enumerate(self.current_layers):
            item_widget = QFrame()
            item_widget.setFrameShape(QFrame.Shape.Box)
            item_widget.setStyleSheet("QFrame { background-color: #ffffff; margin-bottom: 4px; }")

            item_layout = QHBoxLayout(item_widget)
            item_layout.setContentsMargins(5, 5, 5, 5)

            lbl_thumb = QLabel()
            lbl_thumb.setFixedSize(50, 50)
            self.set_pixmap_to_label(lbl_thumb, layer['layer_img'])
            item_layout.addWidget(lbl_thumb)

            lbl_info = QLabel(f"{self.tr('layer')} {layer['index']}\n{layer['hex']}")
            lbl_info.setStyleSheet(f"color: {layer['hex']}; font-weight: bold;")
            item_layout.addWidget(lbl_info)

            # Volume warning badge
            vol = _estimate_layer_volume(layer, img_w, img_h, scale, layer_height, frame_width)
            if vol < PRUSA_VOLUME_THRESHOLD_MM3:
                lbl_warn = QLabel("⚠️ <9mm³")
                lbl_warn.setStyleSheet("color: #e67e22; font-weight: bold; font-size: 11px;")
                lbl_warn.setToolTip(
                    f"Volume: {vol:.1f}mm³ — onder PrusaSlicer limiet (9mm³).\n"
                    f"Kan 'inches' waarschuwing geven in PrusaSlicer.\n"
                    f"Verhoog schaal/laagdikte/detail of sluit laag uit."
                )
                item_layout.addWidget(lbl_warn)

            # Exclude checkbox
            chk_exclude = QCheckBox(self.tr("exclude_layer"))
            chk_exclude.setChecked(layer.get('excluded', False))
            chk_exclude.stateChanged.connect(lambda state, i=idx: self.on_layer_exclude_changed(i, state))
            item_layout.addWidget(chk_exclude)
            layer['_exclude_checkbox'] = chk_exclude

            item_widget.mousePressEvent = lambda e, i=idx: self.select_layer_preview(i)
            self.layer_list_layout.addWidget(item_widget)

    def on_processing_error(self, err_msg):
        self.progress_bar.setVisible(False)
        self.btn_apply.setEnabled(True)
        self.log_box.append(f"{self.tr('err_processing')} {err_msg}")

    def select_layer_preview(self, idx):
        if 0 <= idx < len(self.current_layers):
            layer = self.current_layers[idx]
            self.set_pixmap_to_label(self.lbl_layer_preview, layer['layer_img'])
            self.lbl_layer_title.setText(f"{self.tr('preview_layer')} {layer['index']} ({layer['hex']}):")
            self.log_box.append(f"{self.tr('selected')} {self.tr('layer')} {layer['index']} ({layer['hex']})")

    def on_layer_exclude_changed(self, idx, state):
        """Update layer excluded flag when checkbox changes."""
        if 0 <= idx < len(self.current_layers):
            self.current_layers[idx]['excluded'] = (state == Qt.CheckState.Checked.value)

    def clear_layer_thumbnails(self):
        while self.layer_list_layout.count():
            child = self.layer_list_layout.takeAt(0)
            if child.widget():
                child.widget().deleteLater()

    def set_pixmap_to_label(self, label, numpy_img):
        h, w, ch = numpy_img.shape
        bytes_per_line = ch * w
        img = np.ascontiguousarray(numpy_img)
        q_img = QImage(img.data, w, h, bytes_per_line, QImage.Format.Format_RGB888)
        pixmap = QPixmap.fromImage(q_img)

        scaled_pixmap = pixmap.scaled(
            label.size(), Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation
        )
        label.setPixmap(scaled_pixmap)

    # ------------------- SVG export -------------------

    def export_svgs(self):
        if not self.current_layers:
            return

        w, h = self.current_layers[0]['width'], self.current_layers[0]['height']
        frame_path = generate_frame_path(w, h, frame_width=3)
        scale = self.spin_obj_scale.value()
        mm_w = w * scale
        mm_h = h * scale

        if self.chk_single_file.isChecked():
            file_path, _ = QFileDialog.getSaveFileName(
                self, self.tr("export_dialog"), "combined_layers.svg", "SVG Bestanden (*.svg)"
            )
            if not file_path:
                return

            # nsmap wordt niet door svgwrite ondersteund: prefix handmatig op de
            # root zetten, anders is 'inkscape:' een ongebonden prefix -> ongeldige SVG
            dwg = svgwrite.Drawing(os.fspath(file_path), size=(f"{mm_w:.3f}mm", f"{mm_h:.3f}mm"),
                                   profile='full', debug=False)
            dwg.viewbox(0, 0, w, h)
            dwg.attribs['xmlns:inkscape'] = INKSCAPE_NSMAP['inkscape']

            export_layers = [l for l in self.current_layers if not l.get('excluded', False)]
            if not export_layers:
                self.log_box.append("⚠️ Geen lagen geselecteerd voor export (alles uitgesloten).")
                return

            # Volume warnings
            for layer in export_layers:
                vol = _estimate_layer_volume(layer, w, h, scale, layer_height, frame_width)
                if vol < PRUSA_VOLUME_THRESHOLD_MM3:
                    self.log_box.append(
                        f"⚠️ Laag {layer['index']} ({layer['hex']}): volume {vol:.1f}mm³ < 9mm³ — "
                        f"PrusaSlicer 'inches' waarschuwing mogelijk. "
                        f"Verhoog schaal/laagdikte/detail of sluit laag uit."
                    )

            for layer in export_layers:
                layer_id = f"layer_{layer['index']}_{layer['hex'][1:]}"
                layer_group = dwg.g(id=layer_id)
                layer_group.attribs['inkscape:groupmode'] = 'layer'
                layer_group.attribs['inkscape:label'] = f"Layer {layer['index']} - {layer['hex']}"

                path_data = " ".join(layer['paths'])
                if path_data:
                    path = dwg.path(d=path_data, fill=layer['hex'], stroke="none",
                                    fill_rule="evenodd",
                                    id=f"{layer_id}_fill")
                    layer_group.add(path)

                layer_group.add(dwg.path(d=frame_path, fill="none", stroke=layer['hex'],
                                         stroke_width=1.5,
                                         id=f"{layer_id}{MARKER_SUFFIX}_frame"))

                dwg.add(layer_group)

            dwg.save()
            self.log_box.append(f"{self.tr('saved_file')} {Path(file_path).name}")

        else:
            out_dir = QFileDialog.getExistingDirectory(self, self.tr("export_dialog"))
            if not out_dir:
                return

            export_layers = [l for l in self.current_layers if not l.get('excluded', False)]
            if not export_layers:
                self.log_box.append("⚠️ Geen lagen geselecteerd voor export (alles uitgesloten).")
                return

            # Volume warnings
            for layer in export_layers:
                vol = _estimate_layer_volume(layer, w, h, scale, layer_height, frame_width)
                if vol < PRUSA_VOLUME_THRESHOLD_MM3:
                    self.log_box.append(
                        f"⚠️ Laag {layer['index']} ({layer['hex']}): volume {vol:.1f}mm³ < 9mm³ — "
                        f"PrusaSlicer 'inches' waarschuwing mogelijk. "
                        f"Verhoog schaal/laagdikte/detail of sluit laag uit."
                    )

            for layer in export_layers:
                layer_filename = Path(out_dir) / f"layer_{layer['index']:02d}_{layer['hex'][1:]}.svg"
                layer_id = f"layer_{layer['index']}_{layer['hex'][1:]}"
                dwg = svgwrite.Drawing(os.fspath(layer_filename), size=(f"{mm_w:.3f}mm", f"{mm_h:.3f}mm"),
                                       profile='full', debug=False)
                dwg.viewbox(0, 0, w, h)

                path_data = " ".join(layer['paths'])
                if path_data:
                    dwg.add(dwg.path(d=path_data, fill=layer['hex'], stroke="none",
                                     fill_rule="evenodd",
                                     id=f"{layer_id}_fill"))

                dwg.add(dwg.path(d=frame_path, fill="none", stroke=layer['hex'],
                                 stroke_width=1.5,
                                 id=f"{layer_id}{MARKER_SUFFIX}_frame"))

                dwg.save()
                self.log_box.append(f"{self.tr('saved_file')} {layer_filename.name}")

        self.log_box.append(self.tr("export_done"))

    # ------------------- OBJ export (SVG -> 3D) -------------------

    def export_objs(self):
        if not self.current_layers:
            return

        if self.obj_thread and self.obj_thread.isRunning():
            self.log_box.append(self.tr("waiting"))
            return

        layer_height = self.slider_obj_height.value() / 10.0
        num_samples = self.slider_obj_samples.value()
        scale = self.spin_obj_scale.value()
        flip_y = self.chk_obj_flip_y.isChecked()
        vertex_colors = self.chk_obj_colors.isChecked()

        # Filter excluded layers
        export_layers = [l for l in self.current_layers if not l.get('excluded', False)]
        if not export_layers:
            self.log_box.append("⚠️ Geen lagen geselecteerd voor export (alles uitgesloten).")
            return

        # Volume warnings
        for layer in export_layers:
            vol = _estimate_layer_volume(layer, layer['width'], layer['height'], scale, layer_height, 0.3)
            if vol < PRUSA_VOLUME_THRESHOLD_MM3:
                self.log_box.append(
                    f"⚠️ Laag {layer['index']} ({layer['hex']}): volume {vol:.1f}mm³ < 9mm³ — "
                    f"PrusaSlicer 'inches' waarschuwing mogelijk. "
                    f"Verhoog schaal/laagdikte/detail of sluit laag uit."
                )

        jobs = []

        if self.chk_single_file.isChecked():
            # Alle lagen in 1 OBJ, op Z gestapeld
            file_path, _ = QFileDialog.getSaveFileName(
                self, self.tr("obj_export_dialog"), "combined_layers.obj", "OBJ Bestanden (*.obj)"
            )
            if not file_path:
                return
            jobs.append({
                'layers': export_layers,
                'path': os.fspath(file_path),
                'stack': True,
                'name': Path(file_path).name
            })
        else:
            # Per kleur een eigen OBJ, allemaal op Z = 0 (multi-color print)
            out_dir = QFileDialog.getExistingDirectory(self, self.tr("obj_export_dialog"))
            if not out_dir:
                return
            for layer in export_layers:
                layer_filename = Path(out_dir) / f"layer_{layer['index']:02d}_{layer['hex'][1:]}.obj"
                jobs.append({
                    'layers': [layer],
                    'path': os.fspath(layer_filename),
                    'stack': False,
                    'name': layer_filename.name
                })

        self.btn_export_obj.setEnabled(False)
        self.btn_export.setEnabled(False)
        self.progress_bar.setVisible(True)
        self.log_box.append(self.tr("obj_exporting"))

        self.obj_thread = ObjExportThread(
            jobs, layer_height, num_samples, scale, flip_y, vertex_colors
        )
        self.obj_thread.progress_signal.connect(self.on_obj_progress)
        self.obj_thread.done_signal.connect(self.on_obj_done)
        self.obj_thread.error_signal.connect(self.on_obj_error)
        self.obj_thread.start()

    def on_obj_progress(self, status):
        self.log_box.append(f"  {status}")

    def on_obj_done(self, job_count, mesh_count, names):
        self.progress_bar.setVisible(False)
        self.btn_export_obj.setEnabled(True)
        self.btn_export.setEnabled(True)
        gc.collect()

        if mesh_count == 0:
            self.log_box.append(self.tr("obj_no_meshes"))
            return

        if self.chk_single_file.isChecked():
            self.log_box.append(self.tr("obj_done_single").format(
                name=names[0] if names else "?", meshes=mesh_count, layers=len(self.current_layers)))
        else:
            self.log_box.append(self.tr("obj_done_multi").format(
                count=job_count, meshes=mesh_count))

    def on_obj_error(self, err_msg):
        self.progress_bar.setVisible(False)
        self.btn_export_obj.setEnabled(True)
        self.btn_export.setEnabled(True)
        self.log_box.append(f"{self.tr('obj_err')} {err_msg}")


def run_cli(argv):
    parser = argparse.ArgumentParser(
        description="Convert layered SVG files to 3D OBJ meshes.")
    parser.add_argument("input", help="Path to input SVG file")
    parser.add_argument("output", help="Path for output OBJ file")
    parser.add_argument("--height", type=float, default=0.2,
                        help="Extrusion height per layer on Z-axis (default: 0.2)")
    parser.add_argument("--samples", type=int, default=200,
                        help="Number of sample points along curved paths (default: 200)")
    parser.add_argument("--scale", type=float, default=1.0,
                        help="Scale px -> units (default: 1.0)")
    parser.add_argument("--no-flip-y", action="store_true",
                        help="Don't flip Y axis (SVG Y points down)")
    parser.add_argument("--colors", action="store_true",
                        help="Write vertex colors")

    args = parser.parse_args(argv)
    count = svg_to_obj(
        args.input, args.output,
        layer_height=args.height,
        num_samples=args.samples,
        scale=args.scale,
        flip_y=not args.no_flip_y,
        vertex_colors=args.colors
    )
    print(f"Successfully converted: '{args.input}' -> '{args.output}' ({count} meshes generated)")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        run_cli(sys.argv[1:])
    else:
        app = QApplication(sys.argv)
        window = SVGLayerSplitterApp()
        window.show()
        sys.exit(app.exec())
