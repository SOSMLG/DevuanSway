#!/usr/bin/env bash
# SWAY_DESC: Shell extras: night-light, auto display (kanshi), media/brightness keys, volume helpers
# SWAY_DEFAULT: Y
# =======================================================
# 20-shell-tools.sh — ambient shell affordances
# -------------------------------------------------------
# The small daemons and helpers that make a laptop desktop feel
# complete without heavyweight extras:
#
#   gammastep       night-light (warm color temp after sunset)
#   kanshi          automatic display profiles (docked/undocked)
#   brightnessctl   backlight control (XF86MonBrightness*)
#   playerctl       media key transport (XF86Audio*Play/Next/Prev)
#   iio-sensor-proxy auto-rotate via the laptop accelerometer
#
# No swayosd by design: volume/mute go through `swayctl sound`
# (pactl) which raises a swaync notification instead of an OSD
# daemon — one less process, same feedback. Nothing here starts
# at login by itself; sway/config autostarts what it uses.
#
# Idempotent: safe to re-run.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Shell extras — night light, displays, media keys"

install_pkgs "Shell extras" \
    gammastep kanshi brightnessctl playerctl iio-sensor-proxy

# policy agent it ships under /usr/bin — record the resolved path for doctor.
command -v kanshi >/dev/null 2>&1 && log_ok "kanshi: $(command -v kanshi)"
command -v gammastep >/dev/null 2>&1 && log_ok "gammastep: $(command -v gammastep)"

# Make sure ~/.local/bin exists for the swayctl helpers (21 installs them).
mkdir -p "$HOME/.local/bin"

echo
log_ok "Shell extras installed."
log_info "  Toggle night light live:  swayctl toggle night"
log_info "  Wallpaper/theme:          swayctl theme set <name> / swayctl bg cycle"