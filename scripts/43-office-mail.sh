#!/usr/bin/env bash
# SWAY_DESC: Office + mail: LibreOffice (Writer/Calc), Thunderbird, KeePassXC
# SWAY_DEFAULT: Y
# =======================================================
# Office + mail
# -------------------------------------------------------
# work-day essentials, installed lean:
#
#   libreoffice-writer + libreoffice-calc  (not the whole suite)
#   thunderbird                            mail/calendar (ESR)
#   keepassxc                              password vault (GUI)
#   gnome-keyring                          secret storage for the desktop
#
# Distro packages, no third-party repos. Idempotent: skips what's
# already there.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Office + mail"

install_pkgs "LibreOffice (Writer + Calc)" \
    libreoffice-writer libreoffice-calc libreoffice-gtk3
install_pkgs "Mail" thunderbird
install_pkgs "Passwords" keepassxc
install_pkgs "Keyring" gnome-keyring

echo
log_ok "Office + mail installed."
log_info "  KeePassXC integrates with swaylock: swayctl lock"