#!/usr/bin/env bash
# SWAY_DESC: Firefox ESR + Betterfox hardening
# SWAY_DEFAULT: Y
# DESC: Install & harden Firefox ESR with privacy-focused settings
# Adapted from harden_firefox.sh (Butterbian) for the Debian (Trixie) + Sway setup.
# Concept inspired by: https://github.com/tonybanters/tonarchy

set -uo pipefail

# Set colors for output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Vendored Betterfox snapshot tag — bump when re-merging upstream changes.
# The merged user.js (this snapshot + local additions) ships in the repo at
# configs/firefox/user.js; refresh it after reviewing upstream:
#   https://github.com/yokoffing/Betterfox/tags
BETTERFOX_TAG=150.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Firefox profile base
MOZ_DIR="$HOME/.mozilla/firefox"

# Where the merged user.js (Betterfox + additions) is cached.
# The wrapper script reads from here on every Firefox launch.
USERJS_CACHE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/butterscripts/firefox"
USERJS_CACHE="$USERJS_CACHE_DIR/user.js"

# Check if running on Debian or Devuan (Devuan also ships /etc/debian_version)
if [ -f /etc/devuan_version ]; then
    echo -e "${GREEN}Devuan detected.${NC}"
elif [ -f /etc/debian_version ]; then
    echo -e "${GREEN}Debian-based system detected.${NC}"
else
    echo -e "${RED}This script is optimized for Debian/Devuan. Your system may not be compatible.${NC}"
    read -r -p "Continue anyway? (y/n): " continue_anyway
    if [[ "$continue_anyway" != "y" && "$continue_anyway" != "Y" ]]; then
        exit 1
    fi
fi

# Install firefox-esr if it isn't present yet — this project targets ESR.
ensure_firefox_esr() {
    if is_installed firefox-esr; then
        echo -e "${GREEN}firefox-esr already installed.${NC}"
        return 0
    fi

    echo -e "${CYAN}firefox-esr not found, installing it...${NC}"
    if [ -z "${SWAY_SKIP_APT_UPDATE:-}" ]; then
        priv apt-get update || { echo -e "${RED}apt-get update failed.${NC}"; return 1; }
    fi
    if priv apt-get install -y firefox-esr; then
        echo -e "${GREEN}firefox-esr installed.${NC}"
    else
        echo -e "${RED}Failed to install firefox-esr.${NC}"
        return 1
    fi
}

# Install the vendored Betterfox user.js (repo payload) → cached user.js.
# The snapshot ships in configs/firefox/user.js — no network at install time.
# The launch wrapper re-copies this cache into the profile on every run.
generate_userjs() {
    local payload="$SCRIPT_DIR/../configs/firefox/user.js"

    if [ ! -f "$payload" ]; then
        echo -e "${RED}Vendored user.js not found: $payload${NC}"
        echo -e "${RED}Is the sway-setup payload (configs/firefox/) present?${NC}"
        return 1
    fi

    mkdir -p "$USERJS_CACHE_DIR"
    if cp "$payload" "$USERJS_CACHE"; then
        echo -e "${GREEN}user.js installed at $USERJS_CACHE (Betterfox ${BETTERFOX_TAG} snapshot)${NC}"
    else
        echo -e "${RED}Failed to copy user.js to $USERJS_CACHE${NC}"
        return 1
    fi
}

