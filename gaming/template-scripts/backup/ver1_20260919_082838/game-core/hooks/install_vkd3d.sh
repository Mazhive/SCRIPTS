#!/bin/bash
# hook: install-vkd3d — D3D12 naar Vulkan (VKD3D-Proton) in de prefix.
#
# Module (game-core/hooks/) opgeroepen door game-common.sh via
#   PROVISION_HOOKS=("install_vkd3d")
# Specifieke DX12-eis; hoort niet in de generieke core (was _install_vkd3d).
# NB: Proton-games hoeven dit meestal niet — hun runner graft vkd3d zelf.

hook_run() {
  local vkd3d_root="$HOME/.config/heroic/tools/vkd3d"
  local setup=""
  if command -v setup_vkd3d_proton.sh >/dev/null 2>&1; then
    setup="$(command -v setup_vkd3d_proton.sh)"
  elif [ -d "$vkd3d_root" ]; then
    local version_file="$vkd3d_root/latest_vkd3d"
    local dir
    dir="$(cat "${version_file:-/dev/null}" 2>/dev/null | tr -d '[:space:]')"
    if [ -z "$dir" ]; then
      setup="$(find "$vkd3d_root" -maxdepth 2 -name setup_vkd3d_proton.sh -print -quit 2>/dev/null)"
    else
      setup="$vkd3d_root/$dir/setup_vkd3d_proton.sh"
    fi
  fi
  if [ -n "$setup" ] && [ -f "$setup" ]; then
    _log "hook(install-vkd3d): VKD3D-Proton installeren ($(basename "$setup"))..."
    WINEPREFIX="$PREFIX_PATH" "$setup" install || true
  else
    _log "hook(install-vkd3d): VKD3D-Proton setup niet gevonden; sla over."
  fi
}