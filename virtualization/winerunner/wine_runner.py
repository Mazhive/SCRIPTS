import sys
import os
import subprocess
import getpass
import requests
from PyQt6.QtWidgets import (QApplication, QWidget, QVBoxLayout, QLabel,  
                             QLineEdit, QPushButton, QFileDialog, QMessageBox, QHBoxLayout)
from PyQt6.QtCore import Qt, QUrl, QTimer

USER = getpass.getuser()

class WineRunnerManager(QWidget):
    def __init__(self):
        super().__init__()
        self.game_mode = "64" # Standaard modern
        self.initUI()
        
        self.search_timer = QTimer()
        self.search_timer.setSingleShot(True)
        self.search_timer.timeout.connect(self.check_proton_status)

    def initUI(self):
        self.setWindowTitle("Peter's AI-Powered WineRunner")
        self.setFixedSize(500, 480)
        
        layout = QVBoxLayout()
        header = QLabel("WINERUNNER INTELLIGENT INSTALLER")
        header.setStyleSheet("font-size: 18px; font-weight: bold; color: #2c3e50;")
        header.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(header)

        self.entry_name = QLineEdit()
        self.entry_name.setPlaceholderText("Bijv. Command & Conquer of Halo")
        self.entry_name.textChanged.connect(self.start_search_timer)
        layout.addWidget(QLabel("<b>Game Naam:</b>"))
        layout.addWidget(self.entry_name)

        # Compatibiliteit & Advies Display
        self.comp_layout = QHBoxLayout()
        self.comp_icon = QLabel("⚪")
        self.comp_text = QLabel("Wachten op invoer...")
        self.comp_layout.addWidget(self.comp_icon)
        self.comp_layout.addWidget(self.comp_text)
        layout.addLayout(self.comp_layout)

        self.advies_lbl = QLabel("")
        self.advies_lbl.setStyleSheet("color: #2980b9; font-style: italic; font-size: 11px;")
        layout.addWidget(self.advies_lbl)

        layout.addSpacing(10)

        self.btn_run = QPushButton("🚀 START INTELLIGENTE SETUP")
        self.btn_run.setMinimumHeight(70)
        self.btn_run.setStyleSheet("background-color: #27ae60; color: white; font-weight: bold; border-radius: 10px;")
        self.btn_run.clicked.connect(self.run_procedure)
        layout.addWidget(self.btn_run)

        self.status = QLabel("Status: Idle")
        self.status.setWordWrap(True)
        layout.addWidget(self.status)

        self.setLayout(layout)

    def start_search_timer(self):
        self.search_timer.start(500)

    def check_proton_status(self):
        query = self.entry_name.text().strip()
        if len(query) < 3: return

        try:
            search_url = f"https://store.steampowered.com/api/storesearch/?term={query}&l=english&cc=US"
            r = requests.get(search_url, timeout=5).json()

            if r.get('total', 0) > 0:
                game = r['items'][0]
                appid = game['id']
                game_name = game['name']

                pdb_url = f"https://www.protondb.com/api/v1/reports/summaries/{appid}.json"
                pdb_r = requests.get(pdb_url, timeout=5).json()
                tier = pdb_r.get('tier', 'unknown')

                # Intelligentie: Is het een oude game?
                legacy_keywords = ["conquer", "red alert", "halo", "doom", "quake", "age of empires"]
                is_legacy = any(k in game_name.lower() for k in legacy_keywords)
                
                if is_legacy:
                    self.game_mode = "32"
                    advies = "💡 Gedetecteerd als LEGACY. Ik ga een 32-bit prefix maken (bespaart ruimte & stabieler)."
                else:
                    self.game_mode = "64"
                    advies = "🚀 Gedetecteerd als MODERN. Ik gebruik een 64/32-bit combo prefix."

                self.update_ui(tier, game_name, advies)
            else:
                self.comp_icon.setText("❓")
                self.comp_text.setText("Niet gevonden in Steam DB.")
        except: pass

    def update_ui(self, tier, name, advies):
        icons = {"platinum": "💎", "gold": "🥇", "silver": "🥈", "bronze": "🥉", "broken": "🚫"}
        self.comp_icon.setText(icons.get(tier, "⚪"))
        self.comp_text.setText(f"<b>{name}</b> ({tier.upper()})")
        self.advies_lbl.setText(advies)

    def setup_prefix(self, path):
        """Maakt de prefix aan op basis van de gedetecteerde modus."""
        env = os.environ.copy()
        arch = "win32" if self.game_mode == "32" else "win64"
        env["WINEPREFIX"] = path
        env["WINEARCH"] = arch

        self.set_status(f"🛠️ Bouwen van {arch} prefix... even geduld.", "#e67e22")
        
        # Initialisatie
        subprocess.run(["wineboot", "-u"], env=env)

        # Libraries toevoegen op basis van modus
        if self.game_mode == "32":
            # Voor oude games vaak d3dx9 en directplay nodig
            subprocess.run(["winetricks", "-q", "d3dx9", "directplay"], env=env)
        else:
            # Voor moderne games DXVK
            subprocess.run(["winetricks", "-q", "dxvk"], env=env)

    def create_runner_script(self, game_dir, game_name, exe_path):
        script_path = os.path.join(game_dir, "linux.game.sh")
        arch = "win32" if self.game_mode == "32" else "win64"
        
        content = f"""#!/bin/bash
# WINERUNNER AUTO-GENERATED
GAME_PATH="$(dirname "$(readlink -f "$0")")"
export WINEPREFIX="$HOME/WINEPREFIXES/{game_name}"
export WINEARCH="{arch}"

cd "$GAME_PATH"

if [ ! -d "$WINEPREFIX" ]; then
    echo "⚠️ Prefix ontbreekt. Automatisch herstellen als $WINEARCH..."
    mkdir -p "$HOME/WINEPREFIXES"
    wineboot -u
    # Fail-safe libs
    if [ "$WINEARCH" == "win32" ]; then
        winetricks -q d3dx9 directplay
    else
        winetricks -q dxvk
    fi
fi

wine64 "./{os.path.basename(exe_path)}" 2>/dev/null || wine "./{os.path.basename(exe_path)}"
"""
        with open(script_path, "w") as f: f.write(content)
        os.chmod(script_path, 0o755)
        return script_path

    def run_procedure(self):
        input_name = self.entry_name.text().strip().replace(" ", ".")
        if not input_name: return
        
        prefix_path = os.path.expanduser(f"~/WINEPREFIXES/{input_name}")
        
        dialog = QFileDialog(self)
        dialog.setDirectory("/mnt/")
        if dialog.exec():
            installer = dialog.selectedFiles()[0]
            if not os.path.exists(prefix_path): os.makedirs(prefix_path)
            
            self.setup_prefix(prefix_path)
            
            # Start Installer
            env = os.environ.copy()
            env["WINEPREFIX"] = prefix_path
            env["WINEARCH"] = "win32" if self.game_mode == "32" else "win64"
            
            self.set_status("🎮 Installer is actief...", "#2980b9")
            subprocess.run(["wine", installer], env=env)
            
            QMessageBox.information(self, "Stap 2", "Selecteer nu de geïnstalleerde EXE op de share.")
            if dialog.exec():
                game_exe = dialog.selectedFiles()[0]
                self.create_runner_script(os.path.dirname(game_exe), input_name, game_exe)
                self.set_status("✨ Intelligent Setup Voltooid!", "#27ae60", True)

    def set_status(self, text, color="#7f8c8d", bold=False):
        self.status.setText(text)
        self.status.setStyleSheet(f"color: {color}; font-weight: {'bold' if bold else 'normal'};")
        QApplication.processEvents()

if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    ex = WineRunnerManager()
    ex.show()
    sys.exit(app.exec())
