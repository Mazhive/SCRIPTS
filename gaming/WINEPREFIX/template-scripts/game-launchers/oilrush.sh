#!/bin/bash
# oilrush.sh — Oil Rush (native Linux-game).
export GAME_NAME="OilRush"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/Native/OILRUSH/OilRush-1.35"
export GAME_NATIVE="1"
export GAME_NATIVE_SHELL="bash"
export GAME_NATIVE_CMD="launcher.sh"
export GAME_LAUNCHER="$(readlink -f "$0")"
export CREATE_DESKTOP_SHORTCUT="1"
source "$(dirname "${BASH_SOURCE[0]}")/../game-core/game-common.sh"
game_main "$@"