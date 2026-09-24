#!/bin/bash
# ---------------------------------------------------------------------------
# steam-nonsteam-fix.sh — maak een non-Steam-gamemap Steam-fusie-veilig.
#
# Achtergrond (zie README, sectie "Steam non-Steam-fusie"): een onbezeten
# echt store-appid in steam_appid.txt fuseert een Steam-shortcut met het
# store-appid en wordt door de license-gate afgebroken (exit -1, koop-nag).
# De omzeiling is eenvoudig: heat bestand neutraliseren (rename naar
# steam_appid.txt.disabled); de game valt dan terug op de bewezen
# pseudo-appid-route en Steam hoeft zelf NIET aangepast te worden.
#
# Deze tool raakt UITSLUITEND steam_appid.txt[.disabled] in de opgegeven
# gamemap — launcher-scripts worden nooit aangeraakt (die voeden de appid
# al via env STEAM_APPID voor Proton/ProtonFixes).
#
# Acties:
#   inspect  <gamemap>          → alleen lezen: status + risico-score
#   neutralise <gamemap>        → rename steam_appid.txt → .disabled
#   restore  <gamemap>          → rename .disabled → steam_appid.txt
#   fake     <gamemap> [--appid N] → (her)schrijf steam_appid.txt met een
#                                  gegenereerde stabiele cijfer-appid uit de
#                                  mapnaam (standaard 8 cijfers via
#                                  appid.fromname.sh); met --appid expliciet.
#                                  Bestaand originaal wordt eerst naar
#                                  .disabled verplaatst (behouden).
#   scan     [rootmap]          → scan hele collectie (default: de
#                                  WINDOWSGAMES-map naast dit pakket):
#                                  conflict-dragers + emu-profielen.
#
# Opties (globaal):
#   --dry-run                   → toon alleen wat er zou gebeuren
#   --len <n>                   → cijferlengte voor fake (default 8)
#
# Exit-codes: 0 ok/idempotent · 2 usage · 3 weigering/onveilig · 4 dry-run
# ---------------------------------------------------------------------------

set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NUMERATOR="$SELF_DIR/appid.fromname.sh"
DEFAULT_ROOT="$(cd "$SELF_DIR/../../.." && pwd)/WINDOWSGAMES"

DRY="0"
LEN="8"
APPID_OVERRIDE=""

_usage() {
    echo "Gebruik: $(basename "$0") <inspect|neutralise|restore|fake|scan> <gamemap> [opties]" >&2
    echo "  opties: --dry-run | --appid <getal> | --len <n>" >&2
    exit 2
}

_weiger() { echo "FOUT: $*" >&2; exit 3; }

_actie_voorstel() {
    # $1 = beschrijving; rest = droge melding
    if [ "$DRY" = "1" ]; then
        echo "[dry-run] Zou: $1"
        return 4
    fi
    shift
    echo "> $1"
    return 10
}

_msg() { echo "  $*"; }

# ---------------------------------------------------------------------------
# output: <status>|<dlls>  met status = active | disabled | "" (geen)
boom_status() {
    local dir="$1"
    local st="" active disabled dlls
    active=""; disabled=""; dlls=""
    [ -e "$dir/steam_appid.txt" ] && active="ja"
    [ -e "$dir/steam_appid.txt.disabled" ] && disabled="ja"
    if [ "$active" = "ja" ]; then
        st="active"
    elif [ "$disabled" = "ja" ]; then
        st="disabled"
    fi
    for d in steam_api.dll steam_api64.dll steamclient.dll; do
        [ -f "$dir/$d" ] && dlls="$dlls $d"
    done
    echo "$st|$dlls"
}

boom_risico() {
    # $1 = active|disabled|geen ; $2 = inhoud
    local st="$1" c="$2"
    case "$st" in
        active)
            if [[ "$c" =~ ^[0-9]{1,10}$ ]]; then
                echo "RISICO: conflict-drager — numeriek store-appid ($c) aanwezig; Steam fuseert non-Steam-shortcuts ermee zolang je het appid niet bezit → neutraliseer."
            elif [ -z "$c" ]; then
                echo "leeg bestand aanwezig (geen numeriek appid) — laag risico; neutraliseer voor de zekerheid."
            else
                echo "niet-numerieke inhoud ('$c') — Steam leest er geen appid uit; laag risico."
            fi
            ;;
        disabled)
            echo "genentraliseerd (.disabled aanwezig) — veilig; restore eventueel om terug te zetten."
            ;;
        *)
            echo "geen steam_appid.txt — veilig (pseudo-appid-route, zoals de werkende shortcuts)."
            ;;
    esac
}

inspect() {
    local dir="$1"
    local st=""
    local c="" rest=""
    [ -d "$dir" ] || _weiger "gamemap bestaat niet: $dir"
    IFS='|' read -r st rest <<< "$(boom_status "$dir")"
    echo "Gamemap: $dir"
    if [ "$st" = "active" ]; then
        c="$(tr -d '\r\n' < "$dir/steam_appid.txt")"
        echo "  steam_appid.txt: aanwezig ($(wc -c < "$dir/steam_appid.txt") bytes, inhoud '$c')"
    elif [ "$st" = "disabled" ]; then
        echo "  steam_appid.txt.disabled: aanwezig (gegen neutraaliseerde/opgeborgen versie)"
    else
        echo "  steam_appid.txt: afwezig"
    fi
    echo "  risico: $(boom_risico "$st" "$c")"
    [ -n "$rest" ] && echo "  emu/steamworks-bibliotheken:${rest}"
    echo "  launchers blijven onaangeraakt (appid loopt via env STEAM_APPID)."
}

