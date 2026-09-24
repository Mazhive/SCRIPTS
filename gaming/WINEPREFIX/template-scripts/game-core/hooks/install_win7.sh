#!/bin/bash
# hook: install-win7 — Windows-versie van de prefix op Windows 7 zetten.
#
# Module (game-core/hooks/) die door game-common.sh wordt opgeroepen via
#   PROVISION_HOOKS=("install-win7")
# Recept uit known-good-prefix (movedprefixes/AOW.Planetfall): CurrentVersion 6.1
# (Windows 7 SP1). Sommige games van dat tijdperk (o.a. deze Unity/DX11-titel)
# gedragen zich anders / beter onder win7 dan onder win10/11.

hook_run() {
  if command -v winetricks >/dev/null 2>&1; then
    _log "hook(install-win7): winetricks -q win7..."
    WINEPREFIX="$PREFIX_PATH" winetricks -q win7 || \
      _log "hook(install-win7): winetricks gaf een non-zero exit; controleer windows-versie."
  else
    _log "hook(install-win7): winetricks niet gevonden; windows-versie niet gewijzigd."
  fi
}