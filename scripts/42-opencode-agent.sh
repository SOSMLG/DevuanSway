#!/usr/bin/env bash
# SWAY_DESC: OpenCode AI agent + Super+A hotkey (via swayctl agent)
# SWAY_DEFAULT: Y
# =======================================================
# AI: OpenCode
# -------------------------------------------------------
# Installs OpenCode (https://opencode.ai) — an open-source,
# terminal-based AI coding agent (bring your own API key, or use
# its free tier). Binds $mod+a to `swayctl agent`, which opens
# OpenCode in a foot terminal.
#
# Also drops a plain system "skill"/AGENTS file describing this
# box, so OpenCode (and Claude Code) start with the right context.
# =======================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "AI: OpenCode"

if command_exists opencode; then
    log_ok "OpenCode already installed ($(opencode --version 2>/dev/null || echo 'version unknown'))."
else
    METHOD=""
    if [ -n "${SWAY_ASSUME_YES:-}" ]; then
        METHOD="1"
    else
        read -rp "$(echo -e "${YELLOW}Install via [1] official script, [2] npm, or [N] skip? (1/2/N): ${NC}")" METHOD
    fi
    case "$METHOD" in
        1)
            log_info "Running the official OpenCode installer..."
            curl -fsSL https://opencode.ai/install | bash \
                && log_ok "OpenCode installed." \
                || log_err "OpenCode installation failed."
            ;;
        2)
            command_exists npm || install_pkgs "Node.js + npm" nodejs npm
            if command_exists npm; then
                priv npm install -g opencode-ai \
                    && log_ok "OpenCode installed via npm." \
                    || log_err "npm install failed."
            fi
            ;;
        *) log_warn "Skipped OpenCode installation." ;;
    esac
fi

for CANDIDATE in "$HOME/.opencode/bin" "$HOME/bin"; do
    if [ -d "$CANDIDATE" ] && ! grep -qF "$CANDIDATE" "$HOME/.bashrc" 2>/dev/null; then
        printf 'export PATH="%s:$PATH"\n' "$CANDIDATE" >> "$HOME/.bashrc"
        log_ok "Added $CANDIDATE to PATH in ~/.bashrc"
    fi
done

# ---- $mod+a binding (sway) ---------------------------------------------------
SWAY_CONFIG="$HOME/.config/sway/config"
if [ -f "$SWAY_CONFIG" ] && ask "Bind Super+A to launch OpenCode?"; then
    if grep -qE "swayctl agent|opencode" "$SWAY_CONFIG" 2>/dev/null; then
        log_ok "Super+A binding already present."
    elif grep -qE '^[[:space:]]*bindsym[[:space:]]+[^#]*\$mod\+a([[:space:]]|$)' "$SWAY_CONFIG" 2>/dev/null; then
        log_warn "\$mod+a is already bound — skip. Free it, or add manually:"
        log_info "  bindsym \$mod+a exec \$term -e swayctl agent"
    else
        cat >> "$SWAY_CONFIG" << 'EOF'

# OpenCode (Super+A) — added by scripts/42-opencode-agent.sh
bindsym $mod+a exec $term -e swayctl agent
EOF
        log_ok "Super+A now launches OpenCode (via swayctl agent)."
    fi
else
    log_info "Skipped hotkey — add manually: bindsym \$mod+a exec \$term -e swayctl agent"
fi

# ---- system skill / AGENTS file ----------------------------------------------
if ask "Install a system 'skill' file so AI tools know this is a Debian/Sway box?"; then
    SKILL_SRC="$SCRIPT_DIR/skills/sway-setup-SKILL.md"
    if [ -f "$SKILL_SRC" ]; then
        mkdir -p "$HOME/.config/opencode"
        cp "$SKILL_SRC" "$HOME/.config/opencode/AGENTS.md" 2>/dev/null \
            && log_ok "Installed to ~/.config/opencode/AGENTS.md"
        if [ ! -f "$HOME/AGENTS.md" ]; then
            cp "$SKILL_SRC" "$HOME/AGENTS.md" 2>/dev/null \
                && log_ok "Also installed to ~/AGENTS.md."
        fi
    else
        log_warn "Skill file not found at $SKILL_SRC — skipping."
    fi
fi

echo
log_ok "OpenCode step complete."
log_info "Run 'opencode auth login' once to connect a provider; then just 'opencode'."