#!/bin/bash
# callofdutyvanguard.sh — Call of Duty Vanguard (h00dbyair/Ksenia v1.26 CrackFix)
# via Proton. IW 8.0 / D3D12-titel → Proton-runner (vkd3d-proton), zoals
# forza-horizon-5.sh. Launch via bootstrapper.exe "Vanguard.exe" (exact de
# flow van StartGame.bat): die start de anti-cheat-service en lanceert de game.
#
# Service-stub: de repack eist de kernel-service `atvi-geirdriful`
# (geirdriful.sys) vóór de launch — "Game MUST be launched ... to satisfy the
# games anticheat". De hook install_atvi_service registreert hem in de verse
# prefix (Wine = alleen register/SCM, geen echte kernel-driver).
#
# Bekende risico's (fast-check, 2026-09): officieel is Vanguard "Borked" op
# Proton (Ricochet kernel-driver), maar deze crack is offline (SP/MP/ZM) en
# gebruikt de driver alleen als stub. De live-test moet uitwijzen of Wine's
# SCM voldoet. Geen Steam-emu-DLLs aanwezig (geen steam_api64).
#
# Belangrijk: proton runner start bij elke call een nieuwe wineserver, wat de
# service-state (RUNNING) vernietigt. Daarom starten we wineserver persistent,
# draaien pre-launch hook (service RUNNING), en voeren bootstrapper.exe **direct**
# uit met GE-Proton wine in DEZEZELFDE wineserver (geen proton runner wrapper).

export GAME_NAME="CallOfDutyVanguard"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/WINDOWSGAMES/Call_of_Duty_-_Vanguard/Call of Duty Vanguard"
export GAME_EXE="$GAME_DIR/bootstrapper.exe"
export PREFIX_ARCH="win64"
export SCRIPT_VERSION="2"
export CREATE_DESKTOP_SHORTCUT="0"
export GAME_LAUNCHER="$(readlink -f "$0")"

export PROTON_ENABLED="1"
export PROTON_PIN="GE-Proton11-7"
export STEAM_APPID="1985820"
export GAME_GAMESCOPE="0"

PROVISION_HOOKS=("install_atvi_service")
PRE_LAUNCH_HOOKS=("install_atvi_service")

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../game-core/game-common.sh"

# game-common zet PREFIX_PATH pas in game_init; wij hebben hem eerder nodig
# voor de persistent-wineserver-start. Zelfde formule als game-common.sh.
GAMEPREFIXES_ROOT="${GAMEPREFIXES_ROOT:-${PREFIX_ROOT:-$HOME/GAMEPREFIXES}}"
PREFIX_DIR="$GAMEPREFIXES_ROOT/$GAME_NAME"
PREFIX_PATH="$PREFIX_DIR/pfx"

# Start wineserver persistent VÓÓR pre-launch hooks.
# Detecteer GE-Proton wineserver bin.
_detect_pinned_proton >/dev/null 2>&1 || _ensure_proton_or_warn || exit 1
runner="$(_detect_pinned_proton)" || { _log "Gepinde runner '$PROTON_PIN' niet beschikbaar"; exit 1; }
wineserver_bin="$(dirname "$runner")/files/bin/wineserver"
wine_bin="$(dirname "$runner")/files/bin/wine"

# Start wineserver persistent als nog niet draait.
if ! pgrep -f "$wineserver_bin" >/dev/null 2>&1; then
  WINEPREFIX="$PREFIX_PATH" "$wineserver_bin" -p >/dev/null 2>&1 &
  sleep 0.5
  _log "Persistent wineserver gestart: $wineserver_bin -p"
fi

