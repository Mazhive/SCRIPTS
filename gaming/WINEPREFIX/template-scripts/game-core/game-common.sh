#!/bin/bash
# game-common.sh — Herbruikbare core voor Wine-game-launchers.
#
# Elke game wordt een "dun" script dat variabelen exporteert en game_main "$@" aanroept:
#   export GAME_NAME="AngryBirds"
#   export GAME_DIR="/mnt/VG_00/.../WINDOWSGAMES/Angrybirds"
#   export GAME_EXE="$GAME_DIR/AngryBirds.exe"
#   export PREFIX_ARCH="win64"
#   export SCRIPT_VERSION="1"
#   game_main "$@"
#
# Opties:
#   PROVISION_HOOKS=( "install_vcrun2019" "install_vkd3d" )  — extra stappen na provision.
#                     Dit zijn MODULES in game-core/hooks/<naam>.sh (elke specifieke
#                     game-eis leeft daar, NIET in deze generieke core). De core laadt
#                     en voert ze uit (hook_run()); onbekende naam → melding.
#                     Mag ook een losse string zijn: PROVISION_HOOKS="install_vcrun2019";
#                     NIET exporteren als je de array-vorm gebruikt — bash-arrays
#                     overleven `export` niet naar subprocessen, wél binnen dit
#                     script omdat game-common.sh gesourced wordt, niet uitgevoerd.
#   PRE_LAUNCH_HOOKS=( "wacom-detect" ) — extra modules die BIJ ÉLKE START vóór
#                     game_launch lopen (i.p.v. alleen bij provision). Zelfde
#                     module-mechaniek als PROVISION_HOOKS; gebruikt voor
#                     run-vaste fouten/keuzes die niet aan een verse prefix
#                     gebonden zijn (bijv. inputfixes die per prefix idempotent
#                     zijn). Zelfde regel: array-vorm NIET exporteren.
#   VC_RUNTIME_METHOD="winetricks"|"redist"                 — levering van de
#                     VC++2019-runtime door de hook-module install-vcrun2019
#                     (winetricks = referentie-receptuur; redist = gebundelde game-
#                     redist als primair, winetricks als vangnet). Per game in te
#                     stellen, alleen waar de opstarttest het nodig maakt.
#   PREFIX_ROOT="$HOME/GAMEPREFIXES"                          — waar prefixes wonen
#   CREATE_DESKTOP_SHORTCUT="1"                               — .desktop aanmaken op
#                                                                $HOME/Desktop (vaste
#                                                                default; overrulebaar
#                                                                via DESKTOP_SHORTCUT_DIR)
#   PROTON_ENABLED="1" / PROTON_PIN="GE-Proton..."            — start via Proton-runner
#   STEAM_APPID="255710"                                      — echte Steam-appid (voor
#                                                                ProtonFixes-herkenning;
#                                                                default "0" indien onbekend)
#   GAME_KEEP_OVERLAYS="1"                                    — MangoHud/vkBasalt wél actief
#                                                                laten (default: uit; overlays
#                                                                crashen sommige games op RADV)
#   GAME_KEEP_XALIA="1"                                       — GE-Proton's xalia (gamepad-UI-
#                                                                hulp voor launchers/installers)
#                                                                wél aan laten (default: uit)
#   GAME_GAMESCOPE="1"                                       — de launch wrappen via gamescope
#                                                                (nested compositor: Wayland-
#                                                                inputfix, FSR/scaling). Alleen
#                                                                bij een Wayland-sessie én een
#                                                                aanwezige gamescope; anders log
#                                                                en gewoon starten. gamescope
#                                                                zelf installeren gebeurt via de
#                                                                optionele hook install_gamescope.
#   GAME_GAMESCOPE_RES="WxH"                                 — interne gamescope-res vastzetten
#                                                                (reproduceerbaar). Leeg/uit =
#                                                                auto-detect van de actieve
#                                                                monitormode via xrandr.
#
# Richtlijn: de prefix wordt ALTIJD lokaal en vers aangemaakt (wineboot -i);
# er wordt nooit een bestaande prefix gekopieerd of vanaf de NFS-share
# gebruikt. Referentie-prefixen (movedprefixes/, protonprefix/) zijn
# uitsluitend onderzoeksmateriaal om af te leiden welke hooks een game
# nodig heeft — geen runtime-afhankelijkheid. Verwijder je die mappen,
# dan moet elk game-script gewoon blijven werken.

set -u

# ── Vaste paden ──────────────────────────────────────────────
GAMEPREFIXES_ROOT="${PREFIX_ROOT:-$HOME/GAMEPREFIXES}"
HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hooks"

