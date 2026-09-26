#!/usr/bin/env bash
# SWAY_DESC: Editors: VSCodium (apt repo) + Neovim (apt) + LazyVim bootstrap
# SWAY_DEFAULT: Y
# =======================================================
# Editors — write code, comfortably
# -------------------------------------------------------
#   VSCodium   telemetry-free VS Code build, via its official APT
#              repository so it tracks updates with normal apt
#              (https://vscodium.com; releases on GitHub)
#   Neovim     Debian's nvim (0.10+) — a good vim, nothing to
#              maintain; then a *user-owned* LazyVim bootstrap: the
#              toolkit scaffolds ~/.config/nvim once and hands it over.
#
# Both are idempotent.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Editors: VSCodium + Neovim"

# ---- VSCodium -----------------------------------------------------------------
if is_installed codium; then
    log_ok "codium already installed ($(dpkg-query -W -f='${Version}' codium 2>/dev/null))."
else
    log_info "Adding the VSCodium apt repository..."
    if ! [ -f /etc/apt/sources.list.d/vscodium.list ]; then
        priv tee /etc/apt/sources.list.d/vscodium.list > /dev/null <<'EOF'
deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://mirrors.tuna.tsinghua.edu.cn/github-release/VSCodium/vscodium/LatestRelease/ deb main
EOF
        # The official repo migrated to mirror hosts; prefer the canonical one.
        priv tee /etc/apt/sources.list.d/vscodium.list > /dev/null <<'EOF'
deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/repos/debs/ vscodium main
EOF
    fi
    if ! [ -f /usr/share/keyrings/vscodium-archive-keyring.gpg ]; then
        priv mkdir -p /usr/share/keyrings
        priv curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
            -o /usr/share/keyrings/vscodium-archive-keyring.gpg 2>/dev/null \
            || log_warn "Could not fetch VSCodium signing key."
    fi
    apt_update || true
    install_pkgs "VSCodium" codium
fi

# ---- Neovim + LazyVim ----------------------------------------------------------
install_pkgs "Neovim" neovim git
NVIM_CFG="$HOME/.config/nvim"
if command -v nvim >/dev/null 2>&1; then
    if [ -d "$NVIM_CFG/lua" ]; then
        log_ok "~/.config/nvim already has a real config — leaving it alone."
    elif ask "Bootstrap LazyVim at ~/.config/nvim?"; then
        log_info "Cloning the LazyVim starter..."
        mkdir -p "$NVIM_CFG"
        TMP="$(mktemp -d)"
        git clone --depth 1 https://github.com/LazyVim/starter "$TMP/lazyvim" >/dev/null 2>&1 \
            && cp -a "$TMP/lazyvim/." "$NVIM_CFG/" \
            && rm -rf "$NVIM_CFG/.git" \
            && log_ok "LazyVim starter in place — open nvim to pull plugins." \
            || log_warn "LazyVim clone failed; add it manually later if you want it."
        rm -rf "$TMP"
    fi
else
    log_warn "nvim not on PATH after install."
fi

echo
log_ok "Editors installed."
log_info "  VSCodium:      codium"
log_info "  Neovim:        nvim   (first run installs LazyVim plugins)"