# Override game_launch: directe wine-executie in persistent wineserver.
game_launch() {
  _neutralize_overlays
  _neutralize_xalia
  _log "Starten: $GAME_EXE (prefix: $PREFIX_PATH, direct wine)"
  cd "$GAME_DIR" || _fail "Kan niet naar $GAME_DIR"

  local gscope=()
  if [ "${GAME_GAMESCOPE:-0}" = "1" ]; then
    if [ "$(_session_flavor)" = "wayland" ] && command -v gamescope >/dev/null 2>&1; then
      gscope=( gamescope -f )
      local _gcalc=""
      if [[ "${GAME_GAMESCOPE_RES:-}" =~ ^[0-9]+x[0-9]+$ ]]; then
        _gcalc="$GAME_GAMESCOPE_RES"
      else
        _gcalc="$(xrandr --current 2>/dev/null | awk '/\*/{ for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+x[0-9]+$/) { print $i; exit } }')"
        if [[ "$_gcalc" =~ ^[0-9]+x[0-9]+$ ]]; then
          _log "GAME_GAMESCOPE_RES niet gezet → native-mode auto-detect: $_gcalc"
        else
          _gcalc=""
          _log "WARN: GAME_GAMESCOPE_RES niet gezet én geen native-mode detecteerbaar; gamescope mag zelf kiezen. Tip: export GAME_GAMESCOPE_RES='WxH'."
        fi
      fi
      if [[ "$_gcalc" =~ ^[0-9]+x[0-9]+$ ]]; then
        gscope+=( -W "${_gcalc%x*}" -H "${_gcalc#*x}" )
      fi
      gscope+=( -- )
      _log "Gamescope-wrap actief (Wayland-sessie): $(command -v gamescope) res=${_gcalc:-auto}"
    elif command -v gamescope >/dev/null 2>&1; then
      _log "GAME_GAMESCOPE=1 overgeslagen (geen Wayland-sessie maar $(_session_flavor))."
    else
      _log "GAME_GAMESCOPE=1 maar gamescope niet gevonden; start zonder wrap."
    fi
  fi

  # Proton-compat env instellen (voor ProtonFixes, dxvk, vkd3d, etc.)
  local appid="${STEAM_APPID:-0}"
  local compatdir="$PREFIX_DIR/compatdata/$appid"
  mkdir -p "$compatdir"
  [ -e "$compatdir/pfx" ] || ln -s "$PREFIX_PATH" "$compatdir/pfx"
  touch "$compatdir/tracked_files"
  local clientdir="$(_steam_client_dir)" || clientdir=""
  export STEAM_COMPAT_DATA_PATH="$compatdir"
  export STEAM_COMPAT_INSTALL_PATH="$GAME_DIR"
  export STEAM_COMPAT_CLIENT_INSTALL_PATH="$clientdir"
  export STEAM_COMPAT_APP_ID="$appid"
  export SteamAppId="$appid"
  export WINEPREFIX="$PREFIX_PATH"
  export PROTON_ENABLED="1"
  export PROTON_PIN="GE-Proton11-7"

  # GE-Proton library paths repliceren (LD_LIBRARY_PATH + WINEDLLPATH)
  # runner = /path/to/GE-Proton11-7/proton
  # lib_dir = $(dirname "$runner")/files/lib/
  local lib_dir="$(dirname "$runner")/files/lib/"
  local ld_paths=(
    "$lib_dir""vkd3d"
    "$lib_dir""wine"
    "$lib_dir""x86_64-linux-gnu"
    "$lib_dir""i386-linux-gnu"
  )
  export LD_LIBRARY_PATH="${ld_paths[*]}:${LD_LIBRARY_PATH:-}"
  export WINEDLLPATH="${lib_dir}vkd3d:${lib_dir}wine:${WINEDLLPATH:-}"

  # Debug: service status check in onze wineserver
  _log "Debug: service status vóór launch:"
  WINEPREFIX="$PREFIX_PATH" "$wine_bin" sc.exe query atvi-geirdriful 2>&1 | grep -viE "MANGOHUD|blacklist" | head -10 | while IFS= read -r line; do _log "  $line"; done

  # Directe uitvoering in onze persistent wineserver
  _log "Start via directe wine: $wine_bin"
  "${gscope[@]}" "$wine_bin" "$GAME_EXE" "Vanguard.exe"
}

game_main "$@" "Vanguard.exe"