# ── Helpers ──────────────────────────────────────────────────
_log() { echo " [game] $*"; }
_fail() { echo " [game] FOUT: $*" >&2; exit 1; }

_require_var() {
  local name="$1"
  local val
  eval "val=\${$name:-}"
  [ -n "$val" ] || _fail "Variabele '$name' is niet gezet in het game-script."
}

# ── Voortgangs-indicator ─────────────────────────────────────
# Lange winetricks-stappen (dotnet48, vcrun, ...) duren minuten zonder enige
# output. Zonder terugkoppeling denkt een gebruiker dat het script hangt en
# start hij een tweede instantie. Deze generieke indicator print tijdens zulke
# stappen elke 10 s een statusregel op dezelfde terminalregel (CR), en is
# daardoor voor ELKE game en ELKE installatie actief. (De Python-GUI krijgt
# later een eigen voortgangsweergave; dit is de terminal-vangnet-laag.)
BUSY_PID=""
BUSY_TS=""
BUSY_LABEL=""

_busy_start() {
  BUSY_LABEL="$1"
  BUSY_TS="$(date +%s)"
  printf '\n [game] bezig met %s... ' "$BUSY_LABEL"
  (
    local ts="$BUSY_TS"
    while :; do
      sleep 10
      printf '\r [game] bezig met %s... (al %ss)   ' "$BUSY_LABEL" "$(( $(date +%s) - ts ))"
    done
  ) &
  BUSY_PID=$!
}

_busy_stop() {
  local s
  [ -n "$BUSY_PID" ] && kill "$BUSY_PID" 2>/dev/null
  # wait retourneert de kill-status (143) van de net-gestopte voortgangs-
  # indicator; onder set -euo pipefail zou dat de provisioning afbreken.
  wait "$BUSY_PID" 2>/dev/null || true
  BUSY_PID=""
  s=$(( $(date +%s) - BUSY_TS ))
  printf '\r [game] klaar: %s (duurde %ss)\n' "$BUSY_LABEL" "$s"
}

# ── Single-instance lock ─────────────────────────────────────
# Voorkomt dat iemand een tweede launcher start terwijl de eerste nog
# provisiont of de game draait (bv. omdat de voortgangsindicator nog niet
# gezien is). Lock via PID-bestand: geen extra gereedschap nodig. Een oude
# lock van een niet-draaiend proces wordt stil opgeruimd.
_acquire_lock() {
  local lf="$PREFIX_DIR/.launch.lock" pid
  mkdir -p "$PREFIX_DIR"
  if [ -f "$lf" ]; then
    pid="$(cat "$lf" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      _fail "Er draait al een launcher voor $GAME_NAME (PID $pid). Wacht tot die klaar is of stop hem eerst."
    fi
    _log "Oude lock verwijderd ($lf, PID ${pid:-onbekend} draait niet meer)."
    rm -f "$lf"
  fi
  echo "$$" >"$lf"
  _LOCK_FILE="$lf"
  _release_lock() { rm -f "${_LOCK_FILE:-}"; }
  trap _release_lock EXIT INT TERM
}

# ── Sessie-detectie (wayland / x11 / headless) ───────────────
# Wayland: WAYLAND_DISPLAY gezet, of XDG_SESSION_TYPE="wayland" (DISPLAY kan
# op Wayland-sessies nog steeds bestaan als XWayland-display). X11: alleen
# DISPLAY. Geen van beide → headless (geen grafische sessie beschikbaar).
_session_flavor() {
  if [ -n "${WAYLAND_DISPLAY:-}" ] || [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
    echo wayland
  elif [ -n "${DISPLAY:-}" ]; then
    echo x11
  else
    echo headless
  fi
}

# ── Distro-detectie (voor host-level hooks) ──────────────────
# Geeft de pakketbeheerder-familie terug (apt/pacman/dnf/zypper), zodat
# host-tools (bv. gamescope) per distro geïnstalleerd kunnen worden.
# Val op "unknown" als er niets herkend wordt; de caller beslist dan zelf.
_distro_pkg() {
  local id=""
  if [ -r /etc/os-release ]; then
    id="$(awk -F= '/^ID=/{gsub(/["\r]/, "", $2); print $2}' /etc/os-release 2>/dev/null)"
  fi
  case "$id" in
    cachyos|arch|archlinux|manjaro|endeavouros) echo pacman ;;
    debian|ubuntu|linuxmint|pop|elementary|zorin) echo apt ;;
    fedora|rhel|centos|rocky|almalinux) echo dnf ;;
    opensuse|opensuse-leap|opensuse-tumbleweed|sles|sled) echo zypper ;;
    *) echo unknown ;;
  esac
}

