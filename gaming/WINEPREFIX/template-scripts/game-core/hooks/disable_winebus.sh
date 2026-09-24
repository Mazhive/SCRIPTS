#!/bin/bash
# hook: disable_winebus — winebus "Enable SDL" uitschakelen + inputfix.
#
# Module (game-core/hooks/) opgeroepen door game-common.sh via
#   PROVISION_HOOKS=("disable_winebus")  (bij vers prefix)   en/of
#   PRE_LAUNCH_HOOKS=("disable_winebus") (idempotente drift-guard, aanbevolen)
# Idempotent + snel → veilig op beide plekken.
#
# Sommige games (o.a. Cyberpunk 2077) detecteren een willekeurig
# joystick-achtig apparaat als gamecontroller en schakelen dan naar
# controllermodus, waardoor muis+toetsenbord genegeerd worden (bekende
# "Press SPACE"-deadinput). De klassieke remedy zette "Enable SDL"=0 EN
# "DisableHidraw"=1 — maar DisableHidraw maakte óók ALLE echte gamepads
# onbruikbaar. Bewezen is dat ALLEEN "Enable SDL"=0 (hidraw intact) het
# toetsenbord herstelt (2026-09, Cyberpunk op KDE Wayland). Daarom:
#   - dit module zet nu uitsluitend "Enable SDL"=0;
#   - nuance uit de gamepad-analyse: "beter gamepads blijven via hidraw"
#     geldt alleen als Wine die route fysiek kan bereiken (leesbaar hidraw /
#     hidraw-node voor de pad). Op deze machine ontbreekt dat — de pad werkt
#     op OS-niveau, maar niet in XInput-only-games zoals Cyberpunk.
#   - EEN UITZONDERING (via de losse tool tools/cyberpunk_gamepad.sh):
#     als de gebruiker expliciet de "padmodus" kiest, maakt de tool in de
#     prefix-root een markerbestand `.pad-mode` (én zet Enable SDL=1). Dan
#     slaan we hier óver, zodat de SDL-backend van winebus de pad als
#     is_gamepad=1-device kan aanbieden (bewezen in de probe). De normale
#     workflow raakt die marker NOOIT aan — dit is alleen de escape-hatch van
#     de handmatige tool.

hook_run() {
  local marker="${PREFIX_PATH%/pfx}/.pad-mode"
  if [[ -f "$marker" ]]; then
    _log "hook(disable_winebus): padmodus actief (marker aanwezig) — SDL-fix overgeslagen; de pad wordt via SDL aangeboden."
    return 0
  fi

  _log "hook(disable_winebus): winebus 'Enable SDL'=0 instellen (hidraw blijft aan)..."

  WINEPREFIX="$PREFIX_PATH" wine reg add \
    'HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\winebus' \
    /v 'Enable SDL' /t REG_DWORD /d 0 /f >/dev/null 2>&1 || \
    _log "hook(disable_winebus): 'Enable SDL' kon niet worden ingesteld."

  # Registry pas echt op disk als de wineserver stopt — anders zou een latere
  # run de oude (wél joystick-vertonele) stand kunnen lezen.
  WINEPREFIX="$PREFIX_PATH" wineserver -w 2>/dev/null || true

  local out
  out="$(WINEPREFIX="$PREFIX_PATH" wine reg query \
    'HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\winebus' 2>/dev/null)"
  echo "$out" | grep -E 'Enable SDL' | sed 's/^/       [game] /'
  echo "$out" | grep -q 'Enable SDL.*0x0' && \
    _log "hook(disable_winebus): OK — Enable SDL=0 actief (toetsenbord werkt)."
}