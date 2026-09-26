#!/usr/bin/env bash
# =======================================================
# Verify Setup — end-state audit
# -------------------------------------------------------
# One-pass check of the toolkit's expected end state:
# group membership, key packages, swayctl + 12-palette
# theme engine, sway config/wallpaper, engineering stack,
# app defaults, and services. Run via `run.sh --verify`
# or standalone after a run.
#
# Prints PASS/FAIL/WARN and exits non-zero on any critical
# failure, so it can gate CI/validation.
# =======================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/scripts/lib/common.sh"

PASS=0; FAIL=0; WARN=0

report() {  # report <name> <status> <detail>
    case "$2" in
        ok)
            printf '  PASS  %-44s %s\n' "$1" "${3:-}"
            PASS=$((PASS + 1))
            ;;
        fail)
            printf '  FAIL  %-44s %s\n' "$1" "${3:-}"
            FAIL=$((FAIL + 1))
            ;;
        warn)
            printf '  WARN  %-44s %s\n' "$1" "${3:-}"
            WARN=$((WARN + 1))
            ;;
    esac
}

pkg() {  # pkg <name> [critical|optional]
    local name="$1" level="${2:-critical}"
    local state detail
    if is_installed "$name"; then
        state="ok"; detail="installed"
    elif [ "$level" = "optional" ]; then
        state="warn"; detail="not installed (optional)"
    else
        state="fail"; detail="missing — re-run the relevant script"
    fi
    report "$name" "$state" "$detail"
}

bin() {  # bin <command> [critical|optional]
    local name="$1" level="${2:-critical}"
    local state detail
    if command -v "$name" >/dev/null 2>&1; then
        state="ok"; detail="$(command -v "$name")"
    elif [ "$level" = "optional" ]; then
        state="warn"; detail="not installed (optional)"
    else
        state="fail"; detail="missing — re-run the relevant script"
    fi
    report "bin: $name" "$state" "$detail"
}

cfg() {  # cfg <label> <path> [critical|optional]
    local label="$1" path="$2" level="${3:-critical}"
    local state detail
    if [ -f "$path" ]; then
        state="ok"; detail="present"
    elif [ "$level" = "optional" ]; then
        state="warn"; detail="missing (optional)"
    else
        state="fail"; detail="missing — re-run the relevant script"
    fi
    report "cfg: $label" "$state" "$detail"
}

# service_state: enabled under systemd OR OpenRC; running via process name.
service_state() {
    local svc="$1" procname="$2" level="${3:-fail}"
    local enabled="" running=""
    if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
        systemctl is-enabled "$svc" >/dev/null 2>&1 && enabled="systemd"
        systemctl is-enabled "${svc}.service" >/dev/null 2>&1 && enabled="systemd"
    elif command -v rc-update >/dev/null 2>&1; then
        rc-update show 2>/dev/null | awk -v s="$svc" '$1==s{found=1} END{exit !found}' && enabled="openrc"
    fi
    pgrep -x "$procname" >/dev/null 2>&1 && running="yes"

    if [ -n "$running" ]; then
        report "$svc (service)" ok "${enabled:-running, not enabled}"
    elif [ "$level" = "optional" ]; then
        report "$svc (service)" warn "not running"
    else
        report "$svc (service)" fail "not running"
    fi
}

log_head "Setup verification"

echo -e "  (user: ${CYAN}${ACTUAL_USER}${NC})\n"

# --- 1. Groups --------------------------------------------------------------
for g in input video render plugdev lpadmin; do
    if id -nG "$ACTUAL_USER" 2>/dev/null | tr ' ' '\n' | grep -qx "$g"; then
        report "group: $g" ok
    else
        report "group: $g" warn "user not in $g (re-run 12-user-groups.sh or: doas usermod -aG $g $ACTUAL_USER)"
    fi
done

# --- 2. Core Sway shell (10-sway-core.sh) ----------------------------------
for p in sway swaybg swaylock swayidle sway-notification-center wlogout \
         foot wofi rofi grim slurp swappy cliphist wf-recorder \
         lxqt-policykit thunar thunar-volman gvfs-backends xarchiver \
         pipewire-audio fonts-jetbrains-mono fonts-noto-color-emoji; do
    pkg "$p"
