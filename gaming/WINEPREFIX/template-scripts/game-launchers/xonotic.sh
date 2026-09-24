#!/bin/bash
# xonotic.sh — Xonotic (native Linux-game).
export GAME_NAME="Xonotic"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/Native/Xonotic"
export GAME_NATIVE="1"
export GAME_NATIVE_SHELL="bash"
export GAME_NATIVE_CMD="xonotic-linux-sdl.sh"
# NVIDIA/hybride-GPU + Wayland: SDL2-fullscreen geeft daar vaak zwart beeld
# met audio → dwing GLX via XWayland af (zie game-core/README.native-opties.md).
export GAME_NATIVE_SDL_DRIVER="x11"
# Fallback bij nog steeds zwart beeld (andere PC, KWin Wayland):
#   export GAME_NATIVE_EXTRA_ARGS="+vid_fullscreen 0"   # windowed
#   export GAME_GAMESCOPE="1"                            # nested compositor
export GAME_LAUNCHER="$(readlink -f "$0")"
export CREATE_DESKTOP_SHORTCUT="1"
source "$(dirname "${BASH_SOURCE[0]}")/../game-core/game-common.sh"
game_main "$@"