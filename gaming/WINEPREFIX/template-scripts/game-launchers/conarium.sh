#!/bin/bash
# Conarium — native Linux-game (wrapper-script).
source "$(dirname "$(readlink -f "$0")")/../game-core/game-conf.sh"
export GAME_NAME="Conarium"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/Native/Conarium"
game_resolve_install_dir
cd "$GAME_DIR" && bash Conarium.sh --gl