#!/usr/bin/env bash
# SWAY_DESC: fastfetch + curated config presets
# SWAY_DEFAULT: Y
# =======================================================
# fastfetch
# -------------------------------------------------------
# System info on terminal open. Deploys the toolkit's own
# clean config, with an option to also install the bundled
# extra presets shipped in configs/fastfetch/.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

if [ "$(id -u)" -eq 0 ]; then
    log_err "Do not run this as root."
    exit 1
fi

if ! have_priv; then
    log_err "Neither doas nor sudo found — cannot escalate."
    exit 1
fi

echo -e "${CYAN}=========================================================${NC}"
echo -e "${CYAN} fastfetch${NC}"
echo -e "${CYAN}=========================================================${NC}"

# ---------------------------------------------------------------------------
# 1. Install fastfetch
# ---------------------------------------------------------------------------
if is_installed fastfetch; then
    log_ok "fastfetch already installed."
else
    log_info "Updating package lists..."
    apt_update -qq
    if priv apt-get install -y fastfetch; then
        log_ok "fastfetch installed."
    else
        log_err "Failed to install fastfetch."
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# 2. Deploy the toolkit's default config
# ---------------------------------------------------------------------------
FF_DIR="$HOME/.config/fastfetch"
mkdir -p "$FF_DIR"

LOCAL_CFG="$SCRIPT_DIR/../configs/fastfetch/config.jsonc"
if [ -f "$LOCAL_CFG" ]; then
    if [ -f "$FF_DIR/config.jsonc" ] && ! cmp -s "$LOCAL_CFG" "$FF_DIR/config.jsonc"; then
        cp -a "$FF_DIR/config.jsonc" "$FF_DIR/config.jsonc.bak.$(date +%Y%m%d_%H%M%S)"
        log_info "  backed up existing config.jsonc → .bak.*"
    fi
    if cp "$LOCAL_CFG" "$FF_DIR/config.jsonc"; then
        log_ok "Default config deployed to $FF_DIR/config.jsonc"
    else
        log_warn "Failed to copy default config."
    fi
else
    log_warn "Local config not found at $LOCAL_CFG — skipping default config."
fi

# ---------------------------------------------------------------------------
# 3. Optional: deploy bundled extra presets
# ---------------------------------------------------------------------------
# Presets ship with the toolkit (configs/fastfetch/) — no network at install
# time, matching the repo rule against fetching content over the wire.
PRESETS_DIR="$SCRIPT_DIR/../configs/fastfetch"
if ask "Also install extra presets (minimal/fancy/neon/debian-red/justaguy/server)?"; then
    if [ ! -d "$PRESETS_DIR" ]; then
        log_warn "Preset payload missing at $PRESETS_DIR — skipping extras."
    else
        for f in minimal.jsonc fancy.jsonc neon.jsonc debian-red.jsonc justaguy.jsonc server.jsonc \
                 debian_swirl.png justaguylinux.png; do
            if [ ! -f "$PRESETS_DIR/$f" ]; then
                log_warn "  missing bundled preset $f — skipping"
                continue
            fi
            # Back up a live preset that differs before overwriting it.
            if [ -f "$FF_DIR/$f" ] && ! cmp -s "$PRESETS_DIR/$f" "$FF_DIR/$f"; then
                cp -a "$FF_DIR/$f" "$FF_DIR/$f.bak.$(date +%Y%m%d_%H%M%S)"
                log_info "  backed up existing $f → .bak.*"
            fi
            if cp "$PRESETS_DIR/$f" "$FF_DIR/$f"; then
                log_info "  installed $f"
            else
                log_warn "  failed to copy $f (continuing)"
            fi
        done
        log_ok "Extra presets installed to $FF_DIR"
        log_info "Switch presets: cp ~/.config/fastfetch/<preset>.jsonc ~/.config/fastfetch/config.jsonc"
    fi
fi

log_ok "fastfetch setup complete. Try it: fastfetch"
