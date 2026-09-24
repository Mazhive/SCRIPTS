#!/bin/bash
# hook: install-dotnet48 — .NET Framework 4.8 + mono verwijderd.
#
# Module (game-core/hooks/) die door game-common.sh wordt opgeroepen via
#   PROVISION_HOOKS=("install-dotnet48")
# Recept uit known-good-prefix (movedprefixes/AOW.Planetfall): dotnet48 installeert
# .NET 4.8 en zet *mscoree op native; remove_mono haalt wine-mono weg zodat
# .NET-apps de echte runtime gebruiken (hier: dowser.exe/louncher-componenten).

hook_run() {
  if command -v winetricks >/dev/null 2>&1; then
    _log "hook(install-dotnet48): winetricks -q remove_mono dotnet48..."
    WINEPREFIX="$PREFIX_PATH" winetricks -q remove_mono dotnet48 || \
      _log "hook(install-dotnet48): winetricks gaf een non-zero exit; controleer eindstatus."
  else
    _log "hook(install-dotnet48): winetricks niet gevonden; .NET 4.8 niet geïnstalleerd."
  fi
}