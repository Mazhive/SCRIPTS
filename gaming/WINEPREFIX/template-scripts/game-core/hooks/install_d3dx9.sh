#!/bin/bash
# hook: install-d3dx9 — DirectX 9 hulp-libs (d3dcompiler_43 + d3dx9_24..43).
#
# Module (game-core/hooks/) die door game-common.sh wordt opgeroepen via
#   PROVISION_HOOKS=("install-d3dx9")
# Recept uit known-good-prefix (movedprefixes/AOW.Planetfall): native
# d3dcompiler_43 + d3dx9 overrides. Voorkomt witte/mistige UI-tekst en
# shader-fixmes bij Unity-games van dit tijdperk.

hook_run() {
  if command -v winetricks >/dev/null 2>&1; then
    _log "hook(install-d3dx9): winetricks -q d3dcompiler_43 d3dx9..."
    WINEPREFIX="$PREFIX_PATH" winetricks -q d3dcompiler_43 d3dx9 || \
      _log "hook(install-d3dx9): winetricks gaf een non-zero exit; controleer eindstatus."
  else
    _log "hook(install-d3dx9): winetricks niet gevonden; d3dx9 niet geïnstalleerd."
  fi
}