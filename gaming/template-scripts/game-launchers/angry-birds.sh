#!/bin/bash
# Angry Birds — dun per-game launcher.
# Zie game-core/game-common.sh voor de logica; hier staat alleen de config.
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../game-core/game-common.sh"

export GAME_NAME="AngryBirds"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/WINDOWSGAMES/Angrybirds"
export GAME_EXE="$GAME_DIR/AngryBirds.exe"
export PREFIX_ARCH="win64"
export SCRIPT_VERSION="1"
export CREATE_DESKTOP_SHORTCUT="1"
export GAME_LAUNCHER="$(readlink -f "$0")"

game_main "$@"