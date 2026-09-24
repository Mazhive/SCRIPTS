#!/bin/bash
# tools/pad-xinput-off.sh — LOSSE, handmatige ROOT-tool: maak de
# pad-xinput-activering (pad-xinput-on.sh) geheel ongedaan.
#
# Wat er teruggezet wordt:
#   1. udev-rule 70-pad-xinput.rules wordt verwijderd (+ reload/trigger),
#   2. de kernel-xpad-driver claimt de pad weer (evdev/joy terug; de
#      hidraw-node die usbhid tijdelijk maakte verdwijnt daarmee),
#   3. einde: controle dat xpad geladen is en de pad geen leesbare
#      hidraw-node meer heeft.
#
# Bewust NIET erbij: SDL-/marker-schoonmaak van (prefix-)launchers — de
# toetsenbordmodus regelt de launch-time guard disable_winebus al (SDL=0).
#
# Vereist ROOT (zelfde zelf-gating als pad-xinput-on.sh). Wordt los gedraaid
# (of later via GUI). Idempotent: niets te ongedaan maken → nette melding en
# exit 0.
#
# Gebruik:
#   tools/pad-xinput-off.sh          – weerstand terug naar kernel-xpad
#   tools/pad-xinput-off.sh status   – lees-only wat er vandaag aan staat
#
# Env-overschrijvingen: PAD_VID, PAD_PID.
set -u

PAD_VID="${PAD_VID:-045e}"
PAD_PID="${PAD_PID:-028e}"
UDEV_RULE_FILE="/etc/udev/rules.d/70-pad-xinput.rules"

say()  { printf '%s\n' "$*"; }
die()  { printf 'FOUT: %s\n' "$*" >&2; exit 1; }
ok()   { printf '%s\n' "  ✓ $*"; }
info() { printf '%s\n' "  ... $*"; }

pad_usb() { lsusb -d "$PAD_VID:$PAD_PID" 2>/dev/null; }
xpad_loaded() { lsmod 2>/dev/null | grep -q '^xpad '; }

find_pad_node() {
  local h v m
  for h in /dev/hidraw*; do
    [ -e "$h" ] || continue
    v="$(udevadm info --query=property --name="$h" 2>/dev/null | sed -n 's/^ID_VENDOR_ID=//p' | head -1)"
    m="$(udevadm info --query=property --name="$h" 2>/dev/null | sed -n 's/^ID_MODEL_ID=//p' | head -1)"
    if [ "$v" = "$PAD_VID" ] && [ "$m" = "$PAD_PID" ]; then
      echo "$h"; return 0
    fi
  done
  return 1
}

need_root() {
  [ "$(id -u)" -eq 0 ] && return 0
  if command -v sudo >/dev/null 2>&1; then
    exec sudo -E "$0" "$@"
  elif command -v pkexec >/dev/null 2>&1; then
    exec pkexec "$0" "$@"
  fi
  die "dit script vereist root; start het met sudo/pkexec (of installeer sudo)."
}

cmd_status() {
  local node
  say "udev-rule  : $([ -f "$UDEV_RULE_FILE" ] && echo "JA ($UDEV_RULE_FILE)" || echo 'nee')"
  say "xpad-load  : $([ "$(xpad_loaded && echo ja)" ] && echo 'JA (pad bij de kernel-driver)' || echo 'nee')"
  if node="$(find_pad_node)"; then
    say "pad hidraw : ${node}  ($(stat -c '%A' "$node"))  → pad staat nog OPEN als XInput"
  else
    say "pad hidraw : (geen node) → pad terug bij xpad/evdev"
  fi
}

cmd_off() {
  need_root "$@"

  if [ -f "$UDEV_RULE_FILE" ]; then
    info "udev-rule weg: $UDEV_RULE_FILE"
    rm -f "$UDEV_RULE_FILE" || die "verwijderen van $UDEV_RULE_FILE mislukt."
    udevadm control --reload-rules || die "udevadm control --reload-rules mislukt."
    udevadm trigger >/dev/null 2>&1
  else
    info "geen udev-rule aanwezig (of via --shot: perm vervalt ook bij replug/reboot)."
  fi

  if ! xpad_loaded; then
    info "xpad-driver laden → pad terug onder kernel-xpad (evdev/joy)"
    modprobe xpad || die "modprobe xpad mislukt."
    udevadm trigger >/dev/null 2>&1
    for _ in 1 2 3 4; do
      xpad_loaded && break
      sleep 1
    done
  else
    info "xpad-driver al geladen."
  fi

  if pad_usb >/dev/null && find_pad_node; then
    die "pad heeft tóch nog een leesbare hidraw-node. Zet de pad er 1 sec uit en probeer opnieuw."
  fi
  ok "klaar: pad terug bij kernel-xpad; toetsenbordmodus is/is blijft actief (guard SDL=0)."
}

case "${1:-}" in
  status) cmd_status ;;
  off|"") cmd_off "$@" ;;
  -h|--help) sed -n '2,18p' "$0" ;;
  *) echo "gebruik: $0 [status | off]" >&2; exit 2 ;;
esac