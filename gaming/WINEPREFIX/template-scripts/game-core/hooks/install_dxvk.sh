#!/bin/bash
# hook: install-dxvk — DXVK native in de prefix (via winetricks).
#
# Module (game-core/hooks/) die door game-common.sh wordt opgeroepen via
#   PROVISION_HOOKS=("install-dxvk")
# Recept uit known-good-prefix (movedprefixes/AOW.Planetfall): winetricks' dxvk
# verb zet d3d9/d3d10core/d3d11/dxgi op "native" en legt de dxvk-dlls in
# system32. Lost WineD3D-shaderfixmes en witte UI-tekst op.

hook_run() {
  if command -v winetricks >/dev/null 2>&1; then
    _log "hook(install-dxvk): winetricks -q dxvk (DXVK native)..."
    WINEPREFIX="$PREFIX_PATH" winetricks -q dxvk || \
      _log "hook(install-dxvk): winetricks gaf een non-zero exit; DXVK mogelijk niet volledig actief."
  else
    _log "hook(install-dxvk): winetricks niet gevonden; DXVK niet geïnstalleerd."
  fi
}