# ── Initialisatie ────────────────────────────────────────────
game_init() {
  _require_var GAME_NAME
  _require_var GAME_DIR

  PREFIX_DIR="$GAMEPREFIXES_ROOT/$GAME_NAME"
  PREFIX_PATH="$PREFIX_DIR/pfx"
  MARKER="$PREFIX_DIR/.provisioned"
  PREFIX_ARCH="${PREFIX_ARCH:-win64}"
  SCRIPT_VERSION="${SCRIPT_VERSION:-1}"
  # [*] i.p.v. scalar: PROVISION_HOOKS kan een bash-array zijn (meerdere
  # hooks) of een losse string (één hook); scalar toegang zou bij een
  # array stil alleen element [0] pakken en de rest laten vallen.
  HOOKS="${PROVISION_HOOKS[*]:-}"
  # Zelfde array/string-regel voor de pre-launch-hooks (bij élke start).
  PRE_HOOKS="${PRE_LAUNCH_HOOKS[*]:-}"

  # Native Linux-games (GAME_NATIVE=1) hebben géén Wine-prefix nodig,
  # dus ook geen wine in PATH en geen GAME_EXE — alleen GAME_DIR.
  if [ "${GAME_NATIVE:-0}" != "1" ]; then
    _require_var GAME_EXE
    command -v wine >/dev/null 2>&1 || _fail "wine niet gevonden in PATH."
  fi

  # Een grafische sessie is nodig om een prefix aan te maken én te starten
  # (wineboot/winetricks hebben een display nodig). Bindend vóór wineboot:
  # op bijv. een SSH-terminal zonder X-forwarding faalt wine anders laat en
  # cryptisch; hier komt een duidelijke fout.
  if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    _fail "Geen grafische sessie (DISPLAY noch WAYLAND_DISPLAY is gezet); kan geen prefix aanmaken of game starten."
  fi

  [ -d "$GAME_DIR" ] || _fail "Game-map niet bereikbaar: $GAME_DIR"
  if [ "${GAME_NATIVE:-0}" != "1" ]; then
    [ -f "$GAME_EXE" ] || _fail "Game executable niet gevonden: $GAME_EXE"
  fi
}

# ── Marker/provision status ──────────────────────────────────
game_needs_provision() {
  [ ! -f "$MARKER" ] && return 0
  local stored_version
  stored_version="$(cat "$MARKER" 2>/dev/null | tr -d '[:space:]')"
  [ "$stored_version" != "$SCRIPT_VERSION" ] && return 0
  return 1
}

# ── Wine-prefix aanmaken ─────────────────────────────────────

# Zoek een x86_64-windows builtin-DLL in de aanwezige Proton/GE-Proton-
# runners; PROTON_PIN heeft voorrang. Nooit vanaf de NFS-share.
_proton_builtin_dll() {
  local dll="$1" root runner
  while IFS= read -r root; do
    if [ -n "${PROTON_PIN:-}" ] && \
       [ -f "$root/$PROTON_PIN/files/lib/wine/x86_64-windows/$dll" ]; then
      echo "$root/$PROTON_PIN/files/lib/wine/x86_64-windows/$dll"
      return 0
    fi
    for runner in "$root"/*/files/lib/wine/x86_64-windows/"$dll"; do
      [ -f "$runner" ] && { echo "$runner"; return 0; }
    done
  done < <(_proton_search_roots)
  return 1
}

# Controleer of een PE-DLL de juiste (x86_64) architectuur heeft. Een
# verkeerde (ARM64-)msvcp140.dll in system32 laat x64-processen falen met
# c000007b → icuuc/icuin niet gevonden → game-exit c0000135. Daarom
# arch-validatie vóór alles.
# Controleer of een PE-DLL de juiste (x86_64) architectuur heeft. Een
# verkeerde (ARM64-)msvcp140.dll in system32 laat x64-processen falen met
# c000007b → icuuc/icuin niet gevonden → game-exit c0000135. Daarom
# arch-validatie vóór alles. Positief controleren (moet aantoonbaar
# PE32+/x86-64 zijn), niet alleen "geen ARM64" — anders keurt een compleet
# corrupt/leeg bestand ("data") ten onrechte goed.
_dll_is_x86_64() {
  local f="$1" out
  [ -f "$f" ] || return 1
  command -v file >/dev/null 2>&1 || return 0   # geen 'file': niet blokkeren
  out="$(file -b "$f" 2>/dev/null)"
  echo "$out" | grep -qiE 'PE32\+? executable' || return 1
  echo "$out" | grep -qiE 'aarch64|arm64' && return 1
  echo "$out" | grep -qiE 'x86-64|x86_64|amd64'
}

# Zoek een NATIVE x86_64-runtime-DLL (msvcp/vcruntime/ucrtbase) in de
# default-prefix van een aanwezige GE-Proton/Steam-Proton runner
# (files/share/default_pfx) — dáár levert de runner echte redist-DLLs mee,
# geen wine-builtins. Hulpje voor hook-modules die runtimes leveren.
# PROTON_PIN heeft voorrang.
_runtime_dll_source() {
  local dll="$1" root runner d
  while IFS= read -r root; do
    if [ -n "${PROTON_PIN:-}" ] && [ -d "$root/$PROTON_PIN" ]; then
      d="$root/$PROTON_PIN/files/share/default_pfx/drive_c/windows/system32/$dll"
      [ -f "$d" ] && { echo "$d"; return 0; }
    fi
    for runner in "$root"/*/; do
      [ -d "$runner" ] || continue
      d="$runner/files/share/default_pfx/drive_c/windows/system32/$dll"
      [ -f "$d" ] && { echo "$d"; return 0; }
    done
  done < <(_proton_search_roots)
  return 1
}

