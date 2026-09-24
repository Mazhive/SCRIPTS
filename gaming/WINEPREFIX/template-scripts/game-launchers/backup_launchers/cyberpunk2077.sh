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
# v13: disable_winebus-hook: Wacom-tablet als /dev/input/js0 joystick →
#      game ziet "controller" en negeert muis+toetsenbord (bewezen: Space
#      doet niks op de startscreen). Enable SDL=0 + DisableHidraw=1 verhielp
#      het (echte input-fix; gamescope noch compositor had effect). +
#      install_gamescope-hook (detect/install nested compositor; wrap alleen
#      bij Wayland-sessies via GAME_GAMESCOPE=1).
# v14: disable_winebus verwijderd — die schakelde óók echte gamepads uit.
#      Vervangen door wacom-detect: waarschuwt + vraagt (Ja/Nee) om de
#      Wacom-kabel los te trekken. De bus/tablet kan gewoon aanblijven.
#      NB: bij deze overgang vielen vcrun2019/PIN/gamescope weg (regressie).
# v15: wacom-detect-handigheid: interactie nu via tools/ask-yesno.sh
#      (TTY/kdialog/zenity); GUI-ready via WACOM_CHOICE=ja|nee.
# v16: werkende v13-voorzieningen teruggezet (install_vcrun2019, PROTON_PIN,
#      GAME_GAMESCOPE) én wacom-detect behouden — géén disable_winebus.
# v17: oorzaak + fix bewezen. "Wacom los trekken" is nooit genoeg: de eigen
#      toetsenbord-js (17ef:6099) blijft áls joystick bestaan en de game zet
#      dan toetsenbord uit (getest: Space dood met alleen keyboard-js1).
#      Fix = winebus "Enable SDL"=0 (hidraw blijft aan) → toetsenbord EN
#      gamepad werken; SDL-env-hints doen niets voor deze game (getest).
#      Test D bewees daarna dat de Wacom onschuldig is (SDL=0 + Wacom erin =
#      werkt, óók als de keuze "Nee" was). Conclusie: de wacom-detect-flow
#      is niet meer nodig — de fix zit stil in de provision-hooks.
#      Verse prefix nodig → v17.
export SCRIPT_VERSION="17"
# Bewezen werkend voor deze game; als deze ontbreekt valt _detect_proton
# terug op de hoogste GE-Proton / Steam-Proton / umu-run.
export PROTON_PIN="GE-Proton11-7"
# Plan B (v11): officiële redist primair i.p.v. winetricks; zie hook-module.
export VC_RUNTIME_METHOD="redist"
# Gamepads blijven werken; fix zit in de provision-hooks (stil, geen prompt).
# GAME_GAMESCOPE: launch wrappen via gamescope bij Wayland-sessies.
export GAME_GAMESCOPE="1"
# Hooks bij provision: vcrun2019 (verplicht), gamescope (detect/install) en
# disable_winebus (inputfix — "Enable SDL"=0, hidraw/blijft, bewezen fix).
# Pre-launch-hook: DITZELFDE disable_winebus draait bij elKAAR start als
# drift-guard, zodat de bekende-werkende staat (keyboard) altijd gegarandeerd
# is, ook als de winebus-registry ooit weer wordt omgezet. Idempotent + snel.
# Eerder zat hier wacom-detect als pre-launch-hook; eruit na Test D (SDL=0 +
# Wacom erin werkt) — de Wacom deed niet mee. wacom-detect.sh blijft als
# herbruikbare module voor andere hosts/games.
PROVISION_HOOKS=("install_gamescope" "install_vcrun2019" "disable_winebus")
PRE_LAUNCH_HOOKS=("disable_winebus")

source "$(dirname "${BASH_SOURCE[0]}")/../game-core/game-common.sh"
game_main "$@"

