#!/usr/bin/env bash
# SWAY_DESC: Sway stack + swaync + foot + wofi/rofi + thunar + LightDM sway session + fonts
# SWAY_DEFAULT: Y
# =======================================================
# 10-sway-core.sh — the lean-but-functional Sway desktop
# -------------------------------------------------------
# Installs the Sway window manager and every piece of the
# "small footprint" shell around it — one bar, one notifier,
# one launcher, one terminal:
#
#   sway/swaybg/swayidle/swaylock  WM + wallpaper + idle + lock
#   swaybar status.sh              the bar — built into sway, themed by the engine
#                                 (no separate bar daemon; 'swayctl bar restart' reloads)
#   sway-notification-center        notifications (swaync)
#   foot                            terminal (only pinned terminal)
#   rofi (wofi fallback)            app launcher / runner
#   grim/slurp/swappy/wl-clipboard  screenshots + clipboard
#   wlogout                         power menu
#   lxqt-policykit                  polkit agent (Wayland-capable)
#   thunar + gvfs + xarchiver       files / mounts / archives
#   xdg-desktop-portal-wlr          Wayland portals
#   fonts                           Noto + emoji + JetBrains Mono + FA
#
# Also:
#   * makes the **SwaySetup** Wayland session the LightDM default
#     (one display manager owns the console; XFCE session stays
#     selectable as a manual fallback, it is never auto-started)
#   * deploys the static configs from configs/ into ~/.config
#     (backing up anything already there)
#
# Idempotent: safe to re-run; backs up before overwriting.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Sway stack + shell + LightDM sway session"

# ---- 1. Packages -------------------------------------------------------------
CORE_PKGS=(
    sway swaybg swayidle swaylock sway-notification-center wlogout
    foot wofi rofi xwayland xdg-desktop-portal-wlr
    grim slurp swappy wl-clipboard cliphist wf-recorder
    lxqt-policykit
    thunar thunar-archive-plugin thunar-volman gvfs-backends gvfs-fuse xarchiver
    pipewire-audio
    fonts-noto-core fonts-noto-color-emoji fonts-jetbrains-mono fonts-font-awesome
)
# fonts-noto-core pulls caret/extra subsets; keep the really common ones here.
install_pkgs "Sway core" "${CORE_PKGS[@]}"

# ---- 2. User Dirs ------------------------------------------------------------
command_exists xdg-user-dirs-update && {
    mkdir -p "$HOME/Screenshots"
    xdg-user-dirs-update 2>/dev/null || true
}

