#!/usr/bin/env bash
# SWAY_DESC: Desktop apps: Flatpak, CUPS, firewall, office-lite, media, torrent, mpv/zathura, TLP + battery cap, TUI tools
# SWAY_DEFAULT: Y
# =======================================================
# 40-desktop-apps.sh — day-to-day applications (lean set)
# -------------------------------------------------------
# Everything a general-purpose laptop needs that isn't the WM
# shell itself, installed --no-install-recommends where sensible:
#
#   flatpak + Flathub        user-space apps (secondary source)
#   cups + printer drivers   printing
#   gufw/ufw                 firewall, enabled with sane defaults
#   mpv  (VLC as fallback)   video
#   zathura + mupdf          PDF
#   qbittorrent              torrents
#   TLP + 80% battery cap    battery care (thinkpad_acpi)
#   btop/eza/bat/zoxide/fd   everyday TUI tools
#   yazi                     TUI file browser (best-effort: cargo)
#
# Heavy or niche apps live in their own steps (43-47). This one is
# the "works everywhere" baseline.
#
# Idempotent: safe to re-run.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Desktop applications (lean set)"

install_pkgs "Utility apps" \
    flatpak gparted qbittorrent gufw \
    cups cups-pdf printer-driver-gutenprint \
    mpv vlc \
    zathura zathura-pdf-mupdf \
    btop eza bat zoxide fd-find ripgrep

# ---- Flatpak -------------
if [ -f /etc/os-release ] && grep -qiE 'devuan' /etc/os-release 2>/dev/null || true; then
    # Flathub is distro-agnostic; only add if the remote is missing.
    if command -v flatpak >/dev/null 2>&1; then
        flatpak remotes 2>/dev/null | grep -q flathub \
            || flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
            && log_ok "Flathub remote added."
    fi
else
    [ -n "$(command -v flatpak 2>/dev/null)" ] && { :; }
fi

# ---- TLP + charge cap ----
install_pkgs "Battery care" tlp tlp-rdw powertop
start_service tlp
if [ -d "/sys/class/power_supply" ] && [ -n "$(ls /sys/class/power_supply 2>/dev/null | head -1)" ]; then
    for bat in /sys/class/power_supply/BAT0 /sys/class/power_supply/BAT1; do
        if [ -w "$bat/charge_control_end_threshold" ]; then
            printf '%s' 80 > "$bat/charge_control_end_threshold" 2>/dev/null \
                && log_ok "Battery charge cap set to 80% ($bat)."
        fi
    done
fi

# ---- yazi (best-effort install) ----------------------------------------------
# Not packaged in trixie; grab it via cargo when that's available, else note it.
if ! command -v yazi >/dev/null 2>&1; then
    if command -v cargo >/dev/null 2>&1; then
        log_info "Installing yazi via cargo (background)..."
        (cargo install --locked yazi-fm >/dev/null 2>&1 || true) &
    else
        log_warn "yazi not installed (needs cargo — install with: cargo install --locked yazi-fm)."
    fi
else
    log_ok "yazi already installed: $(command -v yazi)"
fi

echo
log_ok "Desktop apps installed."
log_info "  swayctl update --apply   — check/install apt+flatpak updates"
log_info "  TLP details: doas tlp-stat -s"