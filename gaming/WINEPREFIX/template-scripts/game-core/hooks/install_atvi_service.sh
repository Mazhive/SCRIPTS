#!/bin/bash
# hook: install-atvi-service — Ricochet anti-cheat service-stub installeren en starten.
#
# Module (game-core/hooks/) die door game-common.sh wordt opgeroepen via
#   PROVISION_HOOKS=("install_atvi_service")
#   PRE_LAUNCH_HOOKS=("install_atvi_service")
#
# Call of Duty Vanguard (h00dbyair/Ksenia crack) verwacht de kernel-service
# `atvi-geirdriful` (binPath → geirdriful.sys) voordat bootstrapper.exe de
# game-launch doet ("Game MUST be launched ... to satisfy the games anticheat").
# Op Windows zet Install Service.bat dat via sc.exe; hier repliceren we dat in
# de verse lokale prefix.
#
# Wine kan géén echte kernel-driver laden (ZwLoadDriver → winedevice.exe →
# LoadLibraryExW als user-mode DLL; een kernel-.sys kan niet mappen →
# STATUS_DLL_INIT_FAILED / 1114). Daarom laden we een eigen x86-64 shim-DLL
# met lege entry (geirdriful_shim.sys) die het ImagePath van de service is.
# Wine's init_driver keert STATUS_SUCCESS zodra OptionalHeader.AddressOfEntryPoint
# == 0 is — daarmee is StartServiceW/StartService "voldaan" en denkt de game
# dat het anti-cheat-component draait. De echte geirdriful.sys in de game-map
# blijft onaangeroerd.
#
# Provision: service registreren + shim deployen.
# Pre-launch: service (her)starten vlak voor bootstrapper (StartServiceW check).

hook_run() {
  local hook_dir win_drv_dir win_drv wine_cmd wineserver_cmd is_pre_launch=0
  local img_path='\SystemRoot\system32\drivers\geirdriful.sys'

  # Detect of we in PRE_LAUNCH_HOOKS draaien (game-common.sh zet PRE_HOOK_RUN=1).
  [ "${PRE_HOOK_RUN:-0}" = "1" ] && is_pre_launch=1

  hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  win_drv_dir="$PREFIX_PATH/drive_c/windows/system32/drivers"
  win_drv="$win_drv_dir/geirdriful.sys"

  # Gebruik ALTIJD de wine van de (gepinde) Proton-runner, niet `wine` uit PATH
  # (op deze host = /opt/wine-stable, wat met een GE-Proton-prefix conflicten
  # geeft: setupapi error=80 / prefix-upgrade). _detect_pinned_proton en
  # _proton_search_roots komen uit game-common.sh (hook wordt daarbinnen getraced).
  wine_cmd="$(command -v wine)"
  wineserver_cmd=""
  if declare -f _detect_pinned_proton >/dev/null 2>&1; then
    local runner=""
    runner="$(_detect_pinned_proton)" || runner=""
    if [ -n "$runner" ] && [ -x "$(dirname "$runner")/files/bin/wine" ]; then
      wine_cmd="$(dirname "$runner")/files/bin/wine"
      wineserver_cmd="$(dirname "$runner")/files/bin/wineserver"
    fi
  fi

  # Alleen bij provision (eerste run): foute wineserver killen en juiste starten.
  # Bij pre-launch is de launcher's wineserver (proton runner) al actief en correct.
  if [ "$is_pre_launch" = "0" ] && [ -n "$wineserver_cmd" ]; then
    WINEPREFIX="$PREFIX_PATH" "$wineserver_cmd" -k >/dev/null 2>&1 || true
    sleep 0.5
    WINEPREFIX="$PREFIX_PATH" "$wineserver_cmd" -w >/dev/null 2>&1 || true
  fi
  _log "hook(install-atvi-service): wine=${wine_cmd} (pre-launch=$is_pre_launch)"

  _log "hook(install-atvi-service): deploy shim-driver naar $win_drv"
  if [ ! -f "$hook_dir/geirdriful_shim.sys" ]; then
    _log "hook(install-atvi-service): geirdriful_shim.sys ontbreekt naast de hook — service niet geïnstalleerd."
    return 1
  fi
  mkdir -p "$win_drv_dir" || { _log "hook(install-atvi-service): kan $win_drv_dir niet aanmaken."; return 1; }
  cp -f "$hook_dir/geirdriful_shim.sys" "$win_drv" || { _log "hook(install-atvi-service): kopiëren naar drivers/ mislukt."; return 1; }

  _log "hook(install-atvi-service): service atvi-geirdriful registreren/herstellen (ImagePath=$img_path)"
  WINEPREFIX="$PREFIX_PATH" "$wine_cmd" sc.exe stop atvi-geirdriful >/dev/null 2>&1 || true
  WINEPREFIX="$PREFIX_PATH" "$wine_cmd" sc.exe delete atvi-geirdriful >/dev/null 2>&1 || true
  WINEPREFIX="$PREFIX_PATH" "$wine_cmd" sc.exe create atvi-geirdriful type= kernel start= demand error= ignore \
    binPath= "$img_path" DisplayName= "atvi-geirdriful" >/dev/null 2>&1 || \
    _log "hook(install-atvi-service): sc create gaf non-zero; controleer registratie."
  WINEPREFIX="$PREFIX_PATH" "$wine_cmd" reg add "HKLM\\System\\CurrentControlSet\\Services\\atvi-geirdriful" \
    -v ImagePath -t REG_EXPAND_SZ -d "$img_path" -f >/dev/null 2>&1 || \
    _log "hook(install-atvi-service): reg add ImagePath mislukte; check registratie."

  # Controle-regel: wat er daadwerkelijk is opgeslagen.
  WINEPREFIX="$PREFIX_PATH" "$wine_cmd" reg query "HKLM\\System\\CurrentControlSet\\Services\\atvi-geirdriful" \
    -v ImagePath 2>/dev/null | grep -o 'ImagePath.*' && \
    _log "hook(install-atvi-service): ImagePath geregistreerd (zie boven)."

  # Start + statustelling: bootstrapper doet StartServiceW → dit moet RUNNING zijn.
  WINEPREFIX="$PREFIX_PATH" "$wine_cmd" sc.exe start atvi-geirdriful >/dev/null 2>&1 || \
    _log "hook(install-atvi-service): sc start non-zero — service mogelijk al draaiend of shim niet startbaar."
  WINEPREFIX="$PREFIX_PATH" "$wine_cmd" sc.exe query atvi-geirdriful || \
    _log "hook(install-atvi-service): sc query gaf 1060/anders — service niet zichtbaar in SCM (zie plan: mogelijke fallback)."
}