#!/usr/bin/env bash
# SWAY_DESC: Apply default theme (catppuccin-mocha) + cursor + wallpaper
# SWAY_DEFAULT: Y
# =======================================================
# 22-theme-default.sh — initial theme application
# -------------------------------------------------------
# Pins the default palette (catppuccin-mocha) by running the
# same renderer 21 installs, then sets a sane GTK dark scheme and
# re-asserts the bundled default wallpaper. Everything beyond this
# is live-swappable with `swayctl theme set <name>` / `swayctl bg …`.
#
# Why a separate step: keep the CLI installer (21) focused on
# plumbing and let this step own the *choice* of what the box looks
# like out of the box. Change the default here (or pass
# SWAY_THEME=retro bash scripts/22-theme-default.sh).
#
# Idempotent: safe to re-run.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Default theme: catppuccin-mocha"

SWAYCTL="$HOME/.local/bin/swayctl"
if [ ! -x "$SWAYCTL" ]; then
    log_err "swayctl not installed — run scripts/21-swayctl-cli.sh first."
    exit 1
fi

THEME="${SWAY_THEME:-catppuccin-mocha}"
if ! "$SWAYCTL" theme list 2>/dev/null | grep -qx "$THEME"; then
    log_warn "Theme '$THEME' unknown — falling back to catppuccin-mocha."
    THEME="catppuccin-mocha"
fi

"$SWAYCTL" theme set "$THEME" && log_ok "Theme applied: $THEME"

# GTK dark scheme so GTK apps match (foot/swaybar are already themed).
command_exists gsettings && {
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark 2>/dev/null || true
}

# Re-assert the bundled default wallpaper (marker + sway output).
DEFAULT_WALL="$HOME/.config/sway/wallpapers/catppuccin-mocha.png"
if [ -f "$DEFAULT_WALL" ] && [ -z "$("$SWAYCTL" bg current 2>/dev/null)" ]; then
    "$SWAYCTL" bg set "$DEFAULT_WALL" >/dev/null 2>&1 && log_ok "Default wallpaper set."
fi

echo
log_ok "Default theme + wallpaper in place."
log_info "  Browse them all:      swayctl theme list / swayctl style"
log_info "  Change permanently:   swayctl setup"
