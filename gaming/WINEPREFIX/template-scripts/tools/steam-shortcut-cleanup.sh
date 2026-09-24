#!/bin/bash
# ---------------------------------------------------------------------------
# steam-shortcut-cleanup.sh — verwijder een non-Steam-shortcut UIT Steam.
#
# Steam slaat non-Steam-shortcuts op in een BINAIR KeyValues-bestand:
#   ~/.steam/steam/userdata/<account>/config/shortcuts.vdf
# Dit bestand is binair (geen tekst-VDF), vandaar dat we de beproefde
# `vdf`-pythonbibliotheek gebruiken (is al op deze machine: /usr/lib/python3/
# dist-packages/vdf) — én die byte-exact rond schrijft (geverifieerd op dit
# bestand: roundtrip 10499==10499)). Writen gebeurt alleen na:
#   - een roundtrip-bewijs (load→dump == origineel) en
#   - een backup ernaast, en
#   - de Steam-client die gesloten is (anders overschrijft Steam de write).
#
# Doel: "vastzittende" non-Steam-shortcuts opruimen (bv. na de
# Forza/non-Steam-fusie, zoals de Forza Horizon 5 entry #20 die hierin stond).
#
# Gebruik:
#   steam-shortcut-cleanup.sh list                     → alle shortcuts (tabel)
#   steam-shortcut-cleanup.sh verify                   → parse+roundtrip-bewijs
#   steam-shortcut-cleanup.sh remove <naam-of-exe>     → DROOG: toont match(es)
#   steam-shortcut-cleanup.sh remove <naam-of-exe> --commit [--force] [--file <vdf>]
#   --commit  → écht wegschrijven (zonder dit vlag blijft het een droge run)
#   --force   → negeert de "Steam draait nog"-weigering
#   --file    → een ander shortcuts.vdf (bv. een testkopie)
#
# Exit-codes: 0 ok · 2 usage · 3 weigering/geen match · 4 dry-run (niets geschreven)
# ---------------------------------------------------------------------------

set -u

_usage() {
    echo "Gebruik: $(basename "$0") <list|verify|remove <naam-of-exe>> [--commit] [--force] [--file <vdf>]" >&2
    exit 2
}

STEAM_RUNNING() { pgrep -x steam >/dev/null 2>&1 || pgrep -x steamwebhelper >/dev/null 2>&1; }

VDF=""
ACTION=""
NEEDLE=""
COMMIT="0"
FORCE="0"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --file) [ "$#" -ge 2 ] || _usage; VDF="$2"; shift 2 ;;
        --commit) COMMIT="1"; shift ;;
        --force) FORCE="1"; shift ;;
        list) ACTION="list"; shift ;;
        verify) ACTION="verify"; shift ;;
        remove)
            ACTION="remove"; [ "$#" -ge 2 ] || _usage; NEEDLE="$2"; shift 2
            ;;
        *) _usage ;;
    esac
done
[ -n "$ACTION" ] || _usage

# ---------------------------------------------------------------------------
# VDF-bestand zoeken
# ---------------------------------------------------------------------------
if [ -z "$VDF" ]; then
    mapfile -t CAND < <(find "$HOME/.steam/steam/userdata" -maxdepth 3 \
        -path '*/userdata/*/config/shortcuts.vdf' -type f 2>/dev/null)
    if [ "${#CAND[@]}" -eq 0 ]; then
        echo "FOUT: geen shortcuts.vdf gevonden onder ~/.steam/steam/userdata" >&2
        exit 3
    fi
    [ "${#CAND[@]}" -eq 1 ] || {
        echo "FOUT: meerdere shortcuts.vdf gevonden:" >&2
        printf '  %s\n' "${CAND[@]}" >&2
        echo "Gebruik --file om er een te kiezen." >&2
        exit 3
    }
    VDF="${CAND[0]}"
fi
[ -r "$VDF" ] || { echo "FOUT: niet leesbaar: $VDF" >&2; exit 3; }

REAL_VDF="0"
case "$VDF" in
    "$HOME/.steam"*) REAL_VDF="1" ;;
esac

# ---------------------------------------------------------------------------
# Python-hulpmotoren (gebruikt de `vdf`-bibliotheek; alleen stdlib-afhankelijk)
# ---------------------------------------------------------------------------
PY_PROG='import sys, io, vdf

def load(vdf_path):
    return vdf.binary_load(io.BytesIO(open(vdf_path, "rb").read()))

def dump_bytes(kv):
    buf = io.BytesIO()
    vdf.binary_dump(kv, buf)
    return buf.getvalue()

def roundtrip_ok(vdf_path, kv):
    return dump_bytes(kv) == open(vdf_path, "rb").read()