# ── Hook-modules uitvoeren ───────────────────────────────────
# Specifieke game-eisen (VC-runtime, vkd3d, ...) leven in APARTE modules:
# game-core/hooks/<naam>.sh. Deze generieke core kent ze niet; hij laadt ze
# alleen op naam (PROVISION_HOOKS). Elke module definieert hook_run().
_run_hook() {
  local name="$1"
  local module="$HOOKS_DIR/$name.sh"
  [ -f "$module" ] || { _log "Hook-module niet gevonden: $module"; return 1; }
  # shellcheck disable=SC1090
  . "$module"
  if declare -f hook_run >/dev/null 2>&1; then
    _busy_start "hook $name"
    hook_run
    _busy_stop
  else
    _log "Hook-module '$name' definieert geen hook_run()."
    return 1
  fi
}

game_provision() {
  _provision_fresh

  # Registry volledig naar disk flushen vóór de game start. Wine schrijft
  # zijn registry pas echt weg als de wineserver stopt; sommige games lezen
  # bij launch direct wat er op disk staat (bleek bij de win10-waarde en de
  # winebus-keys). Dit is de generieke voorziening dáárvoor.
  _busy_start "registry-flush (wineserver -w)"
  WINEPREFIX="$PREFIX_PATH" wineserver -w 2>/dev/null || true
  _busy_stop

  echo "$SCRIPT_VERSION" > "$MARKER"
  _log "Provision klaar (marker v$SCRIPT_VERSION)."
}

# ── Verse prefix via wineboot ─────────────────────────────────
# Enige provision-methode: er wordt nooit een bestaande prefix gekopieerd.
_provision_fresh() {
  _log "Prefix aanmaken voor $GAME_NAME op $PREFIX_PATH"
  mkdir -p "$PREFIX_DIR"

  # gecko/mono-dialogen onderdrukken (niet nodig voor de meeste games)
  export WINEDLLOVERRIDES="mscoree=;mshtml=${WINEDLLOVERRIDES:-}"
  _busy_start "wineboot -i"
  env WINEPREFIX="$PREFIX_PATH" WINEARCH="$PREFIX_ARCH" wineboot -i || \
    { _busy_stop; _fail "wineboot mislukt (prefix: $PREFIX_PATH)"; }
  _busy_stop

  for hook in ${HOOKS:-}; do
    _log "Hook: $hook"
    _run_hook "$hook"
  done
}

# ── Re-provision if marker outdated ──────────────────────────
game_reprovision() {
  if game_needs_provision; then
    _log "Marker-versie verschilt — opnieuw provisionen."
    game_provision
  fi
}

# ── Steam-installatiedirs vinden (voor proton SYSTEEM-steam DLLs) ─
# Uitsluitend lokale paden; geen verwijzing naar de NFS-share. Er zijn
# meerdere mogelijke Steam-flavors (native, .deb-package, flatpak-achtige
# layout); we proberen ze allemaal, in volgorde van meest-gangbaar.
_steam_client_dirs() {
  local dir
  for dir in \
    "$HOME/.steam/steam" \
    "$HOME/.steam/debian-installation" \
    "$HOME/.local/share/Steam"; do
    [ -d "$dir" ] && echo "$dir"
  done
}

_steam_client_dir() {
  local dir
  dir="$(_steam_client_dirs | head -n1)"
  [ -n "$dir" ] || return 1
  echo "$dir"
}

# ── Alle mappen waar Proton/GE-Proton-runners kunnen staan ────
# Heroic-layout + compatibilitytools.d van elke gevonden Steam-flavor.
_proton_search_roots() {
  local dir
  [ -d "$HOME/.config/heroic/tools/proton" ] && echo "$HOME/.config/heroic/tools/proton"
  while IFS= read -r dir; do
    [ -d "$dir/compatibilitytools.d" ] && echo "$dir/compatibilitytools.d"
  done < <(_steam_client_dirs)
}

