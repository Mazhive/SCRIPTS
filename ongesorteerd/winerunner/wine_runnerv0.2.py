import sys
import os
import subprocess
import getpass
from PyQt6.QtWidgets import (QApplication, QWidget, QVBoxLayout, QLabel, 
                             QLineEdit, QPushButton, QFileDialog, QMessageBox)
from PyQt6.QtCore import Qt, QUrl

# Gebruikersnaam voor paden en media
USER = getpass.getuser()

class WineManager(QWidget):
    def __init__(self):
        super().__init__()
        self.initUI()

    def initUI(self):
        self.setWindowTitle("Peter's Wine Portable Manager - DXVK Edition")
        self.setFixedSize(500, 350)
        
        layout = QVBoxLayout()

        # Header
        header = QLabel("PORTABLE WINE INSTALLER")
        header.setStyleSheet("font-size: 20px; font-weight: bold; margin-bottom: 15px; color: #2c3e50;")
        header.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(header)

        # Input sectie
        lbl_name = QLabel("Naam van de game (voor de lokale prefix):")
        lbl_name.setStyleSheet("font-weight: bold;")
        layout.addWidget(lbl_name)
        
        self.entry_name = QLineEdit()
        self.entry_name.setPlaceholderText("Bijv: Automation.Empire")
        self.entry_name.setStyleSheet("padding: 8px; font-size: 13px;")
        layout.addWidget(self.entry_name)

        layout.addSpacing(20)

        # Hoofdknop
        self.btn_run = QPushButton("🚀 SELECTEER INSTALLER & START")
        self.btn_run.setMinimumHeight(80)
        self.btn_run.setStyleSheet("""
            QPushButton {
                background-color: #2980b9; 
                color: white; 
                font-weight: bold; 
                font-size: 15px; 
                border-radius: 10px;
            }
            QPushButton:hover {
                background-color: #3498db;
            }
        """)
        self.btn_run.clicked.connect(self.run_procedure)
        layout.addWidget(self.btn_run)

        # Status informatie (Kleurrijk)
        self.status = QLabel("Status: Klaar voor start...")
        self.status.setStyleSheet("color: #7f8c8d; font-style: italic; margin-top: 15px; font-size: 12px;")
        self.status.setWordWrap(True)
        layout.addWidget(self.status)

        self.setLayout(layout)

    def set_status(self, text, color="#7f8c8d", bold=False):
        """Hulpmiddel om de statusbalk direct bij te werken."""
        weight = "bold" if bold else "normal"
        self.status.setText(text)
        self.status.setStyleSheet(f"color: {color}; font-weight: {weight}; font-style: italic; margin-top: 15px;")
        QApplication.processEvents() # Forceer GUI update

    def setup_prefix_features(self, prefix_path):
        """Configureert DXVK en Drive Mappings met visuele feedback."""
        self.set_status("🚀 Bezig met DXVK installatie in prefix... even geduld.", "#e67e22", True)
        
        env = os.environ.copy()
        env["WINEPREFIX"] = prefix_path
        
        # 1. DXVK Installeren via winetricks
        try:
            # -q is voor quiet mode
            subprocess.run(["winetricks", "-q", "dxvk"], env=env)
            self.set_status("✅ DXVK succesvol geïnstalleerd.", "#27ae60", True)
        except Exception as e:
            self.set_status(f"❌ DXVK installatie mislukt: {e}", "#c0392b", True)

        # 2. Drive Mappings forceren in dosdevices
        dosdevices = os.path.join(prefix_path, "dosdevices")
        if not os.path.exists(dosdevices):
            os.makedirs(dosdevices)
            
        for link, target in [("d:", "/mnt/"), ("z:", "/")]:
            link_path = os.path.join(dosdevices, link)
            if not os.path.exists(link_path):
                try:
                    os.symlink(target, link_path)
                except: pass # Mocht link al bestaan

    def create_runner(self, game_dir, game_name, exe_path):
        """Maakt de universele runner aan op de Game share."""
        script_path = os.path.join(game_dir, "linux.game.sh")
        exe_name = os.path.basename(exe_path)
        
        content = f"""#!/bin/bash
# Portable Runner
GAME_PATH="$(dirname "$(readlink -f "$0")")"
export WINEPREFIX="$HOME/WINEPREFIXES/{game_name}"

cd "$GAME_PATH"

if [ ! -d "$WINEPREFIX" ]; then
    echo "Nieuwe gebruiker gedetecteerd. Prefix aanmaken + DXVK setup..."
    mkdir -p "$HOME/WINEPREFIXES"
    wineboot -u
    WINEPREFIX="$WINEPREFIX" winetricks -q dxvk
fi

wine64 "./{exe_name}"
"""
        try:
            with open(script_path, "w") as f:
                f.write(content)
            os.chmod(script_path, 0o755)
            return script_path
        except Exception as e:
            QMessageBox.critical(self, "Fout", f"Kon runner niet opslaan: {e}")
            return None

    def run_procedure(self):
        input_name = self.entry_name.text().strip()
        if not input_name:
            QMessageBox.warning(self, "Invoer vereist", "Voer eerst de naam van de game in.")
            return

        game_name = input_name.replace(" ", ".")
        local_prefix_path = os.path.expanduser(f"~/WINEPREFIXES/{game_name}")

        # Stap 1: Selecteer Installer
        dialog = QFileDialog(self)
        dialog.setWindowTitle("Stap 1: Selecteer de Installer EXE")
        dialog.setNameFilter("Windows Executables (*.exe)")
        dialog.setDirectory("/mnt/")
        dialog.setSidebarUrls([QUrl.fromLocalFile("/mnt/"), QUrl.fromLocalFile(f"/run/media/{USER}/")])
        
        if dialog.exec():
            installer_exe = dialog.selectedFiles()[0]
        else:
            return

        # Maak prefix map
        if not os.path.exists(local_prefix_path):
            os.makedirs(local_prefix_path)

        # DXVK en Mappings
        self.setup_prefix_features(local_prefix_path)

        # Start Installer
        QMessageBox.information(self, "Installatie", 
            "DXVK & Schijven (Z: en D:) zijn ingesteld.\n\n"
            "LET OP: Installeer naar de Game share!\n"
            "Als de schijf niet verschijnt, typ handmatig: Z:/mnt/...")
        
        env = os.environ.copy()
        env["WINEPREFIX"] = local_prefix_path
        
        try:
            self.set_status("🎮 Installer is actief... Volg de stappen in de installer.", "#2980b9")
            subprocess.run(["wine64", installer_exe], env=env)

            # Stap 2: Runner maken
            QMessageBox.information(self, "Runner maken", "Installatie klaar. Selecteer nu de geïnstalleerde game file .exe op de Game share.")
            
            dialog.setWindowTitle("Stap 2: Selecteer de geïnstalleerde Game EXE")
            if dialog.exec():
                game_exe = dialog.selectedFiles()[0]
                game_dir = os.path.dirname(game_exe)
                runner_path = self.create_runner(game_dir, game_name, game_exe)
                
                if runner_path:
                    self.set_status("✨ Alles succesvol afgerond!", "#27ae60", True)
                    
                    msg = QMessageBox(self)
                    msg.setWindowTitle("Voltooid")
                    msg.setText("De portable setup is klaar.\n\nAdvies: Gebruik voortaan de 'linux.game.sh' op de Games share.\n\nWil je de game nu direct starten?")
                    msg.setStandardButtons(QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No)
                    
                    if msg.exec() == QMessageBox.StandardButton.Yes:
                        subprocess.Popen(["bash", runner_path], start_new_session=True)
        except Exception as e:
            QMessageBox.critical(self, "Systeem Fout", f"Fout: {e}")
            self.set_status("❌ Er is een fout opgetreden.", "#c0392b")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    ex = WineManager()
    ex.show()
    sys.exit(app.exec())
