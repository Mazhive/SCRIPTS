#!/bin/bash
# shadwen.sh — Shadwen (native Linux-game).
export GAME_NAME="Shadwen"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/Native/Shadwen_Escape_From_The_Castle_Linux-ACTiVATED"
export GAME_NATIVE="1"
export GAME_NATIVE_SHELL="bash"
export GAME_NATIVE_CMD="shadwen.sh"
export GAME_LAUNCHER="$(readlink -f "$0")"
export CREATE_DESKTOP_SHORTCUT="1"
source "$(dirname "${BASH_SOURCE[0]}")/../game-core/game-common.sh"
game_main "$@"