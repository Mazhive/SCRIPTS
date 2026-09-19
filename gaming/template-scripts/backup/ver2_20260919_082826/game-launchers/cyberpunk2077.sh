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
# v10: VC++2019-runtime levering verplaatst naar aparte hook-module
#      (game-core/hooks/install-vcrun2019.sh) — receptuur = known-working
#      referentie-prefix: winetricks ucrtbase2019 + vcrun2019 (native,
#      builtin-overrides). Verse prefix nodig → v10.
# v11: winetricks laat msvcp140/140_2/vcruntime140_1 als WINE-builtin staan;
#      game crasht dan (c0000005) in de exe-init. Referentie-prefix had de
#      volledige officiële redist (v14.29.30157). Daarom Plan B:
#      VC_RUNTIME_METHOD=redist — gebundelde VC_redist.x64.exe primair
#      (installeert álle x64-CRT-DLLs native via MSI), winetricks als
#      vangnet. Re-provision nodig → v11.
# v12: winetricks' vcrun2019 zet de prefix op win7 → game kiest zijn
#      bundled d3d12on7 (AV-crash c0000005). Hook herstelt nu win10
#      (native D3D12-route via vkd3d-proton, zoals referentie). Re-provision
#      nodig → v12.
export SCRIPT_VERSION="12"
# Bewezen werkend voor deze game; als deze ontbreekt valt _detect_proton
# terug op de hoogste GE-Proton / Steam-Proton / umu-run.
export PROTON_PIN="GE-Proton11-7"
# Plan B (v11): officiële redist primair i.p.v. winetricks; zie hook-module.
export VC_RUNTIME_METHOD="redist"
# Geen 'export': PROVISION_HOOKS mag een array zijn, en bash-arrays
# overleven export niet naar subprocessen. Dat is hier geen probleem: dit
# script sourcet game-common.sh (game_init leest de array in dit proces).
PROVISION_HOOKS=("install_vcrun2019")

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../game-core/game-common.sh"
game_main "$@"