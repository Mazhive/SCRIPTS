#!/bin/bash
# hook: wacom-detect — "fake controller"-detectie + winebus-inputfix.
#
# BEWAARD ALS HERBRUIKBARE MODULE. Voor Cyberpunk 2077 niet meer nodig:
# Test D bewees dat de Wacom onschuldig is (Enable SDL=0 + Wacom erin =
# toetsenbord en gamepad werken, óók bij keuze "Nee"). Cyberpunk gebruikt nu
# de stille provision-hook disable_winebus (alleen Enable SDL=0). Dit module
# blijft beschikbaar voor andere games/hosts die een interactieve detectie +
# Ja/Nee-keuze willen i.p.v. de stille fix.
#
# Module (game-core/hooks/), opgeroepen via
#   PRE_LAUNCH_HOOKS=("wacom-detect")   → bij ÉLKE start, vlak vóór de game
#   (of PROVISION_HOOKS=("wacom-detect") → alleen bij provision; de fix is
#    idempotent, dus pre-launch is de juiste plek)
# De launchers blijven dun: zij hoeven alleen de hooknaam te zetten.
#
# Waarom:
#   Sommige games (o.a. Cyberpunk 2077) zien een willekeurig
#   joystick-achtig apparaat als gamecontroller en zetten dan
#   muis+toetsenbord uit (bekende "Press SPACE"-deadinput). Op deze machine
#   zijn er twee van zulke "valse" joysticks:
#     - een Wacom-tablet die via joydev als /dev/input/js* wordt geëxposeerd
#       (VID 056a);
#     - de eigen USB-toetsenbord-js (bv. Lenovo 17ef:6099, ID_INPUT_KEY=1)
#       die joydev óók als js* aanmeldt. Die is er ALTIJD — "de Wacom-kabel
#       los trekken" is daardoor nooit genoeg.
#   Bewezen fix (2026-09, Cyberpunk op KDE Wayland): ALLEEN "Enable SDL"=0 in
#   de winebus-servicesleutel zetten. Hidraw blijft aan (DisableHidraw NIET
#   zetten — dat maakte voorheen óók alle echte gamepads onbruikbaar), zodat
#   echte gamepads via XInput/hidraw wél blijven werken. Met deze instelling
#   werken toetsenbord én gamepad tegelijk; SDL-env-hints
#   (SDL_GAMECONTROLLER_IGNORE_DEVICES e.d.) worden NIET door de game
#   gehonoreerd (getest), de registry-waarde wél.
#
# Interactie:
#   Via tools/ask-yesno.sh (TTY → kdialog → zenity). De toekomstige
#   Python-GUI neemt deze melding over en kan de keuze vooraf instellen
#   met WACOM_CHOICE=ja|nee (dan geen prompt).

# Fallback zodat deze module ook los bruikbaar is zonder game-common.sh.
command -v _log >/dev/null 2>&1 || _log() { echo " [wacom-detect] $*"; }

# Elke aanwezige Wacom (via by-id of udevadm op event-devices).
_wacom_present() {
  ls /dev/input/by-id/ 2>/dev/null | grep -qi 'wacom' && return 0
  local ev out
  for ev in /dev/input/event*; do
    [ -e "$ev" ] || continue
    out="$(udevadm info --query=property --name="$ev" 2>/dev/null)"
    printf '%s\n' "$out" | grep -qiE '(wacom|056a)' && return 0
  done
  return 1
}

