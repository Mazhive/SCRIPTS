#!/bin/bash
# Automation Empire (CODEX) — Plain Wine launcher
# Unity 5.6.5f1 game, CODEX Steam emulator, Steam appid 1112790
# Werkt met kale Wine prefix - geen hooks, geen libs, geen vcrun/d3dx9
#
# Eigen bewezen prefix-pad (WINEPREFIX direct op PREFIX_DIR, géén /pfx-submap),
# daarom géén game_main: alleen de core-helpers worden gebruikt (desktop-file +
# gamescope-lijst), de launch zelf is de oorspronkelijke wine64-aanroep.

# --- Basisinstellingen (voor de core-helpers) ---
export GAME_NAME="AutomationEmpire"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/WINDOWSGAMES/Automation.Empire"
export GAME_EXE="$GAME_DIR/AutomationEmpire.exe"
export PREFIX_DIR="/home/peter/GAMEPREFIXES/AutomationEmpire"
export WINEPREFIX="$PREFIX_DIR"
export STEAM_APPID="1112790"
export GAME_LAUNCHER="$(readlink -f "$0")"
export CREATE_DESKTOP_SHORTCUT="1"

# --- Core laden (game_make_desktop + gamescope-helper) ---
source "$(dirname "${BASH_SOURCE[0]}")/../game-core/game-common.sh"

# --- SDL3 dynapi-protectie (zelfde regel als via game_launch bij core-games) ---
_neutralize_sdl3_dynapi

# --- Desktop-shortcut (GUI-checkbox GUI_DESKTOP_SHORTCUT wordt gerespecteerd) ---
game_make_desktop

# --- Maak/initialiseer prefix (alleen winecfg win10) ---
if [ ! -d "$PREFIX_DIR" ]; then
    echo "[game] Nieuwe prefix aanmaken..."
    mkdir -p "$PREFIX_DIR"
    env WINEPREFIX="$PREFIX_DIR" wine64 wineboot -u 2>/dev/null
    # Windows 10 instellen
    env WINEPREFIX="$PREFIX_DIR" wine64 winecfg -v win10 2>/dev/null
    echo "[game] Prefix klaar (Windows 10, standaard Wine cfg)"
fi

# --- Launch game (met gamescope-wrap indien gewenst/actief) ---
echo "[game] Starten: $GAME_EXE"
_gscope_argv
exec env WINEPREFIX="$PREFIX_DIR" "${GSCOPE_ARGV[@]}" wine64 "$GAME_EXE"