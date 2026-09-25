#!/usr/bin/env python3
"""Game Launcher - roller-GUI voor de WINEPREFIX launcher-scripts.

De GUI scant template-scripts/game-launchers/*.sh, koppelt elk script aan zijn
icoon in game-launchers/gameicons/ en toont ze in een horizontale roller.
Een klik op een icoon start de launcher als QProcess; de output stroomt live
naar het status-frame rechts. De namen- en icoon-mapping staat onderaan in de
dicts DISPLAY_NAMES en ICON_OVERRIDES - daaronder vrije aanpassing mogelijk.
"""

import os
import re
import signal
from pathlib import Path

from PySide6.QtCore import (QEasingCurve, QProcess, QPointF, QRectF, Qt,
                            QTimer, QVariantAnimation, Signal)
from PySide6.QtGui import (QAction, QColor, QFont, QFontDatabase, QFontMetrics,
                           QIcon, QLinearGradient, QPainter, QPainterPath, QPen,
                           QPixmap, QRadialGradient)
from PySide6.QtWidgets import (QApplication, QCheckBox, QFileDialog,
                               QFrame, QGraphicsObject, QGraphicsScene,
                               QGraphicsView, QGridLayout, QHBoxLayout, QLabel,
                               QLineEdit, QListWidget, QListWidgetItem,
                               QMainWindow, QMessageBox, QPlainTextEdit,
                               QPushButton, QSplitter, QTabBar, QVBoxLayout,
                               QWidget)

BASE = Path(__file__).resolve().parent
LAUNCHERS_DIR = BASE / "template-scripts" / "game-launchers"
ICONS_DIR = LAUNCHERS_DIR / "gameicons"

APP_VERSION = "1.8"

CARD_W = 200.0
CARD_H = 200.0
NAME_H = 40.0
CARD_CORNER = 18.0
SPACING = 195.0
SCENE_H = 470.0
CARD_Y = SCENE_H / 2.0 - 45.0

DISPLAY_NAMES = {
    "angry-birds": "Angry Birds",
    "anno1800": "Anno 1800",
    "aow-planetfall": "AOW: Planetfall",
    "astroidbountyhunter": "Asteroid Bounty Hunter",
    "automationempire": "Automation Empire",
    "callofdutyvanguard": "Call of Duty Vanguard",
    "celeste": "Celeste",
    "citiesskylines": "Cities: Skylines",
    "cyberpunk2077": "Cyberpunk 2077",
    "gta5": "GTA V",
    "oilrush": "Oil Rush",
    "ori-blindforest": "Ori and the Blind Forest",
    "ori-willofthewisps": "Ori and the Will of the Wisps",
    "shadwen": "Shadwen",
    "silence": "Silence",
    "ut2004": "Unreal Tournament 2004",
    "xonotic": "Xonotic",
}

ICON_OVERRIDES = {
    "angry-birds": "angrybirds.png",
    "callofdutyvanguard": "callofdutyvanguard.png",
    "cyberpunk2077": "Cyberpunk.png",
    "citiesskylines": "Cities&Skylines.png",
    "aow-planetfall": "AOW-planetfall.png",
    "astroidbountyhunter": "astroid.bounty.hunter.png",
    "automationempire": "AutomationEmpire.png",
    "ori-blindforest": "ori-blindforest.png",
    "ori-willofthewisps": "ori-willofthewisps.png",
}

