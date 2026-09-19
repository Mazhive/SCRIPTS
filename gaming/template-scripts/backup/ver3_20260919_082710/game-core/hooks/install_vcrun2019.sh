#!/bin/bash
# hook: install-vcrun2019 — VC++2015-2019-runtime leveren in de prefix.
#
# Module (game-core/hooks/) die door game-common.sh wordt opgeroepen via
#   PROVISION_HOOKS=("install-vcrun2019")
# Blijft bewust UIT de generieke core; hier staat de héle receptuur.
# Levert de complete runtime (msvcp140/140_1/140_2/atomic_wait/codecvt_ids,
# vcruntime140(1), ucrtbase) én de native,builtin-overrides — exact de
# known-working referentie-prefix (zie README, per-game notities).
#
# Methode (VC_RUNTIME_METHOD; default "winetricks"):
#   winetricks → winetricks -q ucrtbase2019 vcrun2019 (referentie-receptuur).
#                Ontbreekt winetricks, dan valt de module terug op de
#                gebundelde game-redist als vangnet.
#   redist     → gebundelde VC_redist.x64.exe uit $GAME_DIR/_CommonRedist
#                primair (/install /quiet /norestart); winetricks als vangnet
#                als een DLL na installatie toch ongeldig blijft.
# Zet de game-variabele pas om naar "redist" wanneer een opstarttest dat
# noodzakelijk maakt (voor pc's waar een winetricks-download niet lukt).

_VC_REQUIRED_DLLS=( msvcp140.dll msvcp140_1.dll msvcp140_2.dll \
                    msvcp140_atomic_wait.dll msvcp140_codecvt_ids.dll \
                    vcruntime140.dll vcruntime140_1.dll ucrtbase.dll )
_VC_OVERRIDE_DLLS=( msvcp140 msvcp140_1 msvcp140_2 msvcp140_atomic_wait \
                    msvcp140_codecvt_ids vcruntime140 vcruntime140_1 ucrtbase )

_vc_via_winetricks() {
  _log "hook(install-vcrun2019): winetricks -q ucrtbase2019 vcrun2019 (referentie-receptuur)..."
  WINEPREFIX="$PREFIX_PATH" winetricks -q ucrtbase2019 vcrun2019 || \
    _log "hook(install-vcrun2019): winetricks gaf een non-zero exit; controleer eindstatus."
}

_vc_via_redist() {
  local redist
  redist="$(find "$GAME_DIR/_CommonRedist" -iname 'VC_redist.x64.exe' -print -quit 2>/dev/null)"
  if [ -n "$redist" ]; then
    _log "hook(install-vcrun2019): gebundelde redist installeren: $(basename "$redist")"
    WINEPREFIX="$PREFIX_PATH" wine "$redist" /install /quiet /norestart || \
      _log "hook(install-vcrun2019): redist gaf een non-zero exit; overrides/heal volgen."
    VC_METHOD=redist
  else
    _log "hook(install-vcrun2019): geen VC_redist.x64.exe in $GAME_DIR/_CommonRedist."
    VC_METHOD=none
  fi
}

_vc_set_overrides() {
  local dll
  for dll in "${_VC_OVERRIDE_DLLS[@]}"; do
    WINEPREFIX="$PREFIX_PATH" wine reg add "HKCU\\Software\\Wine\\DllOverrides" \
      /v "*$dll" /d native,builtin /f >/dev/null 2>&1 || true
  done
  _log "hook(install-vcrun2019): DllOverrides native,builtin ingesteld."
}

# Herstelt ontbrekende/ongeldige DLLs; exit 0 als alles geldig is.
_vc_heal() {
  local sys32="$PREFIX_PATH/drive_c/windows/system32"
  local dll src bad=0 miss=""
  for dll in "${_VC_REQUIRED_DLLS[@]}"; do
    if _dll_is_x86_64 "$sys32/$dll"; then
      continue
    fi
    [ -f "$sys32/$dll" ] && _log "hook(install-vcrun2019): $dll geen x86_64-PE — heal."
    if src="$(_runtime_dll_source "$dll")" || src="$(_proton_builtin_dll "$dll")"; then
      if cp -f "$src" "$sys32/$dll" 2>/dev/null; then
        chmod u+w "$sys32/$dll" 2>/dev/null || true
        _log "hook(install-vcrun2019): $dll hersteld als x86_64."
      else
        bad=1; miss="$miss $dll"
      fi
    else
      bad=1; miss="$miss $dll"
    fi
  done
  [ "$bad" = "1" ] && _log "hook(install-vcrun2019): ontbrekend/ongeldig na heal:$miss"
  return $bad
}

hook_run() {
  local method="${VC_RUNTIME_METHOD:-winetricks}"
  VC_METHOD=""

  # ── 1. Runtime leveren (methode-afhankelijk) ──────────────
  if [ "$method" = "redist" ]; then
    _vc_via_redist
  elif command -v winetricks >/dev/null 2>&1; then
    _vc_via_winetricks
    VC_METHOD=winetricks
  else
    _vc_via_redist
  fi

  # ── 2. Overrides zekeren (onafhankelijk van leverancier) ─
  _vc_set_overrides

  # ── 3. Validatie + auto-heal (incl. winetricks-vangnet) ──
  if ! _vc_heal; then
    if [ "$VC_METHOD" != "winetricks" ] && command -v winetricks >/dev/null 2>&1; then
      _log "hook(install-vcrun2019): vangnet — winetricks vcrun2019."
      WINEPREFIX="$PREFIX_PATH" winetricks -q vcrun2019 || true
    fi
    _vc_heal
  fi

  # ── 4. Eindstatus (stille check) ──────────────────────────
  local sys32="$PREFIX_PATH/drive_c/windows/system32"
  local dll ok=1
  for dll in "${_VC_REQUIRED_DLLS[@]}"; do
    if ! _dll_is_x86_64 "$sys32/$dll"; then
      ok=0
      _log "hook(install-vcrun2019): MISS $dll (ontbreekt of geen x86_64-PE)."
    fi
  done
  if [ "$ok" = "1" ]; then
    _log "hook(install-vcrun2019): VC-runtime volledig en geldig (method=$VC_METHOD)."
  else
    _log "hook(install-vcrun2019): LET OP — VC-runtime niet volledig; game kan bij start stil stoppen."
  fi
}