# Create or update the hardened profile at ~/.mozilla/firefox/
setup_profile() {
    local profile_name="$1"  # e.g., default-release or default-esr

    local profile_dir="$MOZ_DIR/$profile_name"

    # If profile base doesn't exist, create it with profiles.ini
    if [ ! -d "$MOZ_DIR" ]; then
        mkdir -p "$profile_dir"
        cat > "$MOZ_DIR/profiles.ini" << PROF_EOF
[General]
StartWithLastProfile=1
Version=2

[Profile0]
Name=$profile_name
IsRelative=1
Path=$profile_name
Default=1
PROF_EOF
        echo -e "${GREEN}Profile created at $profile_dir${NC}"
    else
        # Profile base exists — find existing profile or add ours
        local found=0
        for dir in "$MOZ_DIR"/*."$profile_name"; do
            if [ -d "$dir" ]; then
                profile_dir="$dir"
                found=1
                break
            fi
        done
        [ "$found" -eq 0 ] && mkdir -p "$profile_dir"
    fi

    # Install user.js from cache
    cp "$USERJS_CACHE" "$profile_dir/user.js"
    echo -e "${GREEN}user.js installed to $profile_dir${NC}"
}

# Install policies.json to system distribution directory
install_policies() {
    local distribution_dir="$1"

    [ ! -d "$distribution_dir" ] && priv mkdir -p "$distribution_dir"

    if [ ! -f "$SCRIPT_DIR/policies.json" ]; then
        echo -e "${RED}Error: policies.json not found in $SCRIPT_DIR${NC}"
        return 1
    fi

    if priv cp "$SCRIPT_DIR/policies.json" "$distribution_dir/policies.json"; then
        echo -e "${GREEN}Policies installed to $distribution_dir${NC}"
    else
        echo -e "${RED}Failed to install policies.json${NC}"
        return 1
    fi
}

# Replace system .desktop file (requires root)
install_desktop_file() {
    local exec_name="$1"
    local desktop_file="$2"
    local icon_name="$3"
    local browser_name="$4"

    local system_desktop="/usr/share/applications/$desktop_file"

    priv tee "$system_desktop" > /dev/null << EOF
[Desktop Entry]
Name=$browser_name
GenericName=Web Browser
Exec=$exec_name %u
Terminal=false
Type=Application
Icon=$icon_name
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/vnd.mozilla.xul+xml;text/mml;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
StartupWMClass=$exec_name
EOF

    echo -e "${GREEN}System desktop file updated: $system_desktop${NC}"
}

# Create wrapper script in ~/.local/bin/ to shadow system binary
# Keeps user.js current on every launch (covers CLI, WM keybinds, launchers)
create_wrapper_script() {
    local exec_name="$1"
    local profile_name="$2"  # e.g., default-esr

    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    local wrapper="$bin_dir/$exec_name"

    cat > "$wrapper" << WRAPPER_EOF
#!/bin/sh
MOZ_DIR="\$HOME/.mozilla/firefox"
USERJS="\${XDG_DATA_HOME:-\$HOME/.local/share}/butterscripts/firefox/user.js"

if [ -f "\$USERJS" ]; then
    for dir in "\$MOZ_DIR"/*.$profile_name; do
        if [ -d "\$dir" ]; then
            cp "\$USERJS" "\$dir/user.js" 2>/dev/null
            break
        fi
    done
fi

exec /usr/bin/$exec_name "\$@"
WRAPPER_EOF

    chmod +x "$wrapper"
    echo -e "${GREEN}Wrapper installed: $wrapper${NC}"

    if ! echo "$PATH" | tr ':' '\n' | grep -qx "$bin_dir"; then
        echo -e "${YELLOW}Warning: $bin_dir is not in your PATH${NC}"
        echo -e "${YELLOW}Add to your shell rc: export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    fi
}

# Main hardening function
harden_firefox() {
    local browser_name="$1"
    local exec_name="$2"
    local distribution_dir="$3"
    local desktop_file="$4"
    local icon_name="$5"
    local profile_name="$6"  # e.g., default-release or default-esr

    echo ""
    echo -e "${CYAN}=========================================================${NC}"
    echo -e "${CYAN}Hardening $browser_name${NC}"
    echo -e "${CYAN}=========================================================${NC}"

    setup_profile "$profile_name"
    install_policies "$distribution_dir" || return 1
    install_desktop_file "$exec_name" "$desktop_file" "$icon_name" "$browser_name" || return 1
    create_wrapper_script "$exec_name" "$profile_name" || return 1

    echo -e "${GREEN}$browser_name hardening complete!${NC}"
}

show_menu() {
    echo -e "${CYAN}=========================================================${NC}"
    echo -e "${CYAN}            FIREFOX HARDENING SCRIPT                     ${NC}"
    echo -e "${CYAN}=========================================================${NC}"
    echo ""

    local firefox_installed=false
    local firefox_esr_installed=false

    if is_installed firefox; then
        firefox_installed=true
        echo -e "${GREEN}  Firefox Latest: Installed${NC}"
    else
        echo -e "${YELLOW}  Firefox Latest: Not installed${NC}"
    fi

    if is_installed firefox-esr; then
        firefox_esr_installed=true
        echo -e "${GREEN}  Firefox ESR: Installed${NC}"
    else
        echo -e "${YELLOW}  Firefox ESR: Not installed${NC}"
    fi

    echo ""

    if ! $firefox_installed && ! $firefox_esr_installed; then
        echo -e "${RED}No Firefox installation detected.${NC}"
        exit 1
    fi

    echo -e "${CYAN}=========================================================${NC}"
    echo -e "${YELLOW}This will:${NC}"
    echo -e "  - Create hardened profile at ~/.mozilla/firefox/"
    echo -e "  - Apply Betterfox ${BETTERFOX_TAG} + privacy additions (user.js)"
    echo -e "  - Install privacy-focused search engines"
    echo -e "    (:sp Startpage, :sx Searx, :b Brave, :d DuckDuckGo, :gw/:gi/:gn/:gm Google)"
    echo -e "  - Auto-install uBlock Origin on first run"
    echo -e "  - Replace system .desktop + create wrapper script (re-applies user.js on each launch)"
    echo -e "${CYAN}=========================================================${NC}"
    echo ""
    echo -e "${YELLOW}Select which browser to harden:${NC}"

    local option=1
    local options=()

    if $firefox_installed; then
        echo -e "${CYAN}$option.${NC} Firefox Latest"
        options+=("firefox")
        ((option++))
    fi

    if $firefox_esr_installed; then
        echo -e "${CYAN}$option.${NC} Firefox ESR"
        options+=("firefox-esr")
        ((option++))
    fi

    if $firefox_installed && $firefox_esr_installed; then
        echo -e "${CYAN}$option.${NC} Both"
        options+=("both")
        ((option++))
    fi

    echo -e "${CYAN}$option.${NC} Exit"
    options+=("exit")

    echo ""
    local choice
    if [ -n "${SWAY_ASSUME_YES:-}" ]; then
        # Unattended (run.sh --yes / ISO build): prefer ESR (this project's browser),
        # falling back to Latest when only that is installed.
        for i in "${!options[@]}"; do
            if [ "${options[$i]}" = "firefox-esr" ]; then
                choice=$((i+1))
                break
            fi
        done
        [ -z "$choice" ] && choice=1
        echo -e "${YELLOW}(unattended) hardening: ${options[$((choice-1))]}${NC}"
    else
        # Default to ESR (this project's chosen browser) when only ESR is present.
        local default_choice=1
        read -rp "Enter your choice [default: ${default_choice}]: " choice
        choice=${choice:-$default_choice}
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#options[@]}" ]; then
        echo -e "${RED}Invalid choice${NC}"
        exit 1
    fi

    local selected="${options[$((choice-1))]}"

    case "$selected" in
        "firefox")
            harden_firefox "Firefox" "firefox" "/usr/lib/firefox/distribution" "firefox.desktop" "firefox" "default-release"
            ;;
        "firefox-esr")
            harden_firefox "Firefox ESR" "firefox-esr" "/usr/lib/firefox-esr/distribution" "firefox-esr.desktop" "firefox-esr" "default-esr"
            ;;
        "both")
            harden_firefox "Firefox" "firefox" "/usr/lib/firefox/distribution" "firefox.desktop" "firefox" "default-release"
            harden_firefox "Firefox ESR" "firefox-esr" "/usr/lib/firefox-esr/distribution" "firefox-esr.desktop" "firefox-esr" "default-esr"
            ;;
        "exit")
            echo -e "${YELLOW}Exiting...${NC}"
            exit 0
            ;;
    esac

    echo ""
    echo -e "${CYAN}=========================================================${NC}"
    echo -e "${GREEN}Done! Firefox will now use the hardened profile.${NC}"
    echo -e "${CYAN}=========================================================${NC}"
}

# Preflight checks
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Do not run this script as root — it needs to write to your own \$HOME.${NC}"
    echo -e "${YELLOW}Run it as your normal user; it will escalate itself (doas) when needed.${NC}"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/policies.json" ]; then
    echo -e "${RED}Error: policies.json not found in $SCRIPT_DIR${NC}"
    exit 1
fi

ensure_firefox_esr || exit 1
generate_userjs || exit 1

show_menu