STYLE = """
QMainWindow, QWidget { background-color: #171a20; }
QFrame#header { background-color: transparent; }
QMenuBar { background-color: #1e222a; color: #cdd6e0; border-bottom: 1px solid #2a2f3a; }
QMenuBar::item { background: transparent; padding: 5px 10px; border-radius: 6px; }
QMenuBar::item:selected { background-color: #2c333f; }
QMenu { background-color: #1e222a; color: #cdd6e0; border: 1px solid #2a2f3a; }
QMenu::item { padding: 6px 22px; border-radius: 6px; }
QMenu::item:selected { background-color: #35404f; }
QLabel { color: #e8ecf2; }
QLabel#title { font-size: 22px; font-weight: 700; color: #ffffff; letter-spacing: 2px; }
QLabel#subtitle { color: #9aa4b2; }
QLabel#panelTitle { font-size: 14px; font-weight: 600; color: #ffffff; }
QFrame#optionsFrame {
    background-color: #1b202a; border-radius: 12px;
}
QCheckBox {
    color: #cdd6e0; font-size: 13px; spacing: 8px;
}
QMessageBox {
    background-color: #1e222a;
}
QMessageBox QLabel {
    color: #f2f5f9; font-size: 14px;
}
QPushButton {
    background-color: #3a4350; color: #ffffff;
    border: 1px solid #556279; border-radius: 6px;
    padding: 7px 18px; font-weight: 600; font-size: 13px;
}
QPushButton:hover { background-color: #48546a; }
QPushButton:pressed { background-color: #2c333f; }
QMessageBox QPushButton:default {
    background-color: #35608c; border-color: #6ba5d8;
}
QListWidget {
    background-color: #101318; color: #dbe0e8; border: 1px solid #2a2f3a;
    border-radius: 8px; padding: 4px;
}
QListWidget::item { padding: 7px 8px; border-radius: 5px; }
QListWidget::item:selected { background-color: #35404f; }
QPlainTextEdit {
    background-color: #0c0e12; color: #b9c4d4; border: 1px solid #2a2f3a;
    border-radius: 8px; padding: 6px; selection-background-color: #35404f;
}
QSplitter::handle { background-color: #2a2f3a; }
"""


CONF_PATH = Path.home() / ".config" / "gamelauncher" / "installpaths.conf"


def load_paths():
    """Leest GAME_DIR_<GAME_NAME>="<pad>" uit installpaths.conf (zelfde bestand
    en key-formaat als game-conf.sh aan de shell-kant)."""
    paths = {}
    if not CONF_PATH.is_file():
        return paths
    try:
        for raw in CONF_PATH.read_text(encoding="utf-8").splitlines():
            raw = raw.strip()
            if not raw or "=" not in raw:
                continue
            key, value = raw.split("=", 1)
            key, value = key.strip(), value.strip()
            value = value.strip("\"'")
            if key.startswith("GAME_DIR_"):
                paths[key[len("GAME_DIR_"):].upper()] = value
    except OSError:
        return paths
    return paths


def save_paths(paths):
    """Schrijft alle installatiepaden naar installpaths.conf (idempotent)."""
    try:
        CONF_PATH.parent.mkdir(parents=True, exist_ok=True)
        lines = [f'GAME_DIR_{k.upper()}="{v}"' for k, v in sorted(paths.items())]
        CONF_PATH.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
    except OSError:
        return False
    return True


