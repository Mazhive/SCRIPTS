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
#   VC_RUNTIME_METHOD="winetricks"|"redist"                 — levering van de
#                     VC++2019-runtime door de hook-module install-vcrun2019
#                     (winetricks = referentie-receptuur; redist = gebundelde game-
#                     redist als primair, winetricks als vangnet). Per game in te
#                     stellen, alleen waar de opstarttest het nodig maakt.
#   PREFIX_ROOT="$HOME/GAMEPREFIXES"                          — waar prefixes wonen
#   CREATE_DESKTOP_SHORTCUT="1"                               — .desktop aanmaken
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

# ── Initialisatie ────────────────────────────────────────────
game_init() {
  _require_var GAME_NAME
  _require_var GAME_DIR
  _require_var GAME_EXE

  PREFIX_DIR="$GAMEPREFIXES_ROOT/$GAME_NAME"
  PREFIX_PATH="$PREFIX_DIR/pfx"
  MARKER="$PREFIX_DIR/.provisioned"
  PREFIX_ARCH="${PREFIX_ARCH:-win64}"
  SCRIPT_VERSION="${SCRIPT_VERSION:-1}"
  # [*] i.p.v. scalar: PROVISION_HOOKS kan een bash-array zijn (meerdere
  # hooks) of een losse string (één hook); scalar toegang zou bij een
  # array stil alleen element [0] pakken en de rest laten vallen.
  HOOKS="${PROVISION_HOOKS[*]:-}"

  command -v wine >/dev/null 2>&1 || _fail "wine niet gevonden in PATH."

  [ -d "$GAME_DIR" ] || _fail "Game-map niet bereikbaar: $GAME_DIR"
  [ -f "$GAME_EXE" ] || _fail "Game executable niet gevonden: $GAME_EXE"
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
    hook_run
  else
    _log "Hook-module '$name' definieert geen hook_run()."
    return 1
  fi
}

game_provision() {
  _provision_fresh

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
  env WINEPREFIX="$PREFIX_PATH" WINEARCH="$PREFIX_ARCH" wineboot -i || \
    _fail "wineboot mislukt (prefix: $PREFIX_PATH)"

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
game_launch() {
  _neutralize_overlays
  _neutralize_xalia
  _log "Starten: $GAME_EXE (prefix: $PREFIX_PATH)"
  cd "$GAME_DIR" || _fail "Kan niet naar $GAME_DIR"
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
    "$runner" waitforexitandrun "$GAME_EXE" "$@"
  else
    WINEPREFIX="$PREFIX_PATH" ${WINE_CMD:-wine} "$GAME_EXE" "$@"
  fi
}

# ── .desktop-shortcut ────────────────────────────────────────
# Maakt een .desktop-icoon aan zodat de game zonder terminal/GUI te starten is.
# Doelmap is door de Python-GUI beïnvloedbaar: geef de plek als argument
# (${1}) of via DESKTOP_SHORTCUT_DIR; default is $HOME/.local/share/applications.
game_make_desktop() {
  [ "${CREATE_DESKTOP_SHORTCUT:-0}" = "1" ] || return 0
  local base apps_dir launcher
  base="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  launcher="${GAME_LAUNCHER:-$base/game-launchers/${GAME_NAME}.sh}"
  apps_dir="${1:-${DESKTOP_SHORTCUT_DIR:-$HOME/.local/share/applications}}"
  mkdir -p "$apps_dir"
  cat > "$apps_dir/$GAME_NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$GAME_NAME
Exec="$launcher"
Terminal=false
Categories=Game;
EOF
  _log "Shortcut aangemaakt: $apps_dir/$GAME_NAME.desktop"
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
  _snapshot_backup
  if [ "${PROTON_ENABLED:-0}" != "1" ]; then
    command -v wineserver >/dev/null 2>&1 && wineserver -w 2>/dev/null
  fi
  if game_needs_provision; then
    game_provision
  else
    _log "Prefix is al geprovisiond (v$(cat "$MARKER"))."
  fi
  game_make_desktop
  game_launch "$@"
}