#!/bin/bash
# astroidbountyhunter.sh — Asteroid Bounty Hunter (native Linux-game).
export GAME_NAME="AstroidBountyHunter"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/Native/Asteroid.Bounty.Hunter"
export GAME_NATIVE="1"
export GAME_NATIVE_CMD="AsteroidBountyHunter.x86_64"
export GAME_LAUNCHER="$(readlink -f "$0")"
export CREATE_DESKTOP_SHORTCUT="1"
source "$(dirname "${BASH_SOURCE[0]}")/../game-core/game-common.sh"
game_main "$@"