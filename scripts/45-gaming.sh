#!/usr/bin/env bash
# SWAY_DESC: Gaming: Heroic (Flatpak), Steam, Wine
# SWAY_DEFAULT: Y
# =======================================================
# Gaming
# -------------------------------------------------------
#   heroic          Epic/GOG/Amazon launcher (Flatpak, from Flathub)
#   steam           Steam (apt; needs multilib + i386 enabled by Steam itself)
#   wine (+wine64)  generic Windows games/legacy apps
#
# Flatpak needs the Flathub remote from scripts/40-desktop-apps.sh;
# this step adds it defensively too. GPU acceleration comes from the
# mesa-vulkan-drivers installed in 13-hardware; Steam's own SteamOS
# runtime handles most compatibility.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Gaming"

install_pkgs "Steam" steam
install_pkgs "Wine" wine wine64

if command -v flatpak >/dev/null 2>&1; then
    flatpak remotes 2>/dev/null | grep -q flathub \
        || flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    if command_exists doas; then
        doas flatpak install -y flathub com.heroicgameslauncher.hgl 2>/dev/null \
            || flatpak install -y flathub com.heroicgameslauncher.hgl 2>/dev/null \
            || log_warn "Heroic Flatpak install skipped/failed (network)."
    else
        flatpak install -y flathub com.heroicgameslauncher.hgl 2>/dev/null \
            || log_warn "Heroic Flatpak install skipped/failed (network)."
    fi
else
    log_warn "flatpak not installed — skipping Heroic (run scripts/40-desktop-apps.sh first)."
fi

echo
log_ok "Gaming done."
log_info "  Steam first-launch does its own i386/multilib enablement."
log_info "  Heroic flatpak id: com.heroicgameslauncher.hgl"