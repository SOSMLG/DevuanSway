#!/usr/bin/env bash
# SWAY_DESC: Timeshift system snapshots (cron-based, no systemd timers)
# SWAY_DEFAULT: Y
# =======================================================
# Timeshift — system snapshot/restore
# -------------------------------------------------------
# Mint's signature safety-net: snapshot before a risky change,
# roll back with a couple of clicks. On Debian/Devuan the package
# depends on plain cron, not systemd — so it works fine on
# Devuan's default sysvinit/OpenRC setup.
#
# Installs the tool and ensures cron exists, but deliberately does
# NOT auto-configure a snapshot device or schedule — that's a
# one-time choice with real disk-space implications and Timeshift's
# own first-launch wizard is quick.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Timeshift"

install_pkgs "Timeshift" timeshift
install_pkgs "cron" cron

if is_installed timeshift; then
    log_ok "Timeshift installed."
    log_warn "One-time setup: run 'doas timeshift-launcher' (or find Timeshift in the"
    log_warn "app menu) to choose rsync vs BTRFS mode, storage, and a schedule."
else
    log_err "Timeshift installation failed."
fi