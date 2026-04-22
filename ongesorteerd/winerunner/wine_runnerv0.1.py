import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import os
import subprocess
import getpass

# Haal de huidige gebruikersnaam op voor de /run/media/ paden
USER = getpass.getuser()

def create_runner_script(game_dir, prefix_path, exe_path):
    script_path = os.path.join(game_dir, "linux.game.sh")
    exe_name = os.path.basename(exe_path)
    content = f"""#!/bin/bash
# Automatisch gegenereerd opstartscript
GAME_PATH="$(dirname "$(readlink -f "$0")")"
export WINEPREFIX="{prefix_path}"

cd "$GAME_PATH"
# Controleer of de prefix lokaal bestaat, anders aanmaken
if [ ! -d "$WINEPREFIX" ]; then
    echo "Prefix niet gevonden. Bezig met aanmaken in $WINEPREFIX..."
    wineboot -u
fi

wine64 "./{exe_name}"
"""
    try:
        with open(script_path, "w") as f:
            f.write(content)
        os.chmod(script_path, 0o755)
        return script_path
    except Exception as e:
        messagebox.showerror("Fout", f"Kon script niet opslaan op NFS. Rechten probleem?\n{e}")
        return None

def get_file_path(title):
    # Een popup om te kiezen uit welke hoofdmap we willen starten
    chooser = tk.Toplevel()
    chooser.title("Kies bronlocatie")
    chooser.geometry("300x250")
    chooser.transient(root)
    chooser.grab_set()

    selected_path = tk.StringVar()

    def set_and_close(path):
        res = filedialog.askopenfilename(initialdir=path, title=title, 
                                        filetypes=[("Windows Executable", "*.exe")])
        if res:
            selected_path.set(res)
            chooser.destroy()

    ttk.Label(chooser, text="Waar staat de installer/game?", font=("Arial", 10, "bold")).pack(pady=10)
    
    # Knoppen voor de verschillende mount-locaties
    ttk.Button(chooser, text="NFS / HDD (/mnt)", command=lambda: set_and_close("/mnt/")).pack(pady=5, fill="x", padx=20)
    
    media_path = f"/run/media/{USER}/"
    if os.path.exists(media_path):
        ttk.Button(chooser, text=f"USB / ISO ({media_path})", command=lambda: set_and_close(media_path)).pack(pady=5, fill="x", padx=20)
    
    ttk.Button(chooser, text="Persoonlijke map (~/)", command=lambda: set_and_close(os.path.expanduser("~"))).pack(pady=5, fill="x", padx=20)
    ttk.Button(chooser, text="Annuleren", command=chooser.destroy).pack(pady=10)

    root.wait_window(chooser)
    return selected_path.get()

def run_procedure():
    game_name = entry_name.get().strip().replace(" ", ".")
    if not game_name or game_name == "Game.Naam.Hier":
        messagebox.showerror("Fout", "Voer eerst een geldige gamenaam in.")
        return

    # Prefix Setup
    base_prefix_dir = os.path.expanduser("~/WINEPREFIXES")
    game_prefix_path = os.path.join(base_prefix_dir, game_name)
    
    if not os.path.exists(game_prefix_path):
        os.makedirs(game_prefix_path)

    # Stap 1: Installer zoeken
    installer_exe = get_file_path("Selecteer de Installer EXE")
    if not installer_exe: return

    # Stap 2: Installatie
    env = os.environ.copy()
    env["WINEPREFIX"] = game_prefix_path
    messagebox.showinfo("Installatie", "Wine opent nu de installer.\n\nINSTALLATIE-TIP: Installeer naar de Z: schijf (je NFS share)!")
    
    try:
        subprocess.run(["wine64", installer_exe], env=env)
        
        # Stap 3: Runner maken
        messagebox.showinfo("Laatste stap", "Selecteer nu de geïnstalleerde .exe op de NFS om de runner te genereren.")
        game_exe = get_file_path("Selecteer de geinstalleerde Game EXE")
        
        if game_exe:
            game_dir = os.path.dirname(game_exe)
            runner = create_runner_script(game_dir, game_prefix_path, game_exe)
            if runner:
                messagebox.showinfo("Succes", f"Klaar!\n\nPrefix: {game_prefix_path}\nRunner aangemaakt op NFS.")
    except Exception as e:
        messagebox.showerror("Fout", f"Er ging iets mis: {e}")

# --- Hoofdscherm ---
root = tk.Tk()
root.title("Peter's Wine Portable Manager")
root.geometry("400x220")

style = ttk.Style()
style.theme_use('clam')

frame = ttk.Frame(root, padding="20")
frame.pack(expand=True, fill="both")

ttk.Label(frame, text="Naam van de game:", font=("Arial", 10, "bold")).pack(anchor="w")
entry_name = ttk.Entry(frame, width=40)
entry_name.pack(pady=5, fill="x")
entry_name.insert(0, "Game.Naam.Hier")

btn_start = ttk.Button(frame, text="🚀 Start Procedure", command=run_procedure)
btn_start.pack(pady=20, fill="x")

root.mainloop()
