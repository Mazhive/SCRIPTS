#!/bin/bash
# ori-blindforest.sh — Ori and the Blind Forest (origineel, CODEX-repack) via Proton-runner.
#
# CODEX-emu (codex.ini → appid 261570; steam_api.dll/.cdx + dinput8.dll als
# loader-proxy) in de gamemap → de game draait standalone. 32-bit PE32
# "ori.exe" (Unity 5, Mono in ori_Data/Mono). Renderer DirectX 11; de
# aanwezige ori_d3d11.log toont "Exclusive FS: 1" → gamescope-wrap nodig.
# Saves: AppData\Roaming\Steam\CODEX\261570\remote (prefix-lokaal).
# Input: Default "Enable SDL=0" (drift-guard) is hier EXTRA belangrijk — BF
# leest ook DirectInput en gaat gek doen ("constantly moving left") zodra
# winebus een joystick ziet (bv. de Wacom-js). Dus: geen padmodus voor BF
# via SDL; een echte XInput-pad heeft de root-route nodig (pad-xinput-on.sh).

export GAME_NAME="OriBlindForest"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/WINDOWSGAMES/Ori_atbf"
export GAME_EXE="$GAME_DIR/ori.exe"
export PREFIX_ARCH="win64"
export SCRIPT_VERSION="1"
export CREATE_DESKTOP_SHORTCUT="1"
export GAME_LAUNCHER="$(readlink -f "$0")"
export PROTON_ENABLED="1"
# Echte Steam-appid van het ORIGINELE Blind Forest (matcht codex.ini's
# CODEX 261570); nodig zodat ProtonFixes de game kan herkennen.
export STEAM_APPID="261570"
# Bewezen werkend voor deze gameset; als deze ontbreekt valt _detect_proton
# terug op de hoogste GE-Proton / Steam-Proton / umu-run.
export PROTON_PIN="GE-Proton11-7"
# Zorg dat de host-tool gamescope er is (Wayland-wrap). Skips als al aanwezig;
# anders installatie via pakketbeheerder (sudo/pkexec); kan dat niet → melding
# en de game draait gewoon zonder wrap. Hook-wijzigingen triggeren géén
# re-provision (de marker vergelijkt alleen SCRIPT_VERSION).
# Geen 'export': PROVISION_HOOKS mag een array zijn, en bash-arrays
# overleven export niet naar subprocessen. Dat is hier geen probleem: dit
# script sourcet game-common.sh (game_init leest de array in dit proces).
PROVISION_HOOKS=(install_gamescope)
# v1: gamescope-wrap voor Wayland (zie exclusieve-FS-bewijs hierboven).
#     Resolutie: uit → core auto-detect (xrandr); pin optioneel.
export GAME_GAMESCOPE="1"

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../game-core/game-common.sh"
game_main "$@"