done

# --- 3. Shell tools (20-shell-tools.sh) ------------------------------------
for p in gammastep kanshi brightnessctl playerctl iio-sensor-proxy; do
    pkg "$p" optional
done

# --- 4. swayctl CLI + theme engine (21/22) -----------------------------------
bin swayctl
bin debsway
if [ -d "$HOME/.local/share/swayctl/themes" ]; then
    theme_count="$(find "$HOME/.local/share/swayctl/themes" -maxdepth 2 -name palette.sh | wc -l)"
    if [ "$theme_count" -ge 12 ]; then
        report "swayctl theme engine" ok "$theme_count palettes"
    else
        report "swayctl theme engine" fail "only $theme_count palettes — re-run 21-swayctl-cli.sh"
    fi
else
    report "swayctl install tree" fail "missing — re-run 21-swayctl-cli.sh"
fi
ST="$(cat "$HOME/.local/state/swayctl/theme" 2>/dev/null || echo none)"
report "swayctl active theme" ok "$ST"
cfg "sway/config" "$HOME/.config/sway/config"
cfg "sway palette (colors.conf)" "$HOME/.config/sway/colors.conf"
cfg "foot/foot.ini" "$HOME/.config/foot/foot.ini"
cfg "swaync/config.json" "$HOME/.config/swaync/config.json"
cfg "swaync/style.css" "$HOME/.config/swaync/style.css"
cfg "wofi/style.css" "$HOME/.config/wofi/style.css"
if grep -q '^location=bottom' "$HOME/.config/wofi/config" 2>/dev/null; then
    report "wofi anchor" ok "bottom — rises from above the built-in bar"
else
    report "wofi anchor" fail "expected location=bottom — re-run: swayctl theme set"
fi

cfg "rofi/config.rasi" "$HOME/.config/rofi/config.rasi"
cfg "rofi/theme.rasi" "$HOME/.config/rofi/theme.rasi"
cfg "swaybar palette.env" "$HOME/.config/swaybar/palette.env" optional
if [ -x "$HOME/.config/swaybar/status.sh" ]; then
    report "swaybar status.sh" ok "executable — JSON status protocol"
elif [ -f "$HOME/.config/swaybar/status.sh" ]; then
    report "swaybar status.sh" fail "not executable — swaybar prints 'error reading from status command' (chmod +x)"
else
    report "swaybar status.sh" fail "missing — re-run 10-sway-core.sh"
fi
cfg "swaylock/config" "$HOME/.config/swaylock/config"
cfg "wlogout/layout" "$HOME/.config/wlogout/layout"
cfg "kanshi/config" "$HOME/.config/kanshi/config"
cfg "gammastep/config.ini" "$HOME/.config/gammastep/config.ini"

# --- Drift guard: nothing from the retired waybar may survive. ----
# 21-swayctl-cli.sh prunes the installed tree on deploy; this makes any
# leftover visible to the audit instead of silently re-rendering waybar.
if [ -e "$HOME/.local/share/swayctl/themes/_base/tpl/waybar" ]; then
    report "waybar remnants" fail "installed tpl still present — re-run 21-swayctl-cli.sh"
elif [ -d "$HOME/.config/waybar" ]; then
    report "waybar remnants" warn "~/.config/waybar still exists — remove if unused (rm -rf ~/.config/waybar)"
else
    report "waybar remnants" ok "none — single built-in bar"
fi

# --- Overlay / screenshot hardening (swayctl kill, lock cleanup) ----
if grep -qE '^cmd_kill\(\)' "$HOME/.local/share/swayctl/lib/actions.sh" 2>/dev/null; then
    report "swayctl kill" ok "escape hatch wired"
else
    report "swayctl kill" fail "cmd_kill missing — re-run 21-swayctl-cli.sh"
fi
if grep -q '\[ -z "$act" \] && return 0' "$HOME/.local/share/swayctl/lib/actions.sh" 2>/dev/null; then
    report "shot menu cancel guard" ok "no respawn loop"
else
    report "shot menu cancel guard" fail "respawn loop possible — re-run 21-swayctl-cli.sh"
fi
if grep -q 'Bar  (built-in swaybar)' "$HOME/.local/share/swayctl/lib/actions.sh" 2>/dev/null; then
    report "swayctl menu bar entry" fail "no-op entry still present"
else
    report "swayctl menu bar entry" ok "removed"
fi
grep -qF 'bindsym --locked $mod+Ctrl+Escape exec swayctl kill' "$HOME/.config/sway/config" 2>/dev/null \
    && report "screenshot panic key" ok "\$mod+Ctrl+Escape (locked-safe)" \
    || report "screenshot panic key" fail "missing — re-run 10-sway-core.sh"

stale=0
for f in "$HOME/.config/sway/keybindings.conf" \
    "$HOME/.config/sway/scripts/autostart.sh" \
    "$HOME/.config/sway/scripts/screenshot" \
    "$HOME/.config/sway/scripts/power" \
    "$HOME/.config/sway/scripts/screen-off" \
    "$HOME/.config/sway/scripts/changevolume" \
    "$HOME/.config/sway/scripts/help" \
    "$HOME/.config/sway/scripts/sway-layout-menu.sh" \
    "$HOME/.config/sway/scripts/thememenu" \
    "$HOME/.config/sway/scripts/status.sh"; do
    [ -e "$f" ] && stale=1
done
if [ "$stale" -eq 1 ]; then
    report "stale sway files" warn "dead scripts/keybindings.conf still in ~/.config/sway"
else
    report "stale sway files" ok "none"
fi

migbaks=$(ls "$HOME"/.config/waybar.bak.* "$HOME"/.local/state/swayctl/bar.bak.* "$HOME"/.config/sway/config.bak.* 2>/dev/null)
if [ -n "$migbaks" ]; then
    report "migration backups" warn "still present — remove by hand when verified"
else
    report "migration backups" ok "none"
fi

# --- 5. Wallpaper ------------------------------------------------------------
if [ -f "$HOME/.config/sway/wallpapers/catppuccin-mocha.png" ]; then
    report "default wallpaper" ok
else
    report "default wallpaper" warn "missing — re-run 22-theme-default.sh"
fi

# --- 6. Engineering stack (30-32) -------------------------------------------
for p in octave jupyter-notebook python3-scipy python3-sympy python3-pandas \
         scilab qucs kicad matlab-support cmake gcc g++ make git; do
    pkg "$p" optional
done
if [ -x "$HOME/.local/venv/eng/bin/python" ]; then
    if "$HOME/.local/venv/eng/bin/python" -c 'import control' >/dev/null 2>&1; then
        report "eng venv python-control" ok
    else
        report "eng venv python-control" warn "venv present, python-control missing (swayctl eng venv)"
    fi
else
    report "eng venv ~/.local/venv/eng" warn "not created (swayctl eng venv)"
fi

# --- 7. App defaults (40-47, optional roll = warn) ---------------------------
pkg flatpak optional
pkg timeshift optional
pkg opencode optional
pkg libreoffice-writer optional
pkg thunderbird optional
pkg keepassxc optional
pkg obs-studio optional
pkg kdenlive optional
pkg gimp optional
pkg steam optional
pkg wine optional
pkg codium optional
pkg neovim optional

# --- 8. Services -----------------------------------------------------------
service_state lightdm lightdm critical
service_state bluetooth bluetoothd optional
service_state tlp tlp optional
service_state cups cupsd optional
service_state NetworkManager NetworkManager optional

# --- 9. LightDM default session ----------------------------------------------
if [ -f /usr/share/wayland-sessions/sway-setup.desktop ]; then
    report "SwaySetup session desktop" ok
else
    report "SwaySetup session desktop" fail "missing — re-run 10-sway-core.sh"
fi

echo
echo -e "${GREEN}  ${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
if [ "$FAIL" -gt 0 ]; then
    echo
    log_err "Some checks failed — see lines above, then re-run the relevant script."
    exit 1
fi
exit 0
