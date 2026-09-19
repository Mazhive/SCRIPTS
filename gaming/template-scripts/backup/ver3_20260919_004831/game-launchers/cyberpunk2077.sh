#!/bin/bash
# cyberpunk2077.sh — Cyberpunk 2077 via Proton-runner (non-Steam game).
#
# Lokale, VERSE prefix (wineboot -i) — geen kopie van een bestaande prefix.
# De game is als non-Steam game aan Steam toegevoegd; Proton lanceert
# de exe standalone met eigen wine/vkd3d/dxgi/ntsync en richt de verse
# prefix zelf in ("Upgrading prefix from None to <versie>"). Wine-only
# start crasht in de renderer-init; via `proton waitforexitandrun` werkt het.

export GAME_NAME="Cyberpunk2077"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/WINDOWSGAMES/Cyberpunk 2077/Cyberpunk 2077"
export GAME_EXE="$GAME_DIR/bin/x64/Cyberpunk2077.exe"
export PREFIX_ARCH="win64"
export CREATE_DESKTOP_SHORTCUT="1"
export GAME_LAUNCHER="$(readlink -f "$0")"
export DISABLE_ESYNC=0
export PROTON_ENABLED="1"
# Echte Steam-appid van Cyberpunk 2077; nodig zodat ProtonFixes de game kan
# herkennen (regex op cijfers in STEAM_COMPAT_DATA_PATH). "2077" in de
# gamenaam liet dit toevallig al werken, maar dit is de correcte, expliciete
# manier (en onafhankelijk van hoe GAME_NAME toevallig heet).
export STEAM_APPID="1091500"
# SCRIPT_VERSION verhoogd zodat bestaande prefixen met de oude
# compatdata-structuur (zonder appid-submap) opnieuw geprovisiond worden.
# v9: deterministische VC-runtime-hook (_install_vcrun2019 valideert/
#     herstelt msvcp140.dll op x86_64 i.p.v. blind winetricks) — bestaande
#     prefixes moeten daarom opnieuw provisionen.
export SCRIPT_VERSION="9"
# Bewezen werkend voor deze game; als deze ontbreekt valt _detect_proton
# terug op de hoogste GE-Proton / Steam-Proton / umu-run.
export PROTON_PIN="GE-Proton11-7"
# Geen 'export': PROVISION_HOOKS mag een array zijn, en bash-arrays
# overleven export niet naar subprocessen. Dat is hier geen probleem: dit
# script sourcet game-common.sh (game_init leest de array in dit proces).
PROVISION_HOOKS=("install_vcrun2019")

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../game-core/game-common.sh"
game_main "$@"