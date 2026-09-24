#!/bin/bash
# hook: install_gamescope — gamescope aanwezig maken (detectie + install).
#
# Module (game-core/hooks/) opgeroepen door game-common.sh via
#   PROVISION_HOOKS=("install_gamescope")
#
# gamescope is een HOST-pakket — géén prefix-zaak, maar de install moet ergens
# levens vinden in de per-game flow. Deze module detecteert of gamescope al
# aanwezig is (bv. voorgeïnstalleerd op CachyOS/Arch) en installeert het anders
# via de distro-pakketbeheerder (_distro_pkg). De daadwerkelijke launch-wrap
# (alleen bij GAME_GAMESCOPE=1 én een Wayland-sessie) doet game_launch in
# game-common.sh — dit is puur de "zorg dat het er is"-stap.
#
# Bewuste grenzen: zonder geldige pakketbeheerder, root-rechten óf sudo/pkexec
# slaat de module over met een duidelijke melding (gamescope blijft dan een
# optionele verbetering, geen harde eis).

hook_run() {
  if command -v gamescope >/dev/null 2>&1; then
    _log "hook(install_gamescope): gamescope al aanwezig — geen install nodig."
    return 0
  fi

  local pkg cmd
  pkg="$(_distro_pkg)"
  case "$pkg" in
    apt)    cmd="apt-get install -y gamescope" ;;
    pacman) cmd="pacman -S --noconfirm gamescope" ;;
    dnf)    cmd="dnf install -y gamescope" ;;
    zypper) cmd="zypper install -y gamescope" ;;
    *)
      _log "hook(install_gamescope): pakketbeheerder '$pkg' niet herkend; installeer gamescope handmatig."
      return 0
      ;;
  esac

  _log "hook(install_gamescope): gamescope ontbreekt; installeren via: $cmd"
  if [ "$(id -u)" -eq 0 ]; then
    $cmd
  elif command -v sudo >/dev/null 2>&1; then
    sudo $cmd
  elif command -v pkexec >/dev/null 2>&1; then
    pkexec $cmd
  else
    _log "hook(install_gamescope): geen root en geen sudo/pkexec — installeer gamescope handmatig."
    return 0
  fi

  if command -v gamescope >/dev/null 2>&1; then
    _log "hook(install_gamescope): gamescope nu beschikbaar."
  else
    _log "hook(install_gamescope): installatie leek te lukken maar gamescope is nog niet vindbaar."
  fi
}