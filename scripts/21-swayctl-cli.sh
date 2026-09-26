#!/usr/bin/env bash
# SWAY_DESC: SwayCTL CLI + theme engine (12 palettes, menu/theme/bg/doctor...)
# SWAY_DEFAULT: Y
# =======================================================
# 21-swayctl-cli.sh — the `swayctl` command + theme engine
# -------------------------------------------------------
# One `swayctl <group> <action>` router (swayctl/bin/swayctl)
# dispatching to lib/ once, with themes/<name>/palette.sh
# palettes compiled into every themed app (sway/swaybar, foot,
# swaync, rofi (wofi fallback), wlogout, swaylock). Replaces the old
# `debsway` CLI (kept as a symlink alias).
#
#   swayctl menu|launcher|run|theme|bg|bar|power|lock
#   swayctl clip|shot|sound|wire|toggle|keys|status
#   swayctl eng|update|doctor|setup
#
# Installs to:
#   ~/.local/share/swayctl/     the tree (bin/, lib/, themes/)
#   ~/.local/bin/swayctl        user symlink
#   /usr/local/bin/swayctl      system symlink (sway `exec swayctl …`)
#   debsway → swayctl           continuity alias
#
# Then applies the default theme (catppuccin-mocha) so the live
# session picks up the palette. If a debsway state dir exists it is
# migrated (theme, background marker) to swayctl's.
#
# Idempotent: safe to re-run; refreshes the tree + theme each time.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "SwayCTL CLI + theme engine"

SRC="$SCRIPT_DIR/../swayctl"
if [ ! -d "$SRC" ] || [ ! -f "$SRC/bin/swayctl" ]; then
    log_err "Missing swayctl tree at $SRC — nothing to install."
    exit 1
fi

INSTALL_DIR="$HOME/.local/share/swayctl"
BIN_DIR="$HOME/.local/bin"
NEW_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/swayctl"
OLD_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/debsway"
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$NEW_STATE"

# ---- 1. Copy the tree --------------------------------------------------------
log_info "Installing swayctl to $INSTALL_DIR ..."
cp -r "$SRC/." "$INSTALL_DIR/"
find "$INSTALL_DIR/bin" -name 'swayctl' -exec chmod +x {} +
log_ok "  tree copied (bin/, lib/, themes/)."

# ---- 1b. Prune stale paths ----------------------------------------------------
# $SRC is the source of truth: anything installed that no longer exists there
# is leftover from an older release (e.g. the retired waybar template) and
# must go, or it ghosts back into the live tree on the next theme render.
stale=0
while IFS= read -r -d '' f; do
    rel="${f#"$INSTALL_DIR"/}"
    if [ ! -e "$SRC/$rel" ]; then
        rm -f "$f" && stale=$((stale + 1))
        log_info "  pruned stale file: $rel"
    fi
done < <(find "$INSTALL_DIR" -type f -print0)
while IFS= read -r -d '' d; do
    rel="${d#"$INSTALL_DIR"/}"
    if [ -d "$d" ] && [ ! -e "$SRC/$rel" ]; then
        rmdir "$d" 2>/dev/null && stale=$((stale + 1)) && log_info "  pruned stale dir: $rel"
    fi
done < <(find "$INSTALL_DIR" -mindepth 1 -depth -type d -print0)
[ "$stale" -gt 0 ] && log_ok "  pruned $stale stale path(s) not in the repo." || log_info "  no stale paths — installed tree mirrors the repo."

# ---- 2. Symlinks — user + system (+ debsway alias) ---------------------------
if [ -x "$INSTALL_DIR/bin/swayctl" ]; then
    ln -sf "$INSTALL_DIR/bin/swayctl" "$BIN_DIR/swayctl"
    ln -sf "$INSTALL_DIR/bin/swayctl" "$BIN_DIR/debsway"
    log_ok "  ~/.local/bin/swayctl (and debsway alias)"
    priv ln -sf "$INSTALL_DIR/bin/swayctl" /usr/local/bin/swayctl 2>/dev/null || true
    priv ln -sf "$INSTALL_DIR/bin/swayctl" /usr/local/bin/debsway 2>/dev/null || true
    if [ -e /usr/local/bin/swayctl ]; then
        log_ok "  /usr/local/bin/swayctl (sway binds can exec it)"
    else
        log_warn "  could not create /usr/local/bin/swayctl — sway binds may need a relogin first."
    fi
else
    log_err "$INSTALL_DIR/bin/swayctl is not executable."
    exit 1
fi

# ---- 3. Migrate old debsway state --------------------------------------------
for marker in theme bg night; do
    if [ -f "$OLD_STATE/$marker" ] && [ ! -f "$NEW_STATE/$marker" ]; then
        cp -a "$OLD_STATE/$marker" "$NEW_STATE/$marker" 2>/dev/null && log_ok "  migrated state: $marker"
    fi
done

# ---- 4. Render + apply the default theme --------------------------------------
log_info "Applying default theme (catppuccin-mocha)..."
if SwayCTL_HOME="$INSTALL_DIR" "$INSTALL_DIR/bin/swayctl" theme set catppuccin-mocha; then
    log_ok "Theme applied and persisted (marker: $(cat "$NEW_STATE/theme" 2>/dev/null))."
else
    log_warn "Theme apply reported issues — check $NEW_STATE/ and re-run."
fi

# ---- 5. Live-session refresh ---------------------------------------------------
if command_exists swaymsg && [ -n "${SWAYSOCK:-}" ] && swaymsg -t get_version >/dev/null 2>&1; then
    swaymsg reload >/dev/null 2>&1 && log_ok "Sway reloaded."
else
    log_info "No live sway session — everything takes effect on next login."
fi

echo
log_ok "SwayCTL CLI installed."
log_info "  Try: swayctl doctor   (\$mod+Shift+C reloads sway binds first)"
log_info "       swayctl theme list / swayctl bar restart"
log_info "       swayctl setup    — first-run wizard (theme, wallpaper, night-light)"
log_info "  'debsway' still works (symlink alias)."
