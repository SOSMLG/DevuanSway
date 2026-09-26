#!/usr/bin/env bash
# SWAY_DESC: Chat: Vesktop (Discord) + Telegram (both Flatpak)
# SWAY_DEFAULT: Y
# =======================================================
# Chat
# -------------------------------------------------------
#   Vesktop   Vencord-powered Discord client (Flatpak: dev.vencord.Vesktop)
#   Telegram  Telegram Desktop (Flatpak: org.telegram.desktop — apt's
#             telegram-desktop is not in trixie, so Flatpak is the clean path)
#
# Both are user-scope Flatpaks from Flathub; no apt noise, updates
# ride `flatpak update`.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Chat apps (Flatpak)"

if ! command -v flatpak >/dev/null 2>&1; then
	log_err "flatpak not installed — run scripts/40-desktop-apps.sh first."
	exit 1
fi

flatpak remotes 2>/dev/null | grep -q flathub ||
	flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

install_flatpak_app() {
	local id="$1"
	if flatpak list --app 2>/dev/null | grep -q "^${id}[[:space:]]"; then
		log_ok "$id already installed."
		return 0
	fi
	log_info "Installing $id ..."
	flatpak install -y flathub "$id" 2>/dev/null &&
		log_ok "$id installed." ||
		log_warn "$id install failed/skipped (network or catalog)."
}

install_flatpak_app dev.vencord.Vesktop
install_flatpak_app org.telegram.desktop

echo
log_ok "Chat done."
log_info "Flatpak .desktop entries appear in the app menu / launcher after a relogin."
