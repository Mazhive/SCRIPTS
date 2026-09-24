#!/bin/bash
# ensure-proton.sh — Poortwachter: zorgt dat de door de game vereiste
# Proton-runner aanwezig is (of geïnstalleerd wordt), met Ja/Nee-keuze.
#
# Beroepbaar door game-common.sh (game_launch) en los (bv. de Python-GUI).
# Vereisten van de game volgen uit zijn eigen bekende data:
#   PROTON_PIN="GE-Proton11-7"  → die exacte versie wordt gegarandeerd.
#   geen PROTON_PIN             → willekeurige runner/goedwerkend alternatief.
#
# Kerngedrag: er is GEEN stille downgrade. Mist een gepinde versie, dan
# vraagt het script (via tools/ask-yesno.sh) of die versie nu geïnstalleerd
# mag worden; "Nee"/annuleren stopt de game (exit 1). Pas zónder PIN wordt
# een willekeurige aanwezige runner geaccepteerd, en zonder welke runner dan
# ook wordt installatie van de nieuwste gevraagd.
#
# Gebruik:
#   ensure-proton.sh                        → respecteert PROTON_PIN uit env
#   PROTON_PIN=GE-Proton11-7 ensure-proton.sh
#
# Exit-status:
#   0 → er is (nu) een Proton-runner beschikbaar die voldoet
#   1 → gebruiker geannuleerd, of installatie/detectie mislukt
#
# Terugvalmethode voor de keuzevraag (zie ask-yesno.sh):
# TTY→tekstprompt; daarna kdialog→zenity→notify-send (melding, faalt).

set -u

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$_here/../game-core/game-common.sh" 2>/dev/null || {
  echo " [ensure-proton] FOUT: kan game-common.sh niet laden vanaf $_here/../game-core/" >&2
  exit 1
}

_ep_log()  { echo " [ensure-proton] $*"; }
_ep_fail() { echo " [ensure-proton] FOUT: $*" >&2; exit 1; }

GAME_LABEL="${GAME_NAME:-Deze game}"
ASK="$_here/ask-yesno.sh"

# ── PROTON_PIN gezet: exacte versie garanderen ───────────────
if [ -n "${PROTON_PIN:-}" ]; then
  if _detect_pinned_proton >/dev/null 2>&1; then
    _ep_log "$GAME_LABEL: vereiste '$PROTON_PIN' is al aanwezig."
    exit 0
  fi

  _ep_log "$GAME_LABEL vereist '$PROTON_PIN', maar die is niet gevonden."
  BODY="$GAME_LABEL heeft Proton-versie '$PROTON_PIN' nodig om te starten, maar die is niet geïnstalleerd.

Wil je '$PROTON_PIN' nu downloaden en installeren?
(Kies je 'Nee', dan kan $GAME_LABEL niet starten.)"
  "$ASK" --title "Proton ontbreekt: $PROTON_PIN" --message "$BODY"
  answer=$?

  if [ "$answer" -eq 2 ]; then
    _ep_fail "Kan geen Ja/Nee-vraag stellen (geen terminal/dialoog). Installeer '$PROTON_PIN' handmatig via: $_here/install-proton.sh --pin '$PROTON_PIN'"
  fi
  if [ "$answer" -ne 0 ]; then
    _ep_log "Installatie geannuleerd door gebruiker. $GAME_LABEL kan niet starten zonder '$PROTON_PIN'."
    exit 1
  fi

  _ep_log "Installatie gestart: $_here/install-proton.sh --pin '$PROTON_PIN'"
  if ! "$_here/install-proton.sh" --pin "$PROTON_PIN"; then
    _ep_fail "Installatie van '$PROTON_PIN' is mislukt. Zie bovenstaande foutmelding."
  fi

  if _detect_pinned_proton >/dev/null 2>&1; then
    _ep_log "Installatie geslaagd: '$PROTON_PIN' is nu aanwezig."
    exit 0
  fi
  _ep_fail "Na installatie nog steeds geen '$PROTON_PIN' gevonden. Controleer $_here/install-proton.sh handmatig."
fi

# ── Geen PIN: voldoet een willekeurige runner, anders nieuwste installeren ─
if _detect_proton >/dev/null 2>&1; then
  _ep_log "Proton-runner al aanwezig, geen installatie nodig."
  exit 0
fi

_ep_log "$GAME_LABEL heeft Proton nodig, maar er is geen enkele runner gevonden."
BODY="$GAME_LABEL heeft Proton nodig om te starten, maar er is geen Proton-runner gevonden.

Wil je GE-Proton nu automatisch installeren?
(Kies je 'Nee', dan kan $GAME_LABEL niet starten.)"
if ! "$ASK" --title "Proton ontbreekt" --message "$BODY"; then
  _ep_log "Installatie geannuleerd of niet mogelijk. $GAME_LABEL kan niet starten zonder Proton."
  exit 1
fi

_ep_log "Installatie gestart: $_here/install-proton.sh (nieuwste)"
if ! "$_here/install-proton.sh"; then
  _ep_fail "install-proton.sh is mislukt. Zie bovenstaande foutmelding."
fi

if _detect_proton >/dev/null 2>&1; then
  _ep_log "Installatie geslaagd, Proton-runner gevonden."
  exit 0
fi
_ep_fail "Na installatie nog steeds geen Proton-runner gevonden. Controleer $_here/install-proton.sh handmatig."