# ── PROTON_PIN als specifieke GE-Proton runner zoeken ─────────
_detect_pinned_proton() {
  [ -n "${PROTON_PIN:-}" ] || return 1
  local root
  while IFS= read -r root; do
    [ -x "$root/$PROTON_PIN/proton" ] && { echo "$root/$PROTON_PIN/proton"; return 0; }
    [ -d "$root/current" ] && [ -x "$root/current/proton" ] && { echo "$root/current/proton"; return 0; }
  done < <(_proton_search_roots)
  return 1
}

# ── Proton-runner detecteren ─────────────────────────────────
# Zoekvolgorde: PROTON_RUNNER (override) → PROTON_PIN → hoogste
# GE-Proton in Heroic-tools/Steam-compatibilitytools.d → willekeurige
# runner daar → officiële Proton in elke Steam-flavor's steamapps/common
# → umu-run (universeel).
_detect_proton() {
  if [ -n "${PROTON_RUNNER:-}" ] && [ -x "$PROTON_RUNNER" ]; then
    echo "$PROTON_RUNNER"
    return 0
  fi

  local chosen=""
  chosen="$(_detect_pinned_proton)" && { echo "$chosen"; return 0; }

  local root dir
  while IFS= read -r root; do
    for dir in $(ls -1d "$root"/GE-*/ 2>/dev/null | sort -Vr); do
      if [ -x "$dir/proton" ]; then
        chosen="${dir%/}/proton"
        break 2
      fi
    done
  done < <(_proton_search_roots)

  if [ -z "$chosen" ]; then
    while IFS= read -r root; do
      for dir in "$root"/*/; do
        if [ -x "$dir/proton" ]; then
          chosen="${dir%/}/proton"
          break 2
        fi
      done
    done < <(_proton_search_roots)
  fi

  # Officiële Proton (Steam-eigen), elke installatie-flavor: elke map
  # onder steamapps/common/ die een uitvoerbaar 'proton'-bestand heeft
  # (naamgeving varieert: "Proton 9.0 (Beta)", "Proton - Experimental", ...).
  if [ -z "$chosen" ]; then
    local steamdir
    while IFS= read -r steamdir; do
      for dir in "$steamdir/steamapps/common"/*/; do
        if [ -x "$dir/proton" ]; then
          chosen="${dir%/}/proton"
          break 2
        fi
      done
    done < <(_steam_client_dirs)
  fi

  if [ -z "$chosen" ] && command -v umu-run >/dev/null 2>&1; then
    chosen="umu-run"
  fi

  [ -n "$chosen" ] || return 1
  echo "$chosen"
}

# ── Instructie bij ontbrekend Proton ─────────────────────────
# Generiek: geldt voor elke game met PROTON_ENABLED=1, gebruikt $GAME_NAME.
_warn_missing_proton() {
  local base
  base="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  base="${base%/game-core}"
  echo " [game] FOUT: deze game (${GAME_NAME:-onbekend}) is geconfigureerd om" >&2
  echo " [game] via Proton te starten (PROTON_ENABLED=1), maar er is geen" >&2
  echo " [game] Proton-runner gevonden." >&2
  echo " [game]" >&2
  echo " [game] Installeer GE-Proton via het meegeleverde script:" >&2
  echo " [game]   $base/tools/install-proton.sh" >&2
  echo " [game] (of dubbelklik/snelkoppeling: 'InstallProton' in je applicatielijst)" >&2
  echo " [game]" >&2
  echo " [game] Of installeer handmatig: protonup-qt, of via Steam > Instellingen > Compatibiliteit." >&2
  echo " [game] Na installatie start je dit script opnieuw." >&2
  return 1
}

# ── Ontbrekend Proton: interactief/grafisch laten oplossen ────
# Roept de losse poortwachter tools/ensure-proton.sh aan (kan ook door de
# toekomstige Python-GUI los gebruikt worden). Valt terug op de statische
# instructietekst als dat script zelf niet gevonden/uitvoerbaar is.
_ensure_proton_or_warn() {
  local base ensure_script
  base="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  base="${base%/game-core}"
  ensure_script="$base/tools/ensure-proton.sh"
  if [ -x "$ensure_script" ]; then
    "$ensure_script" && return 0
    return 1
  fi
  _warn_missing_proton
  return 1
}

