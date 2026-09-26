#!/usr/bin/env bash
# SWAY_DESC: Noto, Font Awesome + JetBrainsMono Nerd Font
# SWAY_DEFAULT: Y
# =======================================================
# Font Installer
# -------------------------------------------------------
# Installs: Noto (Latin + Arabic + Emoji), Font Awesome,
#           JetBrainsMono Nerd Font (latest GitHub release)
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

if [[ $EUID -eq 0 ]]; then
    log_err "Do not run this as root."
    exit 1
fi

if ! have_priv; then
    log_err "Neither doas nor sudo found — cannot escalate."
    exit 1
fi

echo -e "${CYAN}=========================================================${NC}"
echo -e "${CYAN} Font Installer${NC}"
echo -e "${CYAN}=========================================================${NC}"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# ---------------------------------------------------------------------------
# 1. APT packages
# ---------------------------------------------------------------------------
log_info "Updating package lists..."
apt_update -qq

log_info "Installing Noto + Font Awesome via apt..."
install_pkgs "APT fonts" \
    curl \
    fonts-font-awesome \
    fonts-noto-core \
    fonts-noto-unhinted \
    fonts-noto-color-emoji \
    fonts-noto-mono
command -v curl >/dev/null 2>&1 || { log_err "curl is required for the Nerd Font download."; exit 1; }
log_ok "APT fonts installed"

# ---------------------------------------------------------------------------
# 2. Nerd Fonts — JetBrainsMono + IosevkaTerm
# ---------------------------------------------------------------------------
NERD_FONT_DIR="${HOME}/.local/share/fonts/NerdFonts"
mkdir -p "$NERD_FONT_DIR"

install_nerd_font() {
    local name="$1"
    # NOTE: string-test, not `| grep -q` — with `set -o pipefail`, grep -q
    # quits on first match while fc-list is still writing, fc-list dies of
    # SIGPIPE and the check spuriously reports "not installed" (re-download
    # loop on every run).
    if [ -n "$(fc-list 2>/dev/null | grep -i "$name")" ]; then
        log_warn "$name already installed — skipping download"
        return 0
    fi

    log_info "Fetching latest release URL for $name..."
    local download_url
    download_url=$(curl -fsSL https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest \
        | grep -oP '"browser_download_url": "\K[^"]+' \
        | grep -i "${name}.*tar\.xz" \
        | head -1)

    if [[ -z "$download_url" ]]; then
        log_warn "GitHub API failed for $name, using fallback URL..."
        download_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/${name}.tar.xz"
    fi

    local font_archive="${WORK_DIR}/${name}.tar.xz"
    log_info "Downloading $name Nerd Font..."
    if ! curl -fsSL --progress-bar -L -o "$font_archive" "$download_url"; then
        log_err "Download failed: ${download_url}"
        return 1
    fi

    verify_download "$font_archive" 1048576 || return 1

    local expected_sha
    expected_sha="$(curl -fsSL --max-time 20 "${download_url}.sha256" 2>/dev/null | awk '{print $1}' | tr 'A-F' 'a-f')"
    if [ -n "$expected_sha" ]; then
        if ! sha256_verify "$font_archive" "$expected_sha"; then
            log_err "Checksum mismatch — the download may have been tampered with. Removing it."
            rm -f "$font_archive"
            return 1
        fi
    else
        log_warn "Could not fetch upstream .sha256 for $name — relying on the structural check."
    fi

    log_info "Extracting $name fonts..."
    if ! tar -xf "$font_archive" -C "$NERD_FONT_DIR" --wildcards '*.ttf' 2>/dev/null; then
        log_warn "Falling back to full extraction..."
        if ! tar -xf "$font_archive" -C "$NERD_FONT_DIR"; then
            log_err "Failed to extract $name font archive"
            return 1
        fi
    fi
    log_ok "$name Nerd Font installed to ${NERD_FONT_DIR}"
}

install_nerd_font "JetBrainsMono"
install_nerd_font "IosevkaTerm"

# ---------------------------------------------------------------------------
# 3. Fontconfig
# ---------------------------------------------------------------------------
FONTCONF_DIR="${HOME}/.config/fontconfig"
FONTCONF="${FONTCONF_DIR}/fonts.conf"
mkdir -p "$FONTCONF_DIR"

log_info "Writing ${FONTCONF}..."
FONTCONF_TMP="$WORK_DIR/fonts.conf"
cat > "$FONTCONF_TMP" << 'EOF'
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>

  <!-- Monospace: Prefer IosevkaTerm + JetBrainsMono Nerd Fonts, fallback to Noto -->
  <alias>
    <family>monospace</family>
    <prefer>
      <family>IosevkaTerm Nerd Font Mono</family>
      <family>JetBrainsMono Nerd Font Mono</family>
      <family>Noto Sans Mono</family>
      <family>DejaVu Sans Mono</family>
    </prefer>
  </alias>

  <!-- Sans-serif: Noto Sans + Arabic -->
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Sans</family>
      <family>Noto Sans Arabic</family>
      <family>Noto Color Emoji</family>
    </prefer>
  </alias>

  <!-- Serif: Noto Serif -->
  <alias>
    <family>serif</family>
    <prefer>
      <family>Noto Serif</family>
      <family>Noto Serif Arabic</family>
    </prefer>
  </alias>

  <!-- Emoji: Always use color emoji -->
  <match target="pattern">
    <test name="family"><string>emoji</string></test>
    <edit name="family" mode="assign" binding="same">
      <string>Noto Color Emoji</string>
    </edit>
  </match>

  <!-- Rendering: Subpixel hinting for LCD screens -->
  <match target="font">
    <edit name="antialias"  mode="assign"><bool>true</bool></edit>
    <edit name="hinting"    mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle"  mode="assign"><const>hintslight</const></edit>
    <edit name="rgba"       mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter"  mode="assign"><const>lcddefault</const></edit>
  </match>

</fontconfig>
EOF
# Backup-first: never silently clobber a hand-tuned fonts.conf.
if [ -f "$FONTCONF" ] && ! cmp -s "$FONTCONF_TMP" "$FONTCONF"; then
    cp -a "$FONTCONF" "$FONTCONF.bak.$(date +%Y%m%d_%H%M%S)"
    log_info "  backed up existing fonts.conf → .bak.*"
fi
cp "$FONTCONF_TMP" "$FONTCONF"
log_ok "fonts.conf written"

# ---------------------------------------------------------------------------
# 4. Rebuild font cache
# ---------------------------------------------------------------------------
log_info "Rebuilding font cache..."
priv fc-cache -f
fc-cache -f "$NERD_FONT_DIR"
log_ok "Font cache updated"

echo
log_ok "All done!"
echo -e "${CYAN}Verify with:${NC}"
echo -e "  fc-match 'JetBrainsMono Nerd Font Mono'"
echo -e "  fc-match 'Noto Sans Arabic'"
echo -e "  fc-match monospace"
