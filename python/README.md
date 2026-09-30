# ColorStack

**ColorStack** — 3D Print Color Layer Splitter

Split images into color layers using KMeans clustering in LAB color space, then export as print-ready SVG or OBJ files for multi-color 3D printing.

![ColorStack Screenshot](https://github.com/Mazhive/SCRIPTS/python/docs/2026-09-30_16-07.png)

---

## Features

- **Color Layer Splitting** — KMeans clustering in LAB color space for perceptually accurate color separation
- **Interactive Sliders** — Real-time adjustment of:
  - Number of colors (2–32)
  - Saturation boost
  - Luminance weight
  - Blur/nuance filter
  - Minimum detail threshold
- **Live Preview** — Instant preview of selected layer or combined view
- **Per-Layer Exclusion** — Checkbox to exclude problematic layers from export
- **Automatic Volume Check** — Warns if layer volume < 9 mm³ (PrusaSlicer "inches" warning threshold)
- **SVG Export** — mm dimensions, viewBox, 0.3 mm alignment frame
- **OBJ Export** — Extruded 3D layers (0.2 mm default), stacked on Z or separate for multi-color
- **CLI Support** — Headless SVG → OBJ conversion
- **Multi-Language** — Nederlands, English, Español

---

## Installation

### Quick Start (pip)
```bash
pip install PyQt6 opencv-python numpy scikit-learn svgwrite trimesh shapely svgpathtools pillow
```

### Linux (Debian/Ubuntu/Mint)
```bash
sudo apt update
sudo apt install python3-pyqt6 python3-pyqt6.qtsvg python3-opencv python3-numpy python3-sklearn python3-svgwrite python3-trimesh python3-shapely python3-svgpathtools python3-pil
```

### Linux (Arch/Manjaro)
```bash
sudo pacman -S python-pyqt6 python-opencv python-numpy python-scikit-learn python-svgwrite python-trimesh python-shapely python-svgpathtools python-pillow
```

### Linux (Fedora)
```bash
sudo dnf install python3-qt6 python3-opencv python3-numpy python3-scikit-learn python3-svgwrite python3-trimesh python3-shapely python3-svgpathtools python3-pillow
```

### Windows (pip)
```cmd
pip install PyQt6 opencv-python numpy scikit-learn svgwrite trimesh shapely svgpathtools pillow
```

### Windows (Conda)
```cmd
conda install -c conda-forge pyqt opencv numpy scikit-learn svgwrite trimesh shapely svgpathtools pillow
```

### Verify Installation
```bash
python -c "import PyQt6, cv2, numpy, sklearn, svgwrite, trimesh, shapely, svgpathtools, PIL; print('All dependencies OK')"
```

---

## Usage

### GUI Mode
```bash
python ColorStack.py
```

1. **Select Image** — Click "Select Image" to load PNG/JPG/BMP/SVG
2. **Adjust Sliders** — Tweak colors, saturation, luminance, blur, detail
3. **Click "Recalculate / Apply"** — Generate layers
3. **Review Layers** — Click thumbnails to preview individual layers
4. **Exclude Layers** — Uncheck ☐ to exclude small/problematic layers
5. **Export** — Choose SVG or OBJ export

### CLI Mode (SVG → OBJ)
```bash
python ColorStack.py input.svg output.obj --height 0.2
```

**Options:**
| Option | Default | Description |
|--------|---------|-------------|
| `--height` | 0.2 | Layer height in mm |
| `--samples` | 200 | Path resolution (curve samples) |
| `--scale` | 1.0 | Scale factor (px → mm) |
| `--no-flip-y` | false | Don't flip Y axis |
| `--colors` | false | Write vertex colors |

---

## Output Formats

### SVG Export
- **Dimensions** — Real-world mm (e.g., 60.000mm × 53.300mm)
- **viewBox** — Pixel coordinates (e.g., 0 0 600 533)
- **Frame** — 0.3 mm perimeter frame for slicer alignment
- **Layers** — Inkscape-compatible layers with color fills
- **Format** — Single combined file or separate files per layer

### OBJ Export
- **Dimensions** — Match SVG (mm units)
- **Layer Height** — Configurable (default 0.2 mm)
- **Stacking** — Single file (stacked on Z) or separate files (Z=0)
- **Frame** — 0.3 mm perimeter frame on every layer
- **Vertex Colors** — Optional per-layer colors

---

## PrusaSlicer Compatibility

ColorStack includes a **0.3 mm perimeter frame** on every layer to ensure:
- Consistent bounding box across all layers
- Automatic alignment in PrusaSlicer/Bambu Studio/Cura
- Volume > 9 mm³ to avoid "inches" warning

**Volume Warning:** Layers with total volume < 9 mm³ show ⚠️ badge. Fix by:
- Increasing scale
- Increasing layer height
- Lowering detail threshold
- Excluding the layer

---

## Configuration

### Sliders
| Slider | Range | Default | Effect |
|--------|-------|---------|--------|
| Colors | 2–32 | 10 | Number of KMeans clusters |
| Saturation | 1.0–3.0× | 1.5× | Color intensity boost |
| Luminance | 0.1–1.0 | 0.3 | Lightness weight in clustering |
| Blur | 0–10 | 1 | Gaussian blur radius (pre-segmentation) |
| Detail | 1–100 px | 38 | Minimum spot size (noise filter) |

### OBJ Settings
| Setting | Range | Default |
|---------|-------|---------|
| Layer Height | 0.1–10.0 mm | 0.2 mm |
| Scale | 0.005–5.0 mm/px | 0.1 mm/px |
| Path Samples | 10–500 | 200 |
| Flip Y | on/off | On |
| Vertex Colors | on/off | Off |

---

## Project Structure

```
ColorStack/
├── ColorStack.py          # Main application
├── dep.txt                # Dependency list (Linux/Windows)
├── README.md              # This file
├── docs/
│   └── screenshot.png     # App screenshot
└── oud/                   # Previous versions
```

---

## Development

### Run from Source
```bash
git clone https://github.com/yourusername/ColorStack.git
cd ColorStack
pip install -r requirements.txt  # or use dep.txt
python ColorStack.py
```

### Requirements
Create `requirements.txt`:
```text
PyQt6>=6.4
opencv-python>=4.8
numpy>=1.24
scikit-learn>=1.3
svgwrite>=1.4
trimesh>=4.0
shapely>=2.0
svgpathtools>=1.6
pillow>=10.0
```

### Building Executable (PyInstaller)
```bash
pip install pyinstaller
pyinstaller --onefile --windowed --name ColorStack \
  --add-data "dep.txt:." \
  --hidden-import=PyQt6.QtSvg \
  --hidden-import=shapely \
  --hidden-import=trimesh \
  ColorStack.py
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `ModuleNotFoundError: PyQt6.QtSvg` | `pip install --upgrade PyQt6` or install `qsvg.dll` (Windows) |
| `GEOS` error (shapely) | `pip install --upgrade shapely` or `conda install geos` |
| SVG preview blank | Install `python3-pyqt6.qtsvg` (Linux) or reinstall PyQt6 (Windows) |
| OBJ too small in PrusaSlicer | Increase scale or layer height; check frame volume > 9 mm³ |
| "Inches" warning in PrusaSlicer | Layer volume < 9 mm³ — increase scale/height or exclude layer |

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Credits

- **Author** — Mazhive Productions
- **Libraries** — PyQt6, OpenCV, NumPy, scikit-learn, svgwrite, trimesh, shapely, svgpathtools, Pillow
- **Icons** — Qt built-in icons

---

## Changelog

### V1.0.8 (2026)
- Renamed to **ColorStack**
- Added per-layer exclusion checkboxes
- Volume warning for PrusaSlicer compatibility
- 0.3 mm alignment frame on all exports
- English CLI help
- Updated translations (NL/EN/ES)

### V1.0.7
- 0.3 mm perimeter frame
- Volume threshold warning
- Layer exclusion support

### V1.0.6
- Corner markers → perimeter frame
- Fixed PrusaSlicer "inches" warning

---

## Support

- **Issues** — [GitHub Issues](https://github.com/mazhive/ColorStack/issues)
- **Discussions** — [GitHub Discussions](https://github.com/mazhive/ColorStack/discussions)

---

*ColorStack V1.0.8 — Mazhive Productions (2026)*
