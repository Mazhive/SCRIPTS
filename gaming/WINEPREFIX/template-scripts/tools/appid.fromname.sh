#!/bin/bash
# ---------------------------------------------------------------------------
# appid.fromname.sh — spelnaam → stabiele, op cijfers gebaseerde fake-appid.
#
# Eigen bash-interpretatie van tools/appid.numerator.py (Tkinter-GUI voor een
# snel "letter → cijfer"-idee). De python-app wordt bewust NIET aangeraakt;
# dit script is de scriptbare/CLI-variant van hetzelfde algoritme:
#
#   1. Elke letter/spatie telt mee met een oplopende POSITIE (cijfers en
#      leestekens worden overgeslagen en verschuiven de positie NIET).
#   2. Per actief teken wordt een cijfer afgeleid via de digitaal-wortel van
#      de positie:  digit = (positie-1) % 9 + 1   ;  spatie -> 0.
#   3. De reeks wordt PRECIES LEN cijfers lang gemaakt:
#        - te kort  -> aanvullen met 0-en (rechts)
#        - te lang  -> vouwen/optellen vanaf het einde, telkens tegen een
#          positie die met de rest lengte % LEN wordt gekozen; elke som
#          wordt teruggebracht naar 1-9 (digitaal-wortel; 0 blijft 0).
#
# Resultaat is deterministisch: dezelfde naam geeft altijd dezelfde appid,
# en een "standaard"-appid (zoals Steam die schrijft) is een lange reeks
# cijfers — hier standaard 8.
#
# Gebruik:
#   appid.fromname.sh "<spelnaam>" [lengte]      (lengte default 8)
#   appid.fromname.sh -l 10 "<spelnaam>"
#   appid.fromname.sh -v "<spelnaam>"            (toont posities + reductie)
# ---------------------------------------------------------------------------

set -u

_usage() {
    echo "Gebruik: $(basename "$0") [-l <lengte>] [-v] <spelnaam>" >&2
    exit 2
}

LEN="8"
VERBOSE="0"

while [ "$#" -gt 0 ]; do
    case "$1" in
        -l)
            [ "$#" -ge 2 ] || _usage
            LEN="$2"; shift 2
            ;;
        -v)
            VERBOSE="1"; shift
            ;;
        -*)
            _usage
            ;;
        *)
            break
            ;;
    esac
done

# Maximaal twee positionele argumenten: <naam> [lengte]
[ "$#" -ge 1 ] && [ "$#" -le 2 ] || _usage
RAW="$1"
if [ "$#" -eq 2 ]; then
    LEN="$2"
fi

# LEN moet een positief geheel getal zijn (>=1)
if ! [[ "$LEN" =~ ^[1-9][0-9]*$ ]]; then
    echo "FOUT: lengte moet een positief geheel getal zijn (kreeg: '$LEN')" >&2
    exit 2
fi

RAW="$1"

# --- 1 + 2. positie-digitaalwortel per letter/spatie ----------------------
digits=()
positions=()
pos=1
i=0
length=${#RAW}
while [ "$i" -lt "$length" ]; do
    ch="${RAW:i:1}"
    if [ "$ch" = " " ]; then
        digits+=( 0 )
        positions+=( "[SPATIE]" )
        pos=$((pos + 1))
    elif [[ "$ch" =~ [A-Za-z] ]]; then
        d=$(( (pos - 1) % 9 + 1 ))
        digits+=( "$d" )
        positions+=( "${ch^^}(pos $pos→$d)" )
        pos=$((pos + 1))
    fi
    i=$((i + 1))
done

if [ "${#digits[@]}" -eq 0 ]; then
    echo "FOUT: geen letters of spaties gevonden in '$RAW'" >&2
    exit 2
fi

# --- 3. reductie naar precies LEN cijfers ---------------------------------
arr=( "${digits[@]}" )

if [ "${#arr[@]}" -lt "$LEN" ]; then
    while [ "${#arr[@]}" -lt "$LEN" ]; do
        arr+=( 0 )
    done
else
    while [ "${#arr[@]}" -gt "$LEN" ]; do
        last_val="${arr[-1]}"
        unset 'arr[-1]'
        idx=$(( ${#arr[@]} % LEN ))
        sum=$(( arr[idx] + last_val ))
        if [ "$sum" -eq 0 ]; then
            arr[idx]=0
        else
            arr[idx]=$(( (sum - 1) % 9 + 1 ))
        fi
    done
fi

out=""
for d in "${arr[@]}"; do
    out+="$d"
done

if [ "$VERBOSE" = "1" ]; then
    orig=""
    for d in "${digits[@]}"; do orig+="$d"; done
    echo "Naam: $RAW (${#digits[@]} tekens)"
    echo "Posities: ${positions[*]}"
    echo "Oorspronkelijke reeks: $orig"
fi

echo "$out"