def _norm(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


class Game:
    def __init__(self, key, script_path):
        self.key = key
        self.script = script_path
        self._icon = None
        self._default_dir = None

    @property
    def default_dir(self):
        if self._default_dir is None:
            self._default_dir = self._extract_default_dir()
        return self._default_dir

    @property
    def stored_dir(self):
        # Conf-file-key = GAME_DIR_<GAME_NAME> (mixed case, zoals geëxporteerd
        # door het launcher-script); game.key is de lowercased bestandsnaam.
        return load_paths().get(self.key.upper())

    def _extract_default_dir(self):
        try:
            text = self.script.read_text(encoding="utf-8")
        except OSError:
            return None
        m = re.search(r'^export\s+GAME_DIR="(.*)"', text, re.MULTILINE)
        return m.group(1) if m else None

    @property
    def display_name(self):
        return DISPLAY_NAMES.get(self.key, self._prettify(self.key))

    @staticmethod
    def _prettify(key):
        parts = re.split(r"[-_]", key)
        parts = [p for p in parts if p]
        words = []
        for p in parts:
            sub = re.sub(r"([a-z])([A-Z])", r"\1 \2", p)
            words.extend(w for w in sub.split(" ") if w)
        return " ".join(w[:1].upper() + w[1:] for w in words)

    def pixmap(self):
        if self._icon is not None:
            return self._icon
        icon_file = self._resolve_icon()
        if icon_file and icon_file.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp", ".bmp"):
            pm = QPixmap(str(icon_file))
            if not pm.isNull():
                self._icon = pm
                return pm
        self._icon = _placeholder_pixmap(self.display_name)
        return self._icon

    def _resolve_icon(self):
        override = ICON_OVERRIDES.get(self.key)
        if override:
            cand = ICONS_DIR / override
            if cand.exists():
                return cand
        if not ICONS_DIR.exists():
            return None
        files = list(ICONS_DIR.iterdir())
        norm_icons = {_norm(f.stem): f for f in files}
        key_norm = _norm(self.key)
        if key_norm in norm_icons:
            return norm_icons[key_norm]
        for stem, f in norm_icons.items():
            if stem in key_norm or key_norm in stem:
                return f
        return None


_PLACEHOLDER_CACHE = {}


def _placeholder_pixmap(name):
    if name in _PLACEHOLDER_CACHE:
        return _PLACEHOLDER_CACHE[name]
    pm = QPixmap(512, 512)
    pm.fill(Qt.transparent)
    painter = QPainter(pm)
    painter.setRenderHint(QPainter.Antialiasing)
    hue = sum(ord(c) for c in name) % 360
    g = QLinearGradient(0, 0, 512, 512)
    top = QColor.fromHsl(hue, 120, 58)
    bottom = QColor.fromHsl((hue + 40) % 360, 130, 34)
    g.setColorAt(0.0, top)
    g.setColorAt(1.0, bottom)
    painter.setPen(QPen(QColor(255, 255, 255, 40), 2))
    painter.setBrush(g)
    painter.drawRoundedRect(1, 1, 510, 510, 44, 44)
    words = [w for w in name.split() if w]
    letters = "".join(w[0] for w in words)[:2].upper()
    font = QFont()
    font.setBold(True)
    font.setPointSize(150 if len(letters) == 1 else 110)
    font.setFamily(QFontDatabase.systemFont(QFontDatabase.GeneralFont).family())
    painter.setFont(font)
    painter.setPen(QColor(255, 255, 255))
    painter.drawText(QRectF(0, 0, 512, 512), Qt.AlignCenter, letters)
    painter.end()
    _PLACEHOLDER_CACHE[name] = pm
    return pm


class CoverItem(QGraphicsObject):
    """Eén game-kaart in de roller: icoon + naam, gecentreerd op (0,0)."""

    def __init__(self, game, index):
        super().__init__()
        self.game = game
        self.index = index
        self.selected = False
        self.pix = game.pixmap()
        self.setCursor(Qt.PointingHandCursor)

    def boundingRect(self):
        w = CARD_W + NAME_H * 0.6
        return QRectF(-w / 2, -CARD_H / 2, w, CARD_H + NAME_H)

    def paint(self, painter, option, widget=None):
        painter.setRenderHint(QPainter.Antialiasing)
        painter.setRenderHint(QPainter.SmoothPixmapTransform)
        card = QRectF(-CARD_W / 2, -CARD_H / 2, CARD_W, CARD_H)
        card_path = QPainterPath()
        card_path.addRoundedRect(card, CARD_CORNER, CARD_CORNER)

        pen = QPen(QColor(255, 255, 255, 60), 2.5) if self.selected else QPen(QColor(0, 0, 0, 90), 1.5)
        painter.setBrush(QColor(40, 46, 58))
        painter.setPen(pen)
        painter.drawPath(card_path)

        painter.save()
        painter.setClipPath(card_path)
        painter.drawPixmap(card.toRect(), self.pix)
        strip = QRectF(card.left(), card.bottom() - NAME_H, card.width(), NAME_H)
        grad = QLinearGradient(strip.topLeft(), strip.topLeft() + QPointF(0, NAME_H))
        grad.setColorAt(0.0, QColor(0, 0, 0, 40))
        grad.setColorAt(1.0, QColor(0, 0, 0, 200))
        painter.fillRect(strip, grad)
        painter.restore()

        fm = QFontMetrics(self._name_font())
        painter.setFont(self._name_font())
        name = fm.elidedText(self.game.display_name, Qt.ElideRight, int(CARD_W - 20))
        strip = QRectF(card.left() + 10, card.bottom() - NAME_H, CARD_W - 20, NAME_H)
        painter.setPen(QColor(255, 255, 255))
        painter.drawText(strip, Qt.AlignVCenter | Qt.AlignLeft, name)
        painter.setPen(Qt.NoPen)

    def _name_font(self):
        font = QFont()
        font.setPointSize(10)
        font.setWeight(QFont.DemiBold)
        return font

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            view = self.scene().views()[0]
            view.on_card_clicked(self.index)
            event.accept()
        else:
            super().mousePressEvent(event)


class HaloBackdrop(QGraphicsObject):
    """Subtiel omgevingslicht achter de rollerkaarten.

    Zachte radiale gradient zonder harde rand — vervaagt naar alpha 0 aan de
    randen. Gepositioneerd onder alle items in de scene; volgt de breedte via
    set_bounds() vanuit CarouselView._layout().
    """

    def __init__(self):
        super().__init__()
        self._rect = QRectF()

    def set_bounds(self, x, y, w, h):
        self._rect = QRectF(x, y, w, h)
        self.prepareGeometryChange()

    def boundingRect(self):
        return self._rect

    def paint(self, painter, option, widget=None):
        if self._rect.isNull() or self._rect.width() <= 0 or self._rect.height() <= 0:
            return
        painter.setRenderHint(QPainter.Antialiasing)
        painter.setPen(Qt.NoPen)
        w = self._rect.width()
        h = self._rect.height()
        painter.save()
        painter.translate(self._rect.center())
        # Y-as schalen zodat een cirkel visueel de platte band-ellips wordt.
        # De gradient rekent dan mee in de geschaalde ruimte: ieder punt op de
        # omtrek ligt exact op straal w/2 → stop 1.0 → alpha 0, zonder harde rand.
        painter.scale(1.0, h / w)
        grad = QRadialGradient(0.0, 0.0, w / 2.0)
        grad.setColorAt(0.0, QColor(255, 255, 255, 12))
        grad.setColorAt(0.5, QColor(255, 255, 255, 6))
        grad.setColorAt(1.0, QColor(255, 255, 255, 0))
        painter.setBrush(grad)
        painter.drawEllipse(QPointF(0.0, 0.0), w / 2.0, w / 2.0)
        painter.restore()


class CarouselView(QGraphicsView):
    index_changed = Signal(int)

    def __init__(self, games, parent=None):
        super().__init__(parent)
        self.games = games
        self.items = []
        self._target = 0.0
        self._t = 0.0
        self.index = 0
        self.carousel = self

        self.setFrameShape(QFrame.NoFrame)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setRenderHint(QPainter.Antialiasing)
        self.setRenderHint(QPainter.SmoothPixmapTransform)
        self.setBackgroundBrush(QColor(23, 26, 32))
        self.setAlignment(Qt.AlignCenter)
        self.setDragMode(QGraphicsView.NoDrag)

        self.scene = QGraphicsScene(self)
        self.setScene(self.scene)

        self._halo = HaloBackdrop()
        self.scene.addItem(self._halo)

        for i, game in enumerate(games):
            item = CoverItem(game, i)
            self.scene.addItem(item)
            self.items.append(item)
        if not games:
            return
        self.index = 0
        self.refresh()
        self._anim = QVariantAnimation(self)
        self._anim.valueChanged.connect(self._on_anim)
        self._anim.setEasingCurve(QEasingCurve.OutCubic)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        if self.items:
            self._layout(self._t)

    def _width(self):
        return max(self.viewport().width(), 600)

    def _layout(self, t):
        cx = self._width() / 2.0
        cy = SCENE_H / 2.0 - 45.0
        half = int(len(self.items) / 2) + 1
        self._halo.set_bounds(30, cy - CARD_H / 2 - 20,
                              max(self._width() - 60, 0), CARD_H + NAME_H + 40)
        self._halo.setZValue(-half - 2)
        for item in self.items:
            d = item.index - t
            if abs(d) > half + 1:
                item.setVisible(False)
                continue
            item.setVisible(True)
            scale = max(0.5, 1.0 - 0.24 * abs(d))
            item.setScale(scale)
            item.setZValue(-abs(d))
            item.setPos(QPointF(cx + item.index * SPACING - t * SPACING, cy))
            item.setOpacity(1.0 if abs(d) < 2.6 else max(0.25, 1.0 - 0.25 * (abs(d) - 2.6)))
            item.selected = item.index == self.index
            item.update()

    def refresh(self):
        if self.items:
            self.scene.setSceneRect(0, 0, self._width(), SCENE_H)
            self._layout(self._t)

    def on_card_clicked(self, index):
        if not self.games:
            return
        if self.index != index:
            self.select_index(index)
        self.launch_selected(index)

    def select_index(self, index):
        self.move_to(float(index))

    def _set_index(self, new):
        if new != self.index:
            self.index = new
            self.index_changed.emit(new)

    def move_to(self, target):
        target = max(0.0, min(float(len(self.items) - 1), target))
        if not hasattr(self, "_anim"):
            self._target = target
            self._t = target
            self._set_index(int(round(target)))
            self.refresh()
            return
        self._anim.stop()
        self._target = target
        self._anim.setStartValue(self._t)
        self._anim.setEndValue(target)
        self._anim.setDuration(280)
        self._anim.start()

    def nudge(self, delta):
        if self.games:
            self.move_to(self._target + delta)

    def _on_anim(self, value):
        self._t = float(value)
        self._set_index(int(round(self._t)))
        self.refresh()

    def wheelEvent(self, event):
        steps = event.angleDelta().y() or event.angleDelta().x()
        if steps:
            self.nudge(-1 if steps > 0 else 1)
            event.accept()
            return
        super().wheelEvent(event)

    def keyPressEvent(self, event):
        key = event.key()
        if key == Qt.Key_Left:
            self.nudge(-1)
        elif key == Qt.Key_Right:
            self.nudge(1)
        elif key in (Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space):
            if self.games:
                self.launch_selected(self.index)
        else:
            super().keyPressEvent(event)


class GameRun:
    _log_lines = 5000

    def __init__(self, game, on_status, on_output, extra_env=None, banner=None):
        self.game = game
        self.status = "Starten..."
        self.proc = QProcess()
        self.log = []
        if banner:
            self.log.append(banner)
        self.on_status = on_status
        self.on_output = on_output
        self.proc.setProcessChannelMode(QProcess.MergedChannels)
        self.proc.setProgram("bash")
        self.proc.setArguments([str(game.script)])
        if extra_env:
            env = dict(os.environ)
            env.update({k: str(v) for k, v in extra_env.items()})
            self.proc.setEnvironment([f"{k}={v}" for k, v in env.items()])
        self.proc.readyReadStandardOutput.connect(self._read)
        self.proc.started.connect(lambda: self._set_status("Actief"))
        self.proc.finished.connect(self._finished)

    def start(self):
        self.proc.start()
        self._set_status("Starten...")

    def _set_status(self, status):
        self.status = status
        self.on_status(self)

    def _read(self):
        data = bytes(self.proc.readAllStandardOutput()).decode("utf-8", "replace")
        if data:
            for line in data.splitlines():
                self.log.append(line.strip())
            self.log = self.log[-self._log_lines:]
            self.on_output(self)

    def _finished(self, exit_code, status):
        if status == QProcess.CrashExit:
            self._set_status("Gecrasht")
        else:
            self._set_status(f"Gestopt (exit {exit_code})")

    def stop(self):
        pid = self.proc.processId() if self.proc else 0
        if pid and self.proc and self.proc.state() != QProcess.NotRunning:
            try:
                os.killpg(os.getpgid(pid), signal.SIGTERM)
                self._set_status("Stoppen...")
            except (ProcessLookupError, PermissionError):
                self.proc.terminate()
        elif self.proc:
            self.proc.terminate()


class MainWindow(QMainWindow):
    CAROUSEL_H = 430

    def __init__(self, games):
        super().__init__()
        self.games = games
        self.runs = {}
        self.current_run = None
        self.run_tabs = None
        self._dir_edits = {}
        self.setWindowTitle(f"Game Launcher v{APP_VERSION}")
        self.resize(1360, 840)
        self.setStyleSheet(STYLE)
        self._build_menu()

        root = QWidget()
        self.setCentralWidget(root)
        main_layout = QVBoxLayout(root)
        main_layout.setContentsMargins(10, 10, 10, 10)
        main_layout.setSpacing(8)

        main_layout.addWidget(self._build_header())
        main_layout.addWidget(self._build_carousel_banner())
        main_layout.addWidget(self._build_options())
        main_layout.addWidget(self._build_terminal(), 1)

        if games:
            self._select(0)
            self._sync_dir_field()
            self.setWindowIcon(QIcon(str(BASE / "gamelauncherv1.png")))

    def _build_menu(self):
        menubar = self.menuBar()
        help_menu = menubar.addMenu("Help")

        help_action = QAction("Help (bediening)", self)
        help_action.triggered.connect(self._show_help)
        about_action = QAction(f"Over Game Launcher v{APP_VERSION}", self)
        about_action.triggered.connect(self._show_about)
        help_menu.addAction(help_action)
        help_menu.addAction(about_action)

    def _show_help(self):
        QMessageBox.information(
            self, "Game Launcher",
            "Bediening:\n"
            " · Muiswiel / pijltjes: bladeren door de games\n"
            " · Klik op een icoon of Enter: starten\n"
            " · Installatiemap: eigen pad of leeg laten (standaard uit script)\n"
            " · Checkboxen: Desktop-icoon, Gamescope, SDL3, bevestigen, snapshot")

    def _show_about(self):
        QMessageBox.about(
            self, "Over Game Launcher",
            f"<b>Game Launcher</b> — versie {APP_VERSION}<br>"
            "Roller-GUI voor de WINEPREFIX launcher-scripts.<br><br>"
            "Scant template-scripts/game-launchers/*.sh en start games "
            "via de bijbehorende launcher.")

    def _build_header(self):
        header = QFrame()
        header.setObjectName("header")
        lay = QVBoxLayout(header)
        lay.setContentsMargins(0, 6, 0, 2)
        title = QLabel("VAN VOORN GAME LAUNCHER")
        title.setObjectName("title")
        title.setAlignment(Qt.AlignCenter)
        lay.addWidget(title)
        return header

    def _build_carousel_banner(self):
        self.carousel = CarouselView(self.games)
        self.carousel.launch_selected = lambda i: self._on_launch(i)
        self.carousel.index_changed.connect(lambda i: self._on_carousel_changed(i))
        self.carousel.setFixedHeight(self.CAROUSEL_H)
        self.carousel.setMinimumWidth(600)

        hint = QLabel("Muiswiel / pijltjes: bladeren   ·   klik op een icoon of Enter: starten")
        hint.setAlignment(Qt.AlignCenter)
        hint.setStyleSheet("color: #5f6b7a; font-size: 11px;")

        banner = QFrame()
        banner.setObjectName("carouselBanner")
        bl = QVBoxLayout(banner)
        bl.setContentsMargins(0, 0, 0, 0)
        bl.setSpacing(6)
        bl.addWidget(self.carousel)
        bl.addWidget(hint)
        return banner

    def _build_options(self):
        frame = QFrame()
        frame.setObjectName("optionsFrame")
        lay = QVBoxLayout(frame)
        lay.setContentsMargins(12, 10, 12, 10)
        lay.setSpacing(8)

        self.cb_desktop = QCheckBox("Desktop-icoon op het bureaublad")
        self.cb_desktop.setChecked(True)
        self.cb_gamescope = QCheckBox("Start met Gamescope")
        self.cb_sdl3 = QCheckBox("SDL3-fallback aan (standaard SDL)")
        self.cb_sdl3.setChecked(True)
        self.cb_confirm = QCheckBox("Bevestigen vóór start")
        self.cb_confirm.setChecked(True)
        self.cb_snapshot = QCheckBox("Backup-snapshot vóór elke start (testzone)")

        # Grid van 3 kolommen: schaalt vanzelf naar rechts voor extra
        # checkboxen (een 6e valt in kolom 3, een 7e/8e start een nieuwe rij).
        grid = QGridLayout()
        grid.setHorizontalSpacing(24)
        grid.setVerticalSpacing(6)
        checks = (self.cb_desktop, self.cb_gamescope, self.cb_sdl3,
                  self.cb_confirm, self.cb_snapshot)
        for i, cb in enumerate(checks):
            grid.addWidget(cb, i // 3, i % 3)
        lay.addLayout(grid)

        dir_row = QHBoxLayout()
        dir_row.setSpacing(6)
        self.dir_label = QLabel("Installatiemap")
        self.dir_edit = QLineEdit()
        self.dir_edit.setPlaceholderText("(standaard uit launcher-script)")
        self.dir_edit.textChanged.connect(self._on_dir_edited)
        self.dir_button = QPushButton("Bladeren…")
        self.dir_button.clicked.connect(self._browse_dir)
        dir_row.addWidget(self.dir_label)
        dir_row.addWidget(self.dir_edit, 1)
        dir_row.addWidget(self.dir_button)
        lay.addLayout(dir_row)
        return frame

    def _on_carousel_changed(self, index):
        self._sync_dir_field()

    def _on_dir_edited(self, text):
        game = self._selected_game()
        if game is None:
            return
        if text.strip() == game.default_dir:
            self._dir_edits.pop(game.key, None)
        else:
            self._dir_edits[game.key] = text

    def _selected_game(self):
        if not self.games or self.carousel is None:
            return None
        idx = min(self.carousel.index, len(self.games) - 1)
        return self.games[idx]

    def _stored_dir(self, game):
        return game.stored_dir

    def _sync_dir_field(self):
        game = self._selected_game()
        if game is None:
            self.dir_label.setText("Installatiemap")
            self.dir_edit.clear()
            return
        self.dir_label.setText(f"Installatiemap {game.display_name}")
        value = self._dir_edits.get(
            game.key,
            self._stored_dir(game) or game.default_dir or "")
        if self.dir_edit.text() != (value or ""):
            self.dir_edit.setText(value or "")

    def _browse_dir(self):
        game = self._selected_game()
        start = self.dir_edit.text().strip() or (game.default_dir if game else "")
        chosen = QFileDialog.getExistingDirectory(self, "Kies installatiemap", start)
        if chosen:
            self.dir_edit.setText(chosen)

    def _build_terminal(self):
        frame = QFrame()
        frame.setObjectName("terminalFrame")
        lay = QVBoxLayout(frame)
        lay.setContentsMargins(6, 4, 6, 6)
        lay.setSpacing(4)

        self.run_tabs = QTabBar()
        self.run_tabs.setDrawBase(False)
        self.run_tabs.setExpanding(False)
        self.run_tabs.setMovable(True)
        self.run_tabs.setTabsClosable(True)
        self.run_tabs.tabCloseRequested.connect(self._close_run_tab)
        self.run_tabs.currentChanged.connect(self._on_tab_changed)
        self.run_tabs.hide()
        lay.addWidget(self.run_tabs)

        self.terminal = QPlainTextEdit()
        self.terminal.setReadOnly(True)
        self.terminal.setMaximumBlockCount(GameRun._log_lines)
        mono = QFont(QFontDatabase.systemFont(QFontDatabase.FixedFont))
        mono.setPointSize(11)
        self.terminal.setFont(mono)
        self.terminal.setStyleSheet("""
            QPlainTextEdit {
                background-color: #0a0f0c;
                color: #00ff88;
                border: 1px solid #1a3a2a;
                border-radius: 8px;
                padding: 8px;
                selection-background-color: #004422;
            }
        """)
        lay.addWidget(self.terminal, 1)

        self._welcome()
        return frame

    def _welcome(self):
        self.terminal.appendPlainText("Game Launcher — terminal output")
        self.terminal.appendPlainText("Klik een game-icoon in de banner om te starten.")
        self.terminal.appendPlainText("")

    def _select(self, index):
        if self.games:
            self.carousel.select_index(index)

    def _on_launch(self, index):
        if not self.games or index is None or index >= len(self.games):
            return
        game = self.games[index]
        self.carousel.select_index(index)
        if game.key in self.runs and self.runs[game.key].proc.state() != QProcess.NotRunning:
            self._focus_run(self.runs[game.key])
            self._append_terminal(f"=> {game.display_name} draait al.")
            return
        if self.cb_confirm.isChecked():
            answer = QMessageBox.question(
                self, "Game Launcher",
                f"{game.display_name} starten?",
                QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
            if answer != QMessageBox.Yes:
                return
        extra_env = {
            "GUI_DESKTOP_SHORTCUT": "1" if self.cb_desktop.isChecked() else "0",
            "GUI_GAMESCOPE": "1" if self.cb_gamescope.isChecked() else "0",
            "GUI_SDL3_DYNAMIC_API_OFF": "1" if self.cb_sdl3.isChecked() else "0",
            "SNAPSHOT_BACKUP": "1" if self.cb_snapshot.isChecked() else "0",
            "GAME_GUI": "1",
        }
        chosen_dir = self._dir_edits.get(game.key, "").strip()
        conf_key = game.key.upper()
        paths = load_paths()
        if chosen_dir and chosen_dir != game.default_dir:
            paths[conf_key] = chosen_dir
            extra_env["GUI_GAME_DIR"] = chosen_dir
        else:
            paths.pop(conf_key, None)
            # Geen GUI_GAME_DIR bij standaard-pad; de core lost dan de
            # script-default op. stored_dir mag NIET terugvallen naar
            # een oude conf-waarde die we zojuist verwijderden.
        self._dir_edits.pop(game.key, None)
        save_paths(paths)
        run = GameRun(game, self._run_status_changed, self._run_output,
                      extra_env=extra_env,
                      banner=f"== {game.display_name} — installatie wordt uitgevoerd ==")
        self.runs[game.key] = run
        self._add_run_tab(run)
        self._focus_run(run)
        run.start()

    def _run_status_changed(self, run):
        tab_idx = self._tab_index_for(run.game.key)
        if tab_idx >= 0:
            self.run_tabs.setTabText(tab_idx, f"{run.game.display_name}  —  {run.status}")

    def _run_output(self, run):
        if self.current_run is run:
            self._append_terminal(run.log[-1] if run.log else "")

    def _add_run_tab(self, run):
        idx = self.run_tabs.addTab(f"{run.game.display_name}  —  Starten...")
        self.run_tabs.setTabData(idx, run.game.key)
        self.run_tabs.setCurrentIndex(idx)
        if self.run_tabs.count() > 1:
            self.run_tabs.show()

    def _tab_index_for(self, game_key):
        for i in range(self.run_tabs.count()):
            if self.run_tabs.tabData(i) == game_key:
                return i
        return -1

    def _focus_run(self, run):
        self.current_run = run
        idx = self._tab_index_for(run.game.key)
        if idx >= 0:
            self.run_tabs.setCurrentIndex(idx)
        self.terminal.clear()
        self.terminal.setPlainText("\n".join(run.log))

    def _on_tab_changed(self, idx):
        if idx < 0:
            return
        key = self.run_tabs.tabData(idx)
        run = self.runs.get(key)
        if run:
            self._focus_run(run)

    def _close_run_tab(self, idx):
        key = self.run_tabs.tabData(idx)
        run = self.runs.get(key)
        if run and run.proc is not None and run.proc.state() != QProcess.NotRunning:
            run.stop()
        self.run_tabs.removeTab(idx)
        if self.run_tabs.count() <= 1:
            self.run_tabs.hide()
        if self.current_run and self.current_run.game.key == key:
            self.current_run = None
            self.terminal.clear()
            self._welcome()
        elif self.runs:
            self._focus_run(next(iter(self.runs.values())))

    def closeEvent(self, event):
        running = [r for r in self.runs.values()
                   if r.proc is not None and r.proc.state() != QProcess.NotRunning]
        if running:
            names = ", ".join(r.game.display_name for r in running)
            from PySide6.QtWidgets import QMessageBox
            answer = QMessageBox.question(
                self, "Game Launcher",
                f"Er draait nog een game ({names}).\nAfsluiten stopt die game. Toch afsluiten?",
                QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
            if answer != QMessageBox.Yes:
                event.ignore()
                return
            for r in running:
                r.stop()
        event.accept()

    def _append_terminal(self, line):
        self.terminal.appendPlainText(line)
        sb = self.terminal.verticalScrollBar()
        sb.setValue(sb.maximum())


def scan_games():
    games = []
    if LAUNCHERS_DIR.exists():
        for f in sorted(LAUNCHERS_DIR.glob("*.sh")):
            if ".notworking" in f.name:
                continue
            games.append(Game(f.name[:-3], f))
    return games


def _ensure_desktop_icon():
    """Zet bij de eerste start het Game Launcher-icoon op het bureaublad.

    Bestaat ~/Desktop/GameLauncher.desktop al, dan blijft die ongemoeid
    (idempotent). Anders maken, inclusief chmod +x zodat KDE/GNOME de
    shortcut direct klikbaar toont zonder uitroepteken-dialog.
    """
    desktop_dir = Path.home() / "Desktop"
    if not desktop_dir.is_dir():
        return
    target = desktop_dir / "GameLauncher.desktop"
    if target.exists():
        return
    icon = BASE / "gamelauncherv1.png"
    icon_line = str(icon) if icon.exists() else "preferences-desktop-gaming"
    content = (
        "[Desktop Entry]\n"
        "Type=Application\n"
        "Name=Game Launcher\n"
        "Comment=Start games via de launcher-GUI\n"
        f"Exec=python3 {BASE / 'game-gui.py'}\n"
        f"Icon={icon_line}\n"
        "Terminal=false\n"
        "Categories=Game;\n"
        "StartupNotify=true\n"
    )
    target.write_text(content, encoding="utf-8")
    target.chmod(0o755)


def main():
    app = QApplication.instance() or QApplication([])
    app.setApplicationName("Game Launcher")
    _ensure_desktop_icon()
    games = scan_games()
    window = MainWindow(games)
    if not games:
        from PySide6.QtWidgets import QMessageBox
        QMessageBox.warning(window, "Game Launcher",
                            f"Geen launcher-scripts gevonden in:\n{LAUNCHERS_DIR}")
    window.show()
    app.exec()


if __name__ == "__main__":
    main()