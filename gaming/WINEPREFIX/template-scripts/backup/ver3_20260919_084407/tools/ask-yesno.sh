#!/bin/bash
# ask-yesno.sh — Herbruikbare Ja/Nee-vraag voor terminal én desktop.
#
# Los, generiek script: elke andere script-runner (ensure-proton.sh, en straks
# de Python-GUI, installatiekeuzes, enz.) kan hiermee een bevestiging vragen
# zonder zelf dialoog-logica te dupliceren.
#
# Methode-volgorde (eerst wat werkt, dan wat kan):
#   1. TTY aanwezig              → tekstprompt in de terminal [j/N]
#   2. Displaysessie + kdialog   → KDE-stijl dialoogvenster
#   3. Displaysessie + zenity    → GTK-dialoogvenster
#   4. Displaysessie + notify-send → alleen een melding (geen knoppen)
#   Anders                        → faalt met instructie
# Een dialoogvenster heeft ALTIJD de focus; de actieve optie is "Nee".
#
# Gebruik:
#   ask-yesno.sh --title "Proton ontbreekt" --message "GE-Proton installeren?"
#   ask-yesno.sh --message "Opnieuw proberen?" --default-true
#
# Exit-status:
#   0  → "Ja"
#   1  → "Nee" / geannuleerd / venster gesloten
#   2  → geen enkele interactieve methode beschikbaar (tekst + melding op stderr)

set -u

TITLE="Bevestiging"
MESSAGE=""
DEFAULT_YES=0

# ── Hulp ─────────────────────────────────────────────────────
usage() {
  echo "Gebruik: ask-yesno.sh --title TITEL --message BERICHT [--default-true]"
  echo "         Fout/melding via stderr; exit 0=ja, 1=nee, 2=geen methode."
}

while [ $# -gt 0 ]; do
  case "$1" in
    --title)     TITLE="${2:?--title vereist een argument}"; shift 2 ;;
    --message)   MESSAGE="${2:?--message vereist een argument}"; shift 2 ;;
    --default-true) DEFAULT_YES=1; shift ;;
    --help|-h)   usage; exit 0 ;;
    *) echo " [ask-yesno] Onbekend argument: $1 (zie --help)" >&2; exit 2 ;;
  esac
done

[ -n "$MESSAGE" ] || { echo " [ask-yesno] --message is verplicht (zie --help)" >&2; exit 2; }

# ── Methode 1: tekstprompt op een TTY ────────────────────────
if [ -t 0 ]; then
  reply=""
  if [ "$DEFAULT_YES" -eq 1 ]; then
    printf " [ask-yesno] %s — %s [Y/n] " "$TITLE" "$MESSAGE"
  else
    printf " [ask-yesno] %s — %s [j/N] " "$TITLE" "$MESSAGE"
  fi
  read -r reply
  case "$reply" in
    j|J|y|Y|ja|Ja|JA|yes)  exit 0 ;;
    *)                     exit 1 ;;
  esac
fi

# ── Methode 2/3: dialoogvenster op een displaysessie ─────────
if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  if command -v kdialog >/dev/null 2>&1; then
    kdialog --title "$TITLE" --yesno "$MESSAGE"
    exit $?
  fi
  if command -v zenity >/dev/null 2>&1; then
    zenity --question --title="$TITLE" --text="$MESSAGE" --width=400
    exit $?
  fi
  # Methode 4: melding zonder keuze-knoppen — kan niet bevestigen.
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "$TITLE" "$MESSAGE"
  fi
fi

# ── Geen enkele methode: kan niet vragen, dus ook niet akkoord ─
echo " [ask-yesno] Kan geen Ja/Nee-vraag stellen: geen terminal en geen" >&2
echo " [ask-yesno] kdialog/zenity-notify-send-displaysessie beschikbaar." >&2
echo " [ask-yesno] Voer het aanroepende script handmatig uit in een terminal." >&2
exit 2