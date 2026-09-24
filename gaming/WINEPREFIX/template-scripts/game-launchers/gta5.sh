#!/bin/bash
# GTA V (Build 2802, Online, Goldberg Emu) — Proton launcher via game-common.sh
# Let op: deze repack gebruikt Goldberg Steam emulator → GEEN gamescope!

set -euo pipefail

# --- Basisinstellingen (ALLE exports VOOR sourcing game-common.sh) ---
export GAME_NAME="GTA5"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/GAMES/GAMES/WINDOWS/GTA V Build 2802-Online 1_64 met alle DLC_s - Werkt OK"
export GAME_EXE="$GAME_DIR/GTA5.exe"
export PREFIX_ARCH="win64"
export SCRIPT_VERSION="1"
export CREATE_DESKTOP_SHORTCUT="1"
export GAME_LAUNCHER="$(readlink -f "$0")"

# --- Proton / Wine configuratie ---
export PROTON_ENABLED="1"
export PROTON_PIN="GE-Proton11-7"
export STEAM_APPID="271590"              # GTA V Steam appid (voor ProtonFixes + Goldberg)

# VC++ 2019 runtime via winetricks (geen _CommonRedist in deze game-map)
export VC_RUNTIME_METHOD="winetricks"

# DirectX 11 via DXVK (in GE-Proton ingebouwd)
export DXVK_HUD="fps,msgs"
export VKD3D_SHADER_CACHE_SIZE="4"
export WINEDEBUG="-all"

# GEEN gamescope! → conflicteert met Goldberg Steam emulator (Steam API init)
# export GAME_GAMESCOPE="1"

# --- Provision hooks (bij eerste run: prefix setup) ---
# install_vcrun2019: VC++ 2019 runtime (noodzakelijk voor GTA V)
PROVISION_HOOKS=("install_vcrun2019")

# Pre-launch hooks (bij ELKE start vóór game launch)
# disable_winebus: zet winebus Enable SDL=0 (hidraw aan) → toetsenbord werkt
PRE_LAUNCH_HOOKS=("disable_winebus")

# --- Core laden EN pas daarna game_main aanroepen ---
source "$(dirname "$(readlink -f "$0")")/../game-core/game-common.sh"

# Start de game
game_main "$@"