# "Valse" joysticks vinden: js*-devices die NIET met een echte gamepad te
# maken hebben (Wacom-tablet, of een toetsenbord dat joydev als js* aanmeldt).
# Een echte gamepad heeft ID_INPUT_JOYSTICK=1 (met eventueel een eigen VID);
# de Wacom herkennen we op 056a, een toetsenbord-js op ID_INPUT_KEY / 17ef.
# Echo: regels "js-device (omschrijving)" per gevonden faak; niets als schoon.
_bogus_joysticks() {
  local dev out n=0
  for dev in /dev/input/js*; do
    [ -e "$dev" ] || continue
    out="$(udevadm info --query=property --name="$dev" 2>/dev/null)"
    if printf '%s\n' "$out" | grep -qiE '(wacom|056a)'; then
      echo "$dev (Wacom-tablet)"
      n=$((n + 1))
    elif printf '%s\n' "$out" | grep -qiE 'ID_INPUT_JOYSTICK=1'; then
      : # echte gamepad — laten werken
    elif printf '%s\n' "$out" | grep -qiE 'ID_INPUT_KEY=1|ID_VENDOR_ID=17ef|keyboard|kbd'; then
      echo "$dev (toetsenbord-js — altijd aanwezig)"
      n=$((n + 1))
    fi
  done
  return 0
}

# De bewezen fix: winebus "Enable SDL"=0, hidraw blijft gewoon aan.
_apply_fix() {
  local key='HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\winebus'
  local pfx="${PREFIX_PATH:-${WINEPREFIX:-}}"
  _log "hook(wacom-detect): Enable SDL=0 instellen (hidraw blijft aan — echte gamepads blijven werken)..."
  WINEPREFIX="$pfx" wine reg add "$key" \
    /v 'Enable SDL' /t REG_DWORD /d 0 /f >/dev/null 2>&1 || {
    _log "hook(wacom-detect): wine reg add mislukt."
    return 1
  }
  # Wine schrijft zijn registry pas weg als de wineserver stopt; de game leest
  # deze waarde bij de eerstvolgende launch — dus op disk flussen vóór start.
  WINEPREFIX="$pfx" wineserver -w 2>/dev/null || true
  local out
  out="$(WINEPREFIX="$pfx" wine reg query "$key" 2>/dev/null)"
  if echo "$out" | grep -qE 'Enable SDL.*0x0'; then
    _log "hook(wacom-detect): OK — Enable SDL=0 actief; toetsenbord én gamepad werken."
  else
    _log "hook(wacom-detect): 'Enable SDL' niet bevestigd — controleer de prefix-handmatig."
    return 1
  fi
}

hook_run() {
  local bogus
  bogus="$(_bogus_joysticks)"
  if [ -z "$bogus" ]; then
    _log "hook(wacom-detect): geen fake-controller gevonden; niets te doen."
    return 0
  fi

  echo " ⚠️  Fake-controller gedetecteerd — de game ziet dit als 'gamepad'" >&2
  echo "     en negeert dan toetsenbord + muis." >&2
  echo "$bogus" | sed 's/^/     - /' >&2
  echo "     Oplossing: winebus 'Enable SDL' uitzetten (toetsenbord én" >&2
  echo "     je echte gamepad blijven allebei werken)." >&2

  # Keuze: Ja = inputfix toepassen; Nee = spel start zonder fix.
  # WACOM_CHOICE overslaat de prompt (voor de latere Python-GUI).
  local choice="${WACOM_CHOICE:-}"
  if [ -z "$choice" ]; then
    local ask tool_root
    tool_root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
    ask="$tool_root/tools/ask-yesno.sh"
    if [ -x "$ask" ]; then
      if "$ask" --title "Fake-controller gevonden" \
           --message "De game ziet een Wacom/toetsenbord als gamepad (toetsenbord uit). Winebus-fix inschakelen zodat toetsenbord én gamepad werken?"; then
        choice="ja"
      else
        choice="nee"
      fi
    else
      _log "hook(wacom-detect): tools/ask-yesno.sh ontbreekt — fix automatisch toepassen."
      choice="ja"
    fi
  fi

  case "$choice" in
    ja)
      _apply_fix
      ;;
    *)
      _log "hook(wacom-detect): fix overgeslagen (gedrag ongewijzigd)."
      ;;
  esac
  return 0
}