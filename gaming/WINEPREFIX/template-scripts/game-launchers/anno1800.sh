#!/bin/bash
# Anno 1800 (ElAmigos/Empress crack) — Proton launcher via game-common.sh core
# DirectX 11/12 game, Empress Uplay emulator, requires GE-Proton

set -euo pipefail

# --- Basisinstellingen (ALLE exports VOOR sourcing game-common.sh) ---
export GAME_NAME="Anno1800"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/WINDOWSGAMES/Anno.1800"
export GAME_EXE="$GAME_DIR/Bin/Win64/Anno1800.exe"
export PREFIX_ARCH="win64"
export SCRIPT_VERSION="1"
export CREATE_DESKTOP_SHORTCUT="1"
export GAME_LAUNCHER="$(readlink -f "$0")"

# --- Proton / Wine configuratie ---
export PROTON_ENABLED="1"
export PROTON_PIN="GE-Proton11-7"
export STEAM_APPID="1206580"               # Anno 1800 Steam appid (voor ProtonFixes)

# VC++ 2019 runtime via winetricks (game bevat geen _CommonRedist)
export VC_RUNTIME_METHOD="winetricks"

# DirectX 11/12 via DXVK/VKD3D (in GE-Proton ingebouwd)
export DXVK_HUD="fps,msgs"
export VKD3D_SHADER_CACHE_SIZE="4"
export WINEDEBUG="-all"

# Gamescope wrap voor AMD/Wayland (lost exclusive-FS focus-stall op)
export GAME_GAMESCOPE="1"

# --- Provision hooks (bij eerste run: prefix setup) ---
# install_vcrun2019: VC++ 2019 runtime (noodzakelijk)
# install_gamescope: gamescope installatie voor Wayland fix
PROVISION_HOOKS=("install_vcrun2019" "install_gamescope")

# Pre-launch hooks (bij ELKE start vóór game launch)
# disable_winebus: zet winebus Enable SDL=0 (hidraw aan) → toetsenbord werkt
PRE_LAUNCH_HOOKS=("disable_winebus")

# --- Core laden EN pas daarna game_main aanroepen ---
source "$(dirname "$(readlink -f "$0")")/../game-core/game-common.sh"

# Start de game
game_main "$@"