# ── Overlays neutraliseren (MangoHud/vkBasalt) ───────────────
# Overlay-layers crashen sommige games (bv. Cyberpunk op RADV) tijdens de
# Vulkan-init, en niet iedereen heeft ze sowieso draaien. Daarom standaard
# UIT voor game-runs; expliciet weer aan via GAME_KEEP_OVERLAYS=1.
_neutralize_overlays() {
  [ "${GAME_KEEP_OVERLAYS:-0}" = "1" ] && return 0
  export DISABLE_MANGOHUD=1
  unset MANGOHUD ENABLE_VKBASALT 2>/dev/null || true
  :
}

# ── Xalia neutraliseren (GE-Proton gamepad-UI-hulp) ──────────
# xalia.exe is Ge-Proton's controller-UI voor launchers/installers (AT-SPI2/
# UIAutomation), ingeschakeld via PROTON_USE_XALIA=1 (default in GE-Proton11).
# Voor game-runs is-'t overbodig én het crasht op sommige hosts tijdens DXVK/
# Vulkan-init (breekt dan de hele launch). Standaard UIT; expliciet weer aan
# via GAME_KEEP_XALIA=1.
_neutralize_xalia() {
  [ "${GAME_KEEP_XALIA:-0}" = "1" ] && return 0
  export PROTON_USE_XALIA=0
  :
}

# ── Game starten ─────────────────────────────────────────────
# Bepaalt of deze run via gamescope moet lopen. GUI-override:
# GUI_GAMESCOPE="1|0" heeft voorrang op GAME_GAMESCOPE, zodat de checkbox
# in de launcher-GUI per klik gamescope aan/uit kan zetten ook als een
# game-script zelf "1" of "0" hardcodeert (zelfde patroon als
# GUI_DESKTOP_SHORTCUT bij game_make_desktop).
_gscope_want() {
  if [ -n "${GUI_GAMESCOPE:-}" ]; then
    [ "${GUI_GAMESCOPE:-0}" = "1" ] && return 0 || return 1
  fi
  [ "${GAME_GAMESCOPE:-0}" = "1" ]
}

# Vul GSCOPE_ARGV met de gamescope-wrap-argumenten als gamescope actief is
# (gewenst én Wayland-sessie én vindbare gamescope). Anders leeg → game wordt
# gewoon gestart. Herbruikbaar door game_launch én door eigen launch-scripts
# (bv. automationempire) die geen game_main gebruiken.
GSCOPE_ARGV=()
_gscope_argv() {
  GSCOPE_ARGV=()
  _gscope_want || return 0
  if [ "$(_session_flavor)" != "wayland" ] || ! command -v gamescope >/dev/null 2>&1; then
    _log "GAME_GAMESCOPE=1 overgeslagen (geen Wayland-sessie maar $(_session_flavor))."
    return 0
  fi
  # GAME_GAMESCOPE_RES="WxH": interne gamescope-res reproduceerbaar zetten op
  # de native monitormode (voorkomt dat gamescope zelf iets laags/gepatched
  # kiest, bv. 720p, op een 1080p/1440p-scherm). Niet gezet? → gratis
  # auto-detect van de actieve monitormode (xrandr); ook dat mislukt? →
  # gamescope laat zelf kiezen.
  GSCOPE_ARGV=( gamescope -f )
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
    GSCOPE_ARGV+=( -W "${_gcalc%x*}" -H "${_gcalc#*x}" )
  fi
  GSCOPE_ARGV+=( -- )
  _log "Gamescope-wrap actief (Wayland-sessie): $(command -v gamescope) res=${_gcalc:-auto}"
}