def entries(kv):
    return kv.get("shortcuts", {}).items()

def find_all(kv, needle):
    needle = needle.casefold()
    hits = []
    for key, v in entries(kv):
        if not isinstance(v, dict):
            continue
        name = str(v.get("AppName", ""))
        exe = str(v.get("Exe", ""))
        if needle in name.casefold() or needle in exe.casefold():
            hits.append((key, name, exe, v.get("appid")))
    return hits

def main():
    mode, vdfp = sys.argv[1], sys.argv[2]
    kv = load(vdfp)
    if not roundtrip_ok(vdfp, kv):
        print("FOUT: roundtrip-bewijs mislukt; bestand is niet herschrijfbaar-stabiel", file=sys.stderr)
        return 3

    if mode == "verify":
        print("OK: %d shortcut(s); roundtrip byte-exact; bestand %d bytes"
              % (len(entries(kv)), len(open(vdfp, "rb").read())))
        return 0

    if mode == "list":
        print("%-4s %-14s %-28s %s" % ("idx", "appid", "naam", "exe"))
        for key, v in entries(kv):
            if not isinstance(v, dict):
                continue
            print("%-4s %-14s %-28s %s"
                  % (key, v.get("appid"), str(v.get("AppName", ""))[:28], v.get("Exe", "")))
        return 0

    needle = sys.argv[3]
    hits = find_all(kv, needle)

    if not hits:
        print("Geen matches gevonden voor '%s' van %d shortcut(s)."
              % (needle, len(entries(kv))))
        return 3
    if len(hits) > 1:
        print("FOUT: %d matches voor '%s' — weiger; verfijn de naam/exe:" % (len(hits), needle))
        for key, name, exe, appid in hits:
            print("   key '%s' | appid %s | %s | %s" % (key, appid, name, exe))
        return 3

    key, name, exe, appid = hits[0]
    if mode == "match":
        print("EEN match: key '%s' | appid %s | %s | %s" % (key, appid, name, exe))
        return 0

    if mode == "remove":
        removed = kv["shortcuts"].pop(key)
        new_out = dump_bytes(kv)
        tmp = vdfp + ".new"
        with open(tmp, "wb") as f:
            f.write(new_out)
        import os
        os.replace(tmp, vdfp)
        print("VERWIJDERD: '%s' (key %s) uit %s; nog %d shortcut(s) over."
              % (name, key, vdfp, len(entries(kv))))
        print("TIP: herstart Steam om de client te laten herlezen. Terugzetten: cp <bak> shortcuts.vdf.")
        return 0

    return 2

if __name__ == "__main__":
    sys.exit(main())
'

run_py() { python3 - "$@" <<<"$PY_PROG"; }

# ---------------------------------------------------------------------------
# list / verify
# ---------------------------------------------------------------------------
case "$ACTION" in
    list)
        run_py list "$VDF" || { echo "FOUT: kan shortcuts.vdf niet lezen/parsen (vdf-module? leespermissie?)" >&2; exit 3; }
        exit 0
        ;;
    verify)
        run_py verify "$VDF" || { echo "FOUT: VDF is niet stabiel herschrijfbaar." >&2; exit 3; }
        exit 0
        ;;
esac

# ---------------------------------------------------------------------------
# remove
# ---------------------------------------------------------------------------
[ "$ACTION" = "remove" ] || _usage

if [ "$COMMIT" != "1" ]; then
    echo "== dry-run (geen write): matches voor '%s' ==" "$NEEDLE"
    run_py match "$VDF" "$NEEDLE"; rc=$?
    case "$rc" in
        0) echo "Voor daadwerkelijke verwijdering: nogmaals met --commit." ;;
        3) echo "Geen match — er valt niets te verwijderen." ;;
        *) exit "$rc" ;;
    esac
    exit 4
fi

if [ "$REAL_VDF" = "1" ] && STEAM_RUNNING && [ "$FORCE" != "1" ]; then
    echo "FOUT: Steam draait nog — een write wordt bij client-afsluiting overschreven." >&2
    echo "Sluit Steam eerst, of gebruik --force met deze consequentie." >&2
    exit 3
fi
[ "$REAL_VDF" = "1" ] && STEAM_RUNNING && [ "$FORCE" = "1" ] && \
    echo "WAARSCHUWING: --force terwijl Steam draait; write kan verloren gaan."

BAK="${VDF}.bak-$(date +%Y%m%dT%H%M%S)"
cp -p -- "$VDF" "$BAK" || { echo "FOUT: backup mislukt ($BAK)" >&2; exit 3; }
echo "backup: $BAK"

run_py remove "$VDF" "$NEEDLE"; rc=$?
exit "$rc"