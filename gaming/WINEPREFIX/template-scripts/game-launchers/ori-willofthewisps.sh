#!/bin/bash
# ori-willofthewisps.sh — Ori and the Will of the Wisps (non-Steam repack) via Proton-runner.
#
# Ori_atwotw bevat TWEE builds: een UWP/GDK-rommel (appxmanifest, launch-grdk.bat,
# wdapp register — alleen bruikbaar op echte Windows) en de standalone PC-build:
#   oriandthewillofthewisps-pc.exe  +  oriandthewillofthewisps-pc_Data
# Wij starten uitsluitend die PC-build (Logboek: verifieerbare DXVK-run op GT 710).
# Unity IL2CPP (GameAssembly.dll) → geen Mono-laag; géén steam_api/emu-dlls in de
# boom → de repack draait standalone. Saves: AppData\LocalLow\Moon Studios GmbH\...

export GAME_NAME="OriWillOfTheWisps"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/WINDOWSGAMES/Ori_atwotw"
export GAME_EXE="$GAME_DIR/oriandthewillofthewisps-pc.exe"
export PREFIX_ARCH="win64"
export SCRIPT_VERSION="1"
export CREATE_DESKTOP_SHORTCUT="1"
export GAME_LAUNCHER="$(readlink -f "$0")"
export PROTON_ENABLED="1"
# Echte Steam-appid van Ori and the Will of the Wisps (steam_appid.txt in de map);
# nodig zodat ProtonFixes de game kan herkennen.
export STEAM_APPID="1057090"
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
# v1: gamescope-wrap voor Wayland. De DXVK-logs in de gamemap tonen
# "Exclusive FS: 1" → op XWayland + AMD/RADV stalt dat de presentatie
# (zelfde patroon als Cities). Resolutie: uit → core auto-detect (xrandr);
# pin optioneel met export GAME_GAMESCOPE_RES="WxH".
export GAME_GAMESCOPE="1"

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../game-core/game-common.sh"
game_main "$@"