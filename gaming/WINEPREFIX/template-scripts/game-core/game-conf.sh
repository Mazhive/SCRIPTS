#!/bin/bash
# game-conf.sh — per-game installatiepad-resolutie (één bron van waarheid).
#
# Override-volgorde:
#   1. GUI_GAME_DIR  (launch-env uit game-gui.py: per-launch)
#   2. conf          ($GAME_CONF_FILE, key GAME_DIR_<GAME_NAME> — GUI slaat
#                     de door gebruiker gekozen map hier per game op)
#   3. default       (hardcoded GAME_DIR in het launcher-script = fallback)
# Gedeeld door game-common.sh (core) én door standalone-launchers die
# game-conf.sh zelf sourcen (automationempire.sh, conarium.sh).

GAME_CONF_FILE="${GAME_CONF_FILE:-$HOME/.config/gamelauncher/installpaths.conf}"

_conf_log() {
  if declare -F _log >/dev/null 2>&1; then
    _log "$1"
  else
    echo "[game] $1"
  fi
}

_game_conf_get() {
  [ -f "$GAME_CONF_FILE" ] || return 1
  local key
  key="GAME_DIR_$GAME_NAME"
  # Case-insensitive opzoeken (GUI schrijft uppercase, script exporteert mixed-case).
  local line
  line="$(grep -i "^[[:space:]]*${key}=" "$GAME_CONF_FILE" 2>/dev/null | head -1)"
  [ -n "$line" ] || return 1
  local val="${line#*=}"
  # Eerst witruimte trimmen, dan overtollige aanhalingstekens weghalen
  # (trim vóór het strip-pad: bij ` "/pad" ` met trailing-spatie moet de
  #  eindquote wél herkend worden).
  val="${val#"${val%%[![:space:]]*}"}"
  val="${val%"${val##*[![:space:]]}"}"
  case "$val" in
    \"*\") val="${val#\"}"; val="${val%\"}" ;;
    \'*\') val="${val#\'}"; val="${val%\'}" ;;
  esac
  printf '%s' "$val"
}

game_resolve_install_dir() {
  # GAME_EXE_REL afleiden uit de script-default (vóórdat GAME_DIR kan wijzigen),
  # zodat de exe na een override netjes her-deriveerbaar blijft.
  if [ "${GAME_EXE_REL:-unset}" = "unset" ] && [ "${GAME_NATIVE:-0}" != "1" ] \
     && [ -n "${GAME_EXE:-}" ]; then
    GAME_EXE_REL="${GAME_EXE#"$GAME_DIR"/}"
  fi

  local resolved=""
  if [ -n "${GUI_GAME_DIR:-}" ]; then
    resolved="$GUI_GAME_DIR"
  elif resolved="$(_game_conf_get)"; then
    :
  else
    resolved="$GAME_DIR"
  fi

  if [ -n "$resolved" ] && [ "$resolved" != "$GAME_DIR" ]; then
    GAME_DIR="$resolved"
    if [ "${GAME_NATIVE:-0}" != "1" ] && [ -n "${GAME_EXE_REL:-}" ]; then
      GAME_EXE="$GAME_DIR/$GAME_EXE_REL"
    fi
    _conf_log "Installatiepad-override: $GAME_DIR (bron: GUI/conf)"
  fi
}