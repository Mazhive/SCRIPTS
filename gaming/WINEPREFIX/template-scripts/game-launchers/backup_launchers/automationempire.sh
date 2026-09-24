#!/bin/bash
# Automation Empire (CODEX) — Plain Wine launcher
# Unity 5.6.5f1 game, CODEX Steam emulator, Steam appid 1112790
# Werkt met kale Wine prefix - geen hooks, geen libs, geen vcrun/d3dx9

set -euo pipefail

# --- Basisinstellingen ---
export GAME_NAME="AutomationEmpire"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/WINDOWSGAMES/Automation.Empire"
export GAME_EXE="$GAME_DIR/AutomationEmpire.exe"
export PREFIX_DIR="/home/peter/GAMEPREFIXES/AutomationEmpire"
export WINEPREFIX="$PREFIX_DIR"
export STEAM_APPID="1112790"

# --- Plain Wine configuratie ---
export WINEDEBUG="-all"
export WINEDLLOVERRIDES="steam_api64=n,builtin;codex64=n,builtin;GameOverlayRenderer64=n,builtin;steamclient64=n,builtin"

# --- Maak/initialiseer prefix (alleen winecfg win10) ---
if [ ! -d "$PREFIX_DIR" ]; then
    echo "[game] Nieuwe prefix aanmaken..."
    mkdir -p "$PREFIX_DIR"
    env WINEPREFIX="$PREFIX_DIR" wine64 wineboot -u 2>/dev/null
    # Windows 10 instellen
    env WINEPREFIX="$PREFIX_DIR" wine64 winecfg -v win10 2>/dev/null
    echo "[game] Prefix klaar (Windows 10, standaard Wine cfg)"
fi

# --- Launch game ---
echo "[game] Starten: $GAME_EXE"
exec env WINEPREFIX="$PREFIX_DIR" wine64 "$GAME_EXE"