neutralise() {
    local dir="$1"
    local src="$dir/steam_appid.txt"
    local dst="$dir/steam_appid.txt.disabled"
    [ -d "$dir" ] || _weiger "gamemap bestaat niet: $dir"
    if [ -e "$src" ]; then
        if [ -e "$dst" ]; then
            _weiger "zowel steam_appid.txt als .disabled bestaan — bepaal zelf welke versie gewenst is."
        fi
        if [ "$DRY" = "1" ]; then
            _actie_voorstel "steam_appid.txt → steam_appid.txt.disabled ($dir)"
            exit 4
        fi
        mv -- "$src" "$dst" || _weiger "rename mislukt"
        echo "> Gencentraliseerd: steam_appid.txt → steam_appid.txt.disabled"
    elif [ -e "$dst" ]; then
        echo "  al gencentraliseerd (alleen .disabled aanwezig) — veilig."
    else
        echo "  geen steam_appid.txt aanwezig — veilig, niets te doen."
    fi
}

restore() {
    local dir="$1"
    local src="$dir/steam_appid.txt.disabled"
    local dst="$dir/steam_appid.txt"
    [ -d "$dir" ] || _weiger "gamemap bestaat niet: $dir"
    if [ -e "$src" ]; then
        if [ -e "$dst" ]; then
            _weiger "zowel steam_appid.txt als .disabled bestaan — verkies handmatige keuze."
        fi
        if [ "$DRY" = "1" ]; then
            _actie_voorstel "steam_appid.txt.disabled → steam_appid.txt ($dir)"
            exit 4
        fi
        mv -- "$src" "$dst" || _weiger "rename mislukt"
        echo "> Hersteld: steam_appid.txt.disabled → steam_appid.txt"
    elif [ -e "$dst" ]; then
        echo "  steam_appid.txt staat er al — niets te herstellen."
    else
        echo "  geen .disabled aanwezig — niets te herstellen."
    fi
}

fake() {
    local dir="$1"
    local appid="$APPID_OVERRIDE"
    local src="$dir/steam_appid.txt"
    local dst="$dir/steam_appid.txt.disabled"
    [ -d "$dir" ] || _weiger "gamemap bestaat niet: $dir"
    if [ -z "$appid" ]; then
        [ -x "$NUMERATOR" ] || _weiger "appid.fromname.sh niet aangetroffen naast dit script"
        appid="$("$NUMERATOR" "$(basename "$dir")" "$LEN")" || _weiger "kon geen appid genereren uit '$(basename "$dir")'"
    fi
    if ! [[ "$appid" =~ ^[0-9]{1,10}$ ]]; then
        _weiger "appid moet een numerieke reeks zijn (kreeg: '$appid')"
    fi
    if [ -e "$src" ] && [ -e "$dst" ]; then
        _weiger "zowel steam_appid.txt als .disabled aanwezig — geen veilige fake-write."
    fi
    if [ "$DRY" = "1" ]; then
        echo "[dry-run] Zou: steam_appid.txt schrijven met appid '$appid' in $dir"
        [ -e "$src" ] && echo "[dry-run]   (bestaande steam_appid.txt eerst naar .disabled verplaatst)"
        exit 4
    fi
    if [ -e "$src" ]; then
        mv -- "$src" "$dst" && echo "> oorspronkelijke steam_appid.txt opgeborgen als .disabled"
    fi
    printf '%s\n' "$appid" > "$dir/steam_appid.txt" || _weiger "write mislukt"
    echo "> steam_appid.txt geschreven met (fake) appid '$appid'"
}

scan() {
    local root="${1:-$DEFAULT_ROOT}"
    [ -d "$root" ] || _weiger "scamoot  bestaat niet: $root"
    echo "Scan collectie onder: $root"
    local f st c rest dragers=0
    while IFS= read -r -d '' f; do
        b="$(basename "$f")"
        c="$(tr -d '\r\n' < "$f")"
        st="active"
        rest="$(boom_status "$(dirname "$f")" | cut -d'|' -f2)"
        printf '%-45s %-10s %-12s %s\n' "$b" "appid='$c'" "${rest:+emu:${rest// /,}}" "$(boom_risico "$st" "$c")"
        dragers=$((dragers+1))
    done < <(find "$root" -maxdepth 2 -name steam_appid.txt -print0)
    if [ "$dragers" -eq 0 ]; then
        echo "Geen steam_appid.txt gevonden — hele collectie is fusie-veilig."
    fi
}

# ---------------------------------------------------------------------------

# Globale opties vóór de actie schrappen
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) DRY="1"; shift ;;
        --len) [ "$#" -ge 2 ] || _usage; LEN="$2"; shift 2 ;;
        --appid) [ "$#" -ge 2 ] || _usage; APPID_OVERRIDE="$2"; shift 2 ;;
        *) break ;;
    esac
done
[ "$#" -ge 1 ] || _usage

ACTIE="$1"; shift

if ! [[ "$LEN" =~ ^[1-9][0-9]*$ ]]; then
    _weiger "lengte '$LEN' is geen positief geheel getal"
fi

case "$ACTIE" in
    inspect)   [ "$#" -eq 1 ] || _usage; inspect "$1" ;;
    neutralise) [ "$#" -eq 1 ] || _usage; neutralise "$1" ;;
    restore)   [ "$#" -eq 1 ] || _usage; restore "$1" ;;
    fake)      [ "$#" -eq 1 ] || _usage; fake "$1" ;;
    scan)      [ "$#" -le 1 ] || _usage; scan "${1:-}" ;;
    *)         _usage ;;
esac

exit 0