game_launch() {
  _neutralize_overlays
  _neutralize_xalia
  _log "Starten: ${GAME_EXE:-${GAME_NATIVE_SHELL:-}$GAME_NATIVE_CMD} (prefix: $PREFIX_PATH)"

  cd "$GAME_DIR" || _fail "Kan niet naar $GAME_DIR"

  # GAME_GAMESCOPE=1: de launch wrappen via gamescope (nested compositor).
  # Dit lost op Wayland-lagen de bekende XWayland-inputbug op (muis wordt
  # wel gezien maar kliks/toetsen niet — Proton#6845) en levert FSR/scaling.
  # Alleen actief bij een Wayland-sessie én een vindbare gamescope; anders
  # netjes melden en gewoon starten (de game kan alsnog werken).
  _gscope_argv
  local gscope=()
  [ "${#GSCOPE_ARGV[@]}" -gt 0 ] && gscope=("${GSCOPE_ARGV[@]}")

  if [ "${GAME_NATIVE:-0}" = "1" ]; then
    # Native Linux-game: géén Proton/wine — draai het native commando
    # (optioneel via een shell indien het een script/binair nodig heeft).
    local native_start=()
    [ -n "${GAME_NATIVE_SHELL:-}" ] && native_start+=("$GAME_NATIVE_SHELL")
    native_start+=("$GAME_NATIVE_CMD")
    "${gscope[@]}" "${native_start[@]}" "$@"
    return $?
  fi

  if [ "${PROTON_ENABLED:-0}" = "1" ]; then
    local runner compatdir clientdir appid
    # Vereiste runner garanderen: is een PROTON_PIN gezet maar die versie
    # mist, dan eerst (met Ja/Nee-keuze) installeren — géén stille downgrade
    # naar een willekeurige andere runner. Alleen zónder PIN mag er een
    # aanwezige alternatieve runner gebruikt worden.
    # Met een PROTON_PIN is die runner verplicht: ontbreekt hij, dan eerst
    # (met Ja/Nee-keuze) installeren en daarna alsnog expliciet op de pin
    # inzetten. Er volgt géén stille terugval op een andere runner.
    if [ -n "${PROTON_PIN:-}" ]; then
      _detect_pinned_proton >/dev/null 2>&1 || _ensure_proton_or_warn || return 1
      runner="$(_detect_pinned_proton)" || {
        _log "Gepinde runner '$PROTON_PIN' nog niet beschikbaar; geen fallback."
        _warn_missing_proton
        return 1
      }
    else
      runner="$(_detect_proton)" || {
        _ensure_proton_or_warn || return 1
        runner="$(_detect_proton)" || { _warn_missing_proton; return 1; }
      }
    fi
    _log "Start via Proton-runner: $runner"
    # ProtonFixes leidt zijn "game id" af met een regex op cijfers in
    # STEAM_COMPAT_DATA_PATH (re.findall(r'\d+', ...)[-1]). Zonder cijfers
    # in het pad crasht dat met IndexError — dus altijd een numerieke
    # sub-map gebruiken (zoals Steam: compatdata/<appid>/), onafhankelijk
    # van of GAME_NAME toevallig cijfers bevat.
    appid="${STEAM_APPID:-0}"
    compatdir="$PREFIX_DIR/compatdata/$appid"
    mkdir -p "$compatdir"
    [ -e "$compatdir/pfx" ] || ln -s "$PREFIX_PATH" "$compatdir/pfx"
    touch "$compatdir/tracked_files"
    clientdir="$(_steam_client_dir)" || clientdir=""
    export STEAM_COMPAT_DATA_PATH="$compatdir"
    export STEAM_COMPAT_INSTALL_PATH="$GAME_DIR"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$clientdir"
    export STEAM_COMPAT_APP_ID="$appid"
    export SteamAppId="$appid"
    export WINEPREFIX="$PREFIX_PATH"
    "${gscope[@]}" "$runner" waitforexitandrun "$GAME_EXE" "$@"
  else
    WINEPREFIX="$PREFIX_PATH" "${gscope[@]}" ${WINE_CMD:-wine} "$GAME_EXE" "$@"
  fi
}

# ── .desktop-shortcut ────────────────────────────────────────
# Maakt een .desktop-icoon aan zodat de game zonder terminal/GUI te starten is.
# Vaste standaard-afleverplek: de Desktop-map van de gebruiker
# ($HOME/Desktop). De Python-GUI krijgt hiervoor een inputveld dat via
# DESKTOP_SHORTCUT_DIR (of het eerste argument) een andere doelmap
# meegeeft; de default blijft altijd de Desktop.
# Icon: DESKTOP_ICON_PATH (expliciet) of auto-resolve via gameicons/.
# Auto-resolve gebruikt dezelfde matchregel als de GUI (_resolve_icon):
# exacte bestandsnaam → genormaliseerde naam (althans) → containment
# (stem IN key of key IN stem). Zo pakt bv. "CitiesSkylines" ook
# "Cities&Skylines.png" en "AstroidBountyHunter" ook "astroid.bounty.hunter.png".
# GUI-override: GUI_DESKTOP_SHORTCUT="1|0" heeft voorrang op CREATE_DESKTOP_SHORTCUT
# (de launcher-scripts hardcoderen "1", zodat de GUI-checkbox erdoorheen kan).
game_make_desktop() {
  local gui_flag
  gui_flag="${GUI_DESKTOP_SHORTCUT:-}"
  if [ -n "$gui_flag" ]; then
    [ "$gui_flag" = "1" ] || return 0
  else
    [ "${CREATE_DESKTOP_SHORTCUT:-0}" = "1" ] || return 0
  fi
  local base apps_dir launcher icon_path f norm key_norm
  base="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  launcher="${GAME_LAUNCHER:-$base/game-launchers/${GAME_NAME}.sh}"
  apps_dir="${1:-${DESKTOP_SHORTCUT_DIR:-$HOME/Desktop}}"
  mkdir -p "$apps_dir"

  if [ -n "${DESKTOP_ICON_PATH:-}" ]; then
    icon_path="$DESKTOP_ICON_PATH"
  else
    local icons_dir="$base/game-launchers/gameicons"
    if [ -d "$icons_dir" ]; then
      # Genormaliseerde sleutel van GAME_NAME (alleen a-z0-9, lowercase).
      key_norm="$(echo "$GAME_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')"
      # Eerste pass: exact + containerscan op genormaliseerde stempjes.
      for f in "$icons_dir"/*; do
        [ -f "$f" ] || continue
        stem="${f##*/}"
        stem="${stem%.*}"
        norm="$(echo "$stem" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')"
        if [ "$norm" = "$key_norm" ]; then icon_path="$f"; break; fi
      done
      if [ -z "${icon_path:-}" ]; then
        for f in "$icons_dir"/*; do
          [ -f "$f" ] || continue
          stem="${f##*/}"
          stem="${stem%.*}"
          norm="$(echo "$stem" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')"
          if [ -n "$norm" ] && { case "$norm" in *"$key_norm"*) true;; *) false;; esac; } \
             || { [ -n "$key_norm" ] && case "$key_norm" in *"$norm"*) true;; *) false;; esac; }; then
            icon_path="$f"
            break
          fi
        done
      fi
      # Laatste redmiddel: directe naam-match (zonder normalisatie).
      for ext in png jpg jpeg; do
        f="$icons_dir/${GAME_NAME}.${ext}"
        [ -f "$f" ] && icon_path="$f" && break
      done
    fi
  fi

  cat > "$apps_dir/$GAME_NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$GAME_NAME