# ---- 3. Deploy configs -------------------------------------------------------
# Overlay configs/ onto ~/.config, backing up each app dir that already
# exists. The theme step (22) re-renders the color files afterwards;
# configs/ ships the default render so nothing looks broken in between.
CONFIGS_SRC="$SCRIPT_DIR/../configs"
if [ -d "$CONFIGS_SRC" ]; then
    TS="$(date +%Y%m%d_%H%M%S)"
    for app_dir in "$CONFIGS_SRC"/*/; do
        app="$(basename "$app_dir")"
        [ -d "$app_dir" ] || continue
        dst="$HOME/.config/$app"
        if [ -d "$dst" ] && [ "$(ls -A "$dst" 2>/dev/null | wc -l)" -gt 0 ]; then
            cp -a "$dst" "$dst.bak.$TS" 2>/dev/null || true
            log_info "Backed up ~/.config/$app → ~/.config/$app.bak.$TS"
        fi
        mkdir -p "$dst"
        cp -a "$app_dir/." "$dst/"
        log_ok "Deployed configs/$app → ~/.config/$app"
    done
    # Detect config dirs a previous release deployed but this one no longer
    # carries (detected via the timestamped backups made above). Never delete
    # user configs — just surface them so stale apps aren't silently kept.
    for bak in "$HOME"/.config/*.bak.*; do
        [ -e "$bak" ] || continue
        base="$(basename "${bak%%.bak.*}")"
        [ -d "$HOME/.config/$base" ] || continue
        [ -d "$CONFIGS_SRC/$base" ] && continue
        log_warn "~/.config/$base was deployed by an older release but is no longer in configs/ — remove it if unused (rm -rf ~/.config/$base)"
    done
else
    log_warn "configs/ not found next to scripts/ — skipping config deploy."
fi

# Keep ~/.config/sway/current-theme pointing at the default palette name.
[ -d "$HOME/.config/sway" ] || mkdir -p "$HOME/.config/sway"
ln -sfn catppuccin-mocha "$HOME/.config/sway/current-theme" 2>/dev/null || true

# ---- 4. PATH: ~/.local/bin + /usr/local/sbin --------------------------------
if ! grep -qF '.local/bin' "$HOME/.profile" 2>/dev/null; then
    printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.profile"
    log_ok "Added ~/.local/bin to PATH in ~/.profile."
fi

# ---- 5. SwaySetup session = LightDM default ------------------------------------
# The sway package ships /usr/share/wayland-sessions/sway.desktop, but that
# entry has no D-Bus session bus (swaync/portals need one). Install our
# own wrapper session and point LightDM at it. Exactly ONE session is default.
SESSION_BIN="/usr/local/bin/sway-setup-session"
SESSION_DESKTOP="/usr/share/wayland-sessions/sway-setup.desktop"
LIGHTDM_CONF="/etc/lightdm/lightdm.conf.d/60-sway-setup.conf"

priv tee "$SESSION_BIN" > /dev/null <<'EOF'
#!/bin/sh
# SwaySetup Wayland session — launch Sway on a fresh D-Bus session bus.
# Used by LightDM (user-session=sway-setup) and by anything calling "sway-session".
export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_DESKTOP=sway
export XDG_SESSION_TYPE=wayland
exec dbus-run-session -- sway
EOF
priv chmod +x "$SESSION_BIN"

priv mkdir -p /usr/share/wayland-sessions
priv tee "$SESSION_DESKTOP" > /dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=SwaySetup
Comment=Sway (Wayland) on a D-Bus session bus
Exec=/usr/local/bin/sway-setup-session
TryExec=/usr/local/bin/sway-setup-session
EOF

if command_exists lightdm || [ -x /usr/sbin/lightdm ]; then
    priv mkdir -p /etc/lightdm/lightdm.conf.d
    priv tee "$LIGHTDM_CONF" > /dev/null <<'EOF'
# SwaySetup is the one DM-owned console session. XFCE stays selectable in the
# greeter as a manual fallback; this only makes Sway the default.
[Seat:*]
user-session=sway-setup
greeter-show-manual-login=true
EOF
    if [ -f /etc/lightdm/lightdm.conf ] && ! grep -q '^user-session' /etc/lightdm/lightdm.conf; then
        log_ok "LightDM default session set: SwaySetup (wayland). Select \"SwaySetup\" in the greeter."
    else
        log_ok "LightDM 60-sway-setup.conf installed — greeter defaults to SwaySetup."
    fi
else
    log_warn "lightdm not detected — install alignment skipped (session desktop file still installed)."
fi

# ---- 6. run sway-over-XFCE extras ---------------------------------------------
# GPG/SSH agent bridging for GUI sessions under sway (same trick XFCE uses).
if [ ! -f "/etc/profile.d/gpg-agent-wayland.sh" ] && command_exists gpgconf; then
    priv tee /etc/profile.d/gpg-agent-wayland.sh > /dev/null <<'EOF'
# Under Sway (GDK/environment) keep the SSH agent usable; gpgconf pins the
# socket when available. Harmless elsewhere.
EOF
    log_ok "gpg-agent Wayland profile stub installed."
fi

echo
log_ok "Core Sway desktop installed."
log_info "  Install the swayctl CLI + theme engine next: scripts/21-swayctl-cli.sh"
log_info "  Pick your session at login: SwaySetup (default now)."
