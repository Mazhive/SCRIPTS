#!/bin/bash
# citiesskylines.sh — Cities: Skylines (non-Steam, R.G. Mechanics repack) via Proton-runner.
#
# De game is de non-Steam-map (1.11.1-f2, MEX-crack, AllDLC, DX11/Unity Mono).
# Lokale, VERSE prefix (wineboot -i) — geen kopie van een bestaande prefix.
# We starten via de Proton-runner (net als Cyberpunk 2077), ZONDER de Steam-client;
# Proton richt de verse prefix zelf in (dxvk/dxgi voor DX11).

export GAME_NAME="CitiesSkylines"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/WINDOWSGAMES/Cities-Skylines-none-Steam"
export GAME_EXE="$GAME_DIR/Cities.exe"
export PREFIX_ARCH="win64"
export SCRIPT_VERSION="2"
export CREATE_DESKTOP_SHORTCUT="1"
export GAME_LAUNCHER="$(readlink -f "$0")"
export PROTON_ENABLED="1"
# Echte Steam-appid van Cities: Skylines (matcht MEX.ini's SteamAppId=255710);
# nodig zodat ProtonFixes de game kan herkennen (regex op cijfers in
# STEAM_COMPAT_DATA_PATH, crasht anders met IndexError bij een gamenaam
# zonder cijfers).
export STEAM_APPID="255710"
# Bewezen werkend voor deze gameset; als deze ontbreekt valt _detect_proton
# terug op de hoogste GE-Proton / Steam-Proton / umu-run.
export PROTON_PIN="GE-Proton11-7"
# Geen 'export': PROVISION_HOOKS mag een array zijn, en bash-arrays
# overleven export niet naar subprocessen. Dat is hier geen probleem: dit
# script sourcet game-common.sh (game_init leest de array in dit proces).
PROVISION_HOOKS=()

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../game-core/game-common.sh"
game_main "$@"