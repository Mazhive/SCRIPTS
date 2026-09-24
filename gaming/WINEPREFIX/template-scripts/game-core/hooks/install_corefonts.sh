#!/bin/bash
# hook: install-corefonts — Microsoft core fonts (Arial, Tahoma, etc.) in de prefix.
#
# Module (game-core/hooks/) die door game-common.sh wordt opgeroepen via
#   PROVISION_HOOKS=("install-corefonts")
# Benodigd voor Unity-spellen die systeem-fonts (Arial, Tahoma, etc.) gebruiken
# voor UI-tekst. Zonder deze fonts rendert DXVK tekst wit/onleesbaar.
#
# Methode: winetricks -q corefonts (Microsoft core fonts EULA accepted)

hook_run() {
  if command -v winetricks >/dev/null 2>&1; then
    _log "hook(install-corefonts): winetricks -q corefonts (Microsoft core fonts)..."
    WINEPREFIX="$PREFIX_PATH" winetricks -q corefonts || \
      _log "hook(install-corefonts): winetricks gaf een non-zero exit; controleer eindstatus."
  else
    _log "hook(install-corefonts): winetricks niet gevonden; corefonts niet geïnstalleerd."
  fi
}