Exec="$launcher"
${icon_path:+Icon=$icon_path}
Terminal=false
Categories=Game;
EOF
  chmod +x "$apps_dir/$GAME_NAME.desktop"
  _log "Shortcut aangemaakt: $apps_dir/$GAME_NAME.desktop${icon_path:+ (icon: $icon_path)}"
}

# ── Backup-rotatie ───────────────────────────────────────────
# Vóór elke uitvoerbare run: snapshot van de projectmap naar
# backup/ver1_<datum>_<tijd>; ver1→ver2→ver3, oudste weg (max 3). De nieuwste
# werkversie blijft in de hoofdmap. De backup-map zelf wordt uitgesloten om
# recursie te voorkomen (de grote GE-Proton-tar.restant zit daar).
_snapshot_backup() {
  local base backup_root ts d
  base="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  backup_root="$base/backup"
  [ -d "$backup_root" ] || return 0
  command -v rsync >/dev/null 2>&1 || { _log "rsync ontbreekt; backup-snapshot overgeslagen."; return 0; }

  ts="$(date +%Y%m%d_%H%M%S)"
  rm -rf "$backup_root/ver3_"* 2>/dev/null || true
  for d in "$backup_root/ver2"_*; do
    [ -d "$d" ] || continue
    mv "$d" "$backup_root/ver3_${d##*/ver2_}" 2>/dev/null || true
  done
  for d in "$backup_root/ver1"_*; do
    [ -d "$d" ] || continue
    mv "$d" "$backup_root/ver2_${d##*/ver1_}" 2>/dev/null || true
  done

  mkdir -p "$backup_root/ver1_$ts" || return 0
  rsync -a --exclude 'backup/' "$base"/ "$backup_root/ver1_$ts"/ 2>/dev/null || true
  _log "Backup-snapshot gemaakt: backup/ver1_$ts"
}

# ── Hoofd-flow ───────────────────────────────────────────────
game_main() {
  game_init
  _acquire_lock
  _snapshot_backup
  if [ "${PROTON_ENABLED:-0}" != "1" ]; then
    # Wacht alleen op een wineserver van DEZE prefix, en nooit langer dan 10 s.
    # Zonder scope blokkeert `wineserver -w` op élke actieve wine op het systeem
    # (bv. een lopende installatie van een andere game) — dat hangt de launch.
    # Bij een verse provision bestaat de prefix-map nog niet → regel slaat over.
    if [ -d "$PREFIX_PATH" ]; then
      timeout 10 env WINEPREFIX="$PREFIX_PATH" wineserver -w 2>/dev/null || true
    fi
  fi
  if [ "${GAME_NATIVE:-0}" = "1" ]; then
    _log "Native Linux-game: geen Wine-prefix/provision nodig."
  elif game_needs_provision; then
    game_provision
  else
    _log "Prefix is al geprovisiond (v$(cat "$MARKER"))."
  fi
  game_make_desktop
  PRE_HOOK_RUN=1
  for hook in ${PRE_HOOKS:-}; do
    _log "Pre-launch-hook: $hook"
    _run_hook "$hook"
  done
  game_launch "$@"
}