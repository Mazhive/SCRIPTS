#!/bin/bash
# install-proton.sh — Installeert de nieuwste GE-Proton voor de game-launchers.
#
# Downloadt GE-Proton van GitHub (GloriousEggroll/proton-ge-custom) en pakt
# het uit in de compatibilitytools.d van een gevonden Steam-installatie
# (native, .deb, of ~/.local/share/Steam) zodat de versie ook rechtstreeks
# in Steam zelf (Instellingen > Compatibiliteit) zichtbaar en bruikbaar is.
# Is er geen Steam-installatie gevonden, dan valt het terug op de
# Heroic-layout ($HOME/.config/heroic/tools/proton/) — game-common.sh scant
# beide locaties.
#
# Gebruik:
#   install-proton.sh                 → installeer de nieuwste release
#   PROTON_VERSION=GE-Proton11-7 \
#       install-proton.sh             → die specifieke versie installeren
#   install-proton.sh --pin GE-Proton11-7   → idem
#
# Na installatie maakt het script een GUI-snelkoppeling aan:
#   ~/.local/share/applications/InstallProton.desktop

set -euo pipefail

API_URL="https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest"
FALLBACK_VERSION="GE-Proton11-7"
DEST_DESKTOP="$HOME/.local/share/applications/InstallProton.desktop"
TMP_DIR="${TMPDIR:-/tmp}/${$}_proton"

# ── Installatie-doel bepalen: eerste gevonden Steam-flavor's
# compatibilitytools.d, anders Heroic-layout als terugval. ─────
_steam_root() {
  local dir
  for dir in \
    "$HOME/.steam/steam" \
    "$HOME/.steam/debian-installation" \
    "$HOME/.local/share/Steam"; do
    [ -d "$dir" ] && { echo "$dir"; return 0; }
  done
  return 1
}

if STEAM_ROOT="$(_steam_root)"; then
  DEST_INSTALL_ROOT="$STEAM_ROOT/compatibilitytools.d"
else
  DEST_INSTALL_ROOT="$HOME/.config/heroic/tools/proton"
fi

_log()  { echo " [install-proton] $*"; }
_fail() { echo " [install-proton] FOUT: $*" >&2; exit 1; }

if [ -n "${STEAM_ROOT:-}" ]; then
  _log "Steam-installatie gevonden ($STEAM_ROOT); installeer in $DEST_INSTALL_ROOT"
else
  _log "Geen Steam-installatie gevonden; installeer in Heroic-layout $DEST_INSTALL_ROOT"
fi

# ── Argumenten / omgevingspin ─────────────────────────────────
VERSION="${PROTON_VERSION:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --pin)
      [ $# -ge 2 ] || _fail "--pin vereist een versie (bijv. GE-Proton11-7)"
      VERSION="$2"; shift 2 ;;
    --help|-h)
      echo "Gebruik: install-proton.sh [--pin GE-ProtonX-Y]"
      echo "         (of omgevingsvariabele PROTON_VERSION=GE-ProtonX-Y)"
      exit 0 ;;
    *) _fail "Onbekend argument: $1 (zie --help)" ;;
  esac
done

# ── Architectuur ──────────────────────────────────────────────
case "$(uname -m)" in
  x86_64)   ASSET_ARCH="x86_64" ;;
  aarch64)  ASSET_ARCH="aarch64" ;;
  *) _fail "Niet-ondersteunde architectuur: $(uname -m)" ;;
esac
_log "Architectuur: $ASSET_ARCH"

# ── Versie bepalen ────────────────────────────────────────────
if [ -z "$VERSION" ]; then
  _log "Opvragen van de nieuwste GE-Proton release (GitHub)…"
  if command -v curl >/dev/null 2>&1; then
    VERSION="$(curl -s --max-time 30 "$API_URL" | grep -E '"tag_name"' | head -1 \
      | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
  fi
  if [ -z "$VERSION" ] && command -v wget >/dev/null 2>&1; then
    VERSION="$(wget -qO- --timeout=30 "$API_URL" 2>/dev/null \
      | grep -E '"tag_name"' | head -1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
  fi
  [ -n "$VERSION" ] || VERSION="$FALLBACK_VERSION"
  _log "Nieuwste release: $VERSION (fallback: $FALLBACK_VERSION)"
fi
[ -n "$VERSION" ] || _fail "Geen versie bepaald."

TAG="${VERSION#v}"
ASSET="${VERSION}-${ASSET_ARCH}.tar.gz"
URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${TAG}/${ASSET}"

DEST_DIR="$DEST_INSTALL_ROOT/$VERSION"
if [ -x "$DEST_DIR/proton" ]; then
  _log "GE-Proton '$VERSION' is al geïnstalleerd op: $DEST_DIR"
else
  _log "Downloaden: $URL"
  mkdir -p "$DEST_INSTALL_ROOT" "$TMP_DIR"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --connect-timeout 30 -o "$TMP_DIR/$ASSET" "$URL" \
      || _fail "Download mislukt (curl). Controleer je internetverbinding."
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$TMP_DIR/$ASSET" "$URL" || _fail "Download mislukt (wget)."
  else
    _fail "Zowel curl als wget ontbreekt; installeer minimaal één daarvan."
  fi

  _log "Uitpakken naar: $DEST_DIR"
  TMP_EXTRACT="$TMP_DIR/extract"
  mkdir -p "$TMP_EXTRACT"
  tar -xzf "$TMP_DIR/$ASSET" -C "$TMP_EXTRACT" || _fail "Uitpakken mislukt."

  # De topmap in het archief heet niet per se `$VERSION`: de arch-specifieke
  # tarballs gebruiken "<versie>-<arch>" (bv. GE-Proton11-7-x86_64). Normaliseer
  # ALTIJD naar de exacte verwachte mapnaam, zodat detectie (`_detect_proton`/
  # `_detect_pinned_proton` zoeken "$VERSION/proton") en Steam het vinden.
  extracted_top="$(find "$TMP_EXTRACT" -mindepth 1 -maxdepth 1 -type d -print -quit)"
  [ -n "$extracted_top" ] || _fail "Archief bevat geen topmap."
  mkdir -p "$DEST_INSTALL_ROOT"
  rm -rf -- "$DEST_INSTALL_ROOT/$VERSION"
  mv -- "$extracted_top" "$DEST_INSTALL_ROOT/$VERSION" || _fail "Kan uitgepakte map niet hernoemen naar $VERSION."
  rm -rf -- "$TMP_DIR"

  # version-bestand schrijven (Heroic/scripts herkennen dit formaat)
  TS="$(date +%s)"
  [ -f "$DEST_DIR/version" ] || printf '%s %s\n' "$TS" "$VERSION" > "$DEST_DIR/version"

  _log "GE-Proton geïnstalleerd op: $DEST_DIR"
fi

# ── GUI-snelkoppeling (InstallProton) ────────────────────────
SCRIPT_ABS="$(realpath -s -- "$0")"
mkdir -p "$(dirname "$DEST_DESKTOP")"
cat > "$DEST_DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=InstallProton
Comment=Update/installeer GE-Proton voor de game-launchers
Exec="$SCRIPT_ABS"
Terminal=true
Categories=System;
EOF
_log "GUI-snelkoppeling aangemaakt: $DEST_DESKTOP"
_log "Klaar. Start nu het bijbehorende game-script opnieuw."