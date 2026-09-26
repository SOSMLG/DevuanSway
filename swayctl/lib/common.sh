#!/usr/bin/env bash
# =======================================================
# swayctl/lib/common.sh — shared helpers for the SwayCTL CLI
# -------------------------------------------------------
# Sourced by bin/swayctl and every lib/*.sh. Everything
# path-related resolves relative to the tool's install dir
# (~/.local/share/swayctl by default), so moving the tree
# or invoking via /usr/local/bin symlink keeps working.
# =======================================================
[ -n "${_SWAYCTL_LIB_COMMON_LOADED:-}" ] && return 0
_SWAYCTL_LIB_COMMON_LOADED=1

# --- self-location ----------------------------------------------------------
CS_SELF="$(readlink -f "${BASH_SOURCE[0]}")"
CS_LIB_DIR="$(cd "$(dirname "$CS_SELF")" && pwd)"
CS_INSTALL="${SwayCTL_HOME:-$HOME/.local/share/swayctl}"
CS_BIN_DIR="$CS_INSTALL/bin"
CS_LIB="$CS_INSTALL/lib"
CS_THEMES="$CS_INSTALL/themes"
CS_TPL="$CS_THEMES/_base/tpl"
CS_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/swayctl"
CS_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

mkdir -p "$CS_STATE"

# --- CLI colors ----------------------------------------------------------------
D_RED="\033[0;31m"; D_GREEN="\033[0;32m"; D_YELLOW="\033[1;33m"; D_CYAN="\033[0;36m"; D_RESET="\033[0m"
d_log()  { echo -e "${D_CYAN}[*]${D_RESET} $*"; }
d_ok()   { echo -e "${D_GREEN}[OK]${D_RESET} $*"; }
d_warn() { echo -e "${D_YELLOW}[!]${D_RESET} $*"; }
d_err()  { echo -e "${D_RED}[ERROR]${D_RESET} $*" >&2; }

# priv() — run a command as root. Prefers doas, falls back to sudo.
priv() {
    local tool="${SWAY_PRIV:-}"
    if [ -z "$tool" ]; then
        if command -v doas >/dev/null 2>&1; then tool=doas; else tool=sudo; fi
    fi
    "$tool" "$@"
}

# --- palette / theme plumbing --------------------------------------------------
current_theme() {
    if [ -f "$CS_STATE/theme" ]; then
        cat "$CS_STATE/theme"
    else
        printf '%s\n' "catppuccin-mocha"
    fi
}

theme_dir() { printf '%s\n' "$CS_THEMES/$1"; }

# load_palette <dir> — sources a theme's palette.sh which sets C_* variables.
load_palette() {
    local dir="$1" f="${1%/}/palette.sh"
    if [ ! -f "$f" ]; then
        d_err "No palette.sh in $dir"
        return 1
    fi
    unset _PALETTE_OK
    . "$f"
    local missing=0 var
    for var in C_BG C_MANTLE C_CRUST C_SURFACE0 C_SURFACE1 C_SURFACE2 C_OVERLAY \
               C_TEXT C_SUBTEXT0 C_SUBTEXT1 C_ACCENT \
               C_RED C_GREEN C_YELLOW C_BLUE C_PURPLE C_PINK C_TEAL C_ORANGE \
               C_T0 C_T1 C_T2 C_T3 C_T4 C_T5 C_T6 C_T7 \
               C_TB0 C_TB1 C_TB2 C_TB3 C_TB4 C_TB5 C_TB6 C_TB7; do
        if [ -z "${!var:-}" ]; then
            d_err "palette $dir is missing '$var'"
            missing=1
        fi
    done
    [ "$missing" -eq 0 ]
}

# notify <summary> <body?>
notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a swayctl "$1" "${2:-}" >/dev/null 2>&1 || true
}

# is_under_sway — true if swaymsg reaches a running sway
is_under_sway() {
    command -v swaymsg >/dev/null 2>&1 && [ -n "${SWAYSOCK:-}" ] \
        && swaymsg -t get_version >/dev/null 2>&1
}

# swayctl_bin — absolute path to the running swayctl router.
swayctl_bin() {
    if [ -x "$CS_BIN_DIR/swayctl" ]; then
        printf '%s\n' "$CS_BIN_DIR/swayctl"
    elif [ -x /usr/local/bin/swayctl ]; then
        printf '%s\n' "/usr/local/bin/swayctl"
    else
        printf '%s\n' "swayctl"
    fi
}

# term_bin — preferred GUI terminal for showing CLI output visibly.
term_bin() {
    if [ -n "${TERMINAL:-}" ] && command -v "$TERMINAL" >/dev/null 2>&1; then
        printf '%s\n' "$TERMINAL"
        return 0
    fi
    command -v foot >/dev/null 2>&1 && { printf '%s\n' "foot"; return 0; }
    return 1
}

# ---- launcher abstraction -------------------------------------------------
# One frontend for every picker/menu so the launcher stays swappable:
# SWAY_LAUNCHER=rofi|wofi forces a picker; otherwise rofi wins when it's
# installed and wofi is the fallback (10-sway-core.sh installs both).

# launcher_bin — echo the active picker's binary name (or fail if none).
launcher_bin() {
	local forced="${SWAY_LAUNCHER:-}"
	if [ -n "$forced" ]; then
		if command -v "$forced" >/dev/null 2>&1; then
			printf '%s\n' "$forced"
			return 0
		fi
		d_warn "SWAY_LAUNCHER=$forced not installed — falling back."
	fi
	command -v rofi >/dev/null 2>&1 && { printf '%s\n' "rofi"; return 0; }
	command -v wofi >/dev/null 2>&1 && { printf '%s\n' "wofi"; return 0; }
	return 1
}

# launcher_pick <prompt> — stdin lines -> selected line (or empty on cancel).
launcher_pick() {
	local bin
	bin="$(launcher_bin)" || {
		d_err "No picker installed (need rofi — run scripts/10-sway-core.sh)."
		return 1
	}
	case "$bin" in
		rofi) rofi -dmenu -p "$1" ;;
		wofi) wofi --dmenu --insensitive --prompt "$1: " ;;
	esac
}

# wofi_pick — legacy alias; anything that still says wofi gets the frontend.
wofi_pick() { launcher_pick "$@"; }

# set_marker <key> <value>
set_marker() { printf '%s\n' "$2" > "$CS_STATE/$1"; }
get_marker() { [ -f "$CS_STATE/$1" ] && cat "$CS_STATE/$1" || true; }

# reset_terminal_colors — restore a sane terminal if a command mangled it
reset_terminal_colors() { tput sgr0 2>/dev/null || true; }