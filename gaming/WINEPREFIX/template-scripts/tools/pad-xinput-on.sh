#!/bin/bash
# tools/pad-xinput-on.sh — LOSSE, handmatige ROOT-tool: maak de Xbox-pad
# beschikbaar als échte XInput-controller voor Wine/Proton-games.
#
# Auto-vervangt de SDL/winebus-route (cyberpunk_gamepad.sh, doodlopend bewezen):
# games als Ori (beide), Cyberpunk e.d. lezen ALLEEN XInput; wine bouwt zo'n
# controller device alleen uit een leesbare hidraw-node. Op deze machine heeft
# de pad (045e:028e) géén hidraw-node zolang de kernel-xpad-driver hem claimt
# en /dev/hidraw* root-only is. Dit script lost beide op.
#
# Vereist ROOT (zelf-gating via sudo/pkexec). Wordt bewust NIET door launchers
# aangeroepen: los draaien, of later via de GUI.
#
# Gebruik:
#   tools/pad-xinput-on.sh status          – lees-only overzicht op OS-niveau
#   tools/pad-xinput-on.sh                 – pad activeren (default: stabiel via
#                                             udev-rule 70-pad-xinput.rules)
#   tools/pad-xinput-on.sh --shot          – proef-run: alleen tijdelijke chmod 666
#                                             op de node (vervalt bij replug/reboot)
#
# Ongedaan maken: tools/pad-xinput-off.sh (zelfde uitvoering, als root).
#
# Env-overschrijvingen: PAD_VID, PAD_PID.
set -u

PAD_VID="${PAD_VID:-045e}"
PAD_PID="${PAD_PID:-028e}"
UDEV_RULE_FILE="/etc/udev/rules.d/70-pad-xinput.rules"

say()   { printf '%s\n' "$*"; }
die()   { printf 'FOUT: %s\n' "$*" >&2; exit 1; }
ok()    { printf '%s\n' "  ✓ $*"; }
info()  { printf '%s\n' "  ... $*"; }

pad_usb() { lsusb -d "$PAD_VID:$PAD_PID" 2>/dev/null; }

# vind de hidraw-node van de pad aan de hand van VID:PID uit udevadm
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

xpad_loaded() { lsmod 2>/dev/null | grep -q '^xpad '; }

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
  say "pad  USB   : $(pad_usb || echo 'NIET aangesloten')"
  if pad_usb >/dev/null; then
    say "xpad-load  : $([ "$(xpad_loaded && echo ja)" ] && echo 'JA (claimt de pad → geen hidraw)' || echo 'nee (pad vrij voor usbhid)')"
    local node
    node="$(find_pad_node)" && say "pad hidraw : ${node}  ($(stat -c '%A' "$node"))"
    say "udev-rule  : $([ -f "$UDEV_RULE_FILE" ] && echo "JA ($UDEV_RULE_FILE)" || echo 'nee (alleen perm-niveau via OS)')"
    say "→ status : $([ "$(find_pad_node)" ] && [ -r "$(find_pad_node)" ] && echo 'pad leesbaar voor peter → XInput beschikbaar voor wine' || echo 'pad NIET leesbaar → nog niet als XInput beschikbaar')"
  else
    say "→ status : pad los of onbekend; steek de ontvanger erin en probeer opnieuw."
  fi
}

cmd_on() {
  local shot=0
  [ "${1:-}" = "--shot" ] && shot=1

  need_root "$@"
  pad_usb >/dev/null || die "pad ($PAD_VID:$PAD_PID) niet gevonden op USB."

  local node
  node="$(find_pad_node)"
  if [ -z "$node" ]; then
    if xpad_loaded; then
      info "xpad-driver laadt de pad → uit: modprobe -r xpad"
      modprobe -r xpad || die "modprobe -r xpad mislukt (dmesg)."
      udevadm trigger >/dev/null 2>&1
    fi
    for _ in 1 2 3 4 5 6; do
      node="$(find_pad_node)" && break
      sleep 1
    done
  else
    info "pad heeft al een hidraw-node ($node); xpad-load niet van toepassing."
  fi
  [ -n "$node" ] || die "geen hidraw-node voor de pad na unload (usbhid bindt niet). Controleer: dmesg | tail"

  if [ "$shot" -eq 1 ]; then
    info "SHOT: tijdelijke permissie op $node (vervalt bij replug/reboot)"
    chmod 666 "$node" || die "chmod 666 $node mislukt."
  else
    info "stabiel: udev-rule $UDEV_RULE_FILE (MODE 0660, GROUP input, uaccess)"
    printf 'KERNEL=="hidraw*", ATTRS{idVendor}=="%s", ATTRS{idProduct}=="%s", MODE="0660", GROUP="input", TAG+="uaccess"\n' \
      "$PAD_VID" "$PAD_PID" > "$UDEV_RULE_FILE" || die "udev-rule schrijven mislukt."
    udevadm control --reload-rules || die "udevadm control --reload-rules mislukt."
    udevadm trigger >/dev/null 2>&1
  fi

  node="$(find_pad_node)" && [ -r "$node" ] || die "verificatie faalde: node niet leesbaar ($node)."
  ok "pad als XInput klaar: $node ($(stat -c '%A' "$node"))"
  say "  → sluit eerst alle games, dan: <game> via de launcher starten."
  say "  → straks ongedaan maken met root: tools/pad-xinput-off.sh"
}

case "${1:-}" in
  status) cmd_status ;;
  on)     shift 1; cmd_on "$@" ;;
  --shot) cmd_on --shot ;;
  -h|--help) sed -n '2,20p' "$0" ;;
  "")     cmd_on ;;
  *) echo "gebruik: $0 [status | on [--shot]]" >&2; exit 2 ;;
esac