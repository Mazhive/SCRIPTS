#!/bin/bash
# aow-planetfall.sh — Age of Wonders: Planetfall (Il2CPP Unity) via plain wine.
# CODEX-dump met steam_api64.dll emu; opstarten zonder Steam-fusie-beperking,
# dan non-Steam-test om de appid-script te bevestigen.
#
# Recept gebaseerd op known-good-prefix movedprefixes/AOW.Planetfall:
#   plain wine (systeem-wine, géén Proton) + Windows 7 + native DXVK via
#   winetricks + d3dcompiler_43/d3dx9 + VC++2019-runtimes + .NET 4.8 (mono weg).
# Dit lost de witte-UI-tekst op (WineD3D-shaderbug) en start de menu's correct.
#
# gamescope geeft "Primary child shut down!" met deze CODEX-emu
# (steam_api64.dll/steamclient64.dll) onder Xwayland. Volgens de Richtlijn:
# "Alleen actief bij een Wayland-sessie én een vindbare gamescope;
# anders netjes melden en gewoon starten (de game kan alsnog werken)."
# Daarom GAME_GAMESCOPE=0 voor deze game.

export GAME_NAME="AOW.Planetfall"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/WINDOWSGAMES/AOW.Planetfall"
export GAME_EXE="$GAME_DIR/AowPF.exe"
export PREFIX_ARCH="win64"
export SCRIPT_VERSION="3"
export CREATE_DESKTOP_SHORTCUT="0"
export GAME_LAUNCHER="$(readlink -f "$0")"

# Plain wine zoals de known-good-prefix (geen Proton-runner nodig voor deze game).
export PROTON_ENABLED="0"

# Echte Steam-appid van AOW.Planetfall (onbezeten, zoals gescand in 2026-09):
export STEAM_APPID="718850"

# gamescope UIT: CODEX-emu (steam_api64.dll/steamclient64.dll) crasht onder Xwayland.
# Volgens Richtlijn: "alleen actief bij Wayland + gamescope; anders gewoon starten".
export GAME_GAMESCOPE="0"

# Hooks die bij eerste run provisioneren (known-good-recept, die volgorde):
#   vcrun2019    → VC++2019-runtimes (vcruntime140/msvcp140/concrt140 e.a.)
#   d3dx9        → d3dcompiler_43 + d3dx9_24..43 native (witte tekst-fix)
#   dxvk         → DXVK native in prefix (d3d9/d3d10core/d3d11/dxgi=native)
#   dotnet48     → .NET 4.8 + mono verwijderd (mscoree=native)
#   win7         → Windows 7 (CurrentVersion 6.1, SP1)
PROVISION_HOOKS=(install_vcrun2019 install_d3dx9 install_dxvk install_dotnet48 install_win7)

# Pre-launch hooks die bij ELKE start voor de game draaien (input fixes, etc.).
PRE_LAUNCH_HOOKS=(disable_winebus)

# CODEX-emu DLL-overrides: known-good slaat géén steam_api64/xinput/dinput
# overrides op in de registry (dlls liggen naast de exe en laden vanzelf);
# lege WINEDLLOVERRIDES houden.

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../game-core/game-common.sh"
game_main "$@"