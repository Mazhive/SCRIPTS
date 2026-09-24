#!/bin/bash
# ut2004.sh — Unreal Tournament 2004 (native Linux-game).
export GAME_NAME="UT2004"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/Native/UT2004"
export GAME_NATIVE="1"
export GAME_NATIVE_SHELL="bash"
export GAME_NATIVE_CMD="ut2004"
export GAME_LAUNCHER="$(readlink -f "$0")"
export CREATE_DESKTOP_SHORTCUT="1"
source "$(dirname "${BASH_SOURCE[0]}")/../game-core/game-common.sh"
game_main "$@"