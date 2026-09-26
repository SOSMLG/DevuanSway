#!/usr/bin/env bash
# SWAY_DESC: WiFi/Bluetooth/AMD GPU firmware, microcode + fwupd
# SWAY_DEFAULT: Y
# =======================================================
# Hardware Support — firmware, microcode, firmware updates
# -------------------------------------------------------
# Covers the "why doesn't my WiFi/Bluetooth work out of the
# box" class of issues, which is almost always a missing
# non-free firmware blob rather than a real driver problem.
# Also installs CPU microcode (auto-detected Intel vs AMD)
# and fwupd for BIOS/UEFI + peripheral firmware updates via
# LVFS, surfaced with fwupdmgr CLI on this Sway setup.
#
# All of this is inert on hardware it doesn't apply to —
# firmware blobs sit unused in /lib/firmware until matching
# hardware is present, so installing the common set doesn't
# conflict with staying minimal.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

if [ "$(id -u)" -eq 0 ]; then
    log_err "Do not run this as root."
    exit 1
fi

echo -e "${CYAN}=========================================================${NC}"
echo -e "${CYAN} Hardware Support${NC}"
echo -e "${CYAN}=========================================================${NC}"

log_info "Refreshing package lists..."
apt_update || { log_err "apt-get update failed, aborting."; exit 1; }

# Firmware lives in non-free-firmware, which minimal installs often lack.
# Enable it (idempotent snippet file) instead of silently skipping firmware.
ensure_repo_component non-free-firmware \
    || log_warn "Continuing without non-free-firmware — firmware steps may skip."

# ---------------------------------------------------------------------------
# 1. Common WiFi/Bluetooth firmware — Wi-Fi on the L14 G2 AMD is Intel
#    (AX200) or Realtek/MediaTek depending on the exact SKU, so install
#    the broad set. firmware-amd-graphics covers the AMD Vega iGPU; the
#    rest covers Wi-Fi/BT modules and misc devices.
# ---------------------------------------------------------------------------
if ask "Install common WiFi/Bluetooth/GPU firmware?"; then
    if check_repo_package firmware-iwlwifi "non-free-firmware"; then
        install_pkgs "WiFi/Bluetooth/GPU firmware" \
            firmware-iwlwifi firmware-realtek firmware-atheros \
            firmware-brcm80211 firmware-misc-nonfree firmware-linux \
            firmware-amd-graphics
    else
        log_warn "Skipping firmware — non-free-firmware repo component is missing."
        log_warn "Run scripts/11-backports.sh or add 'non-free-firmware' to your suite line."
    fi
fi

# ---------------------------------------------------------------------------
# 2. CPU microcode — auto-detected, never both
# ---------------------------------------------------------------------------
if ask "Install CPU microcode updates (auto-detects Intel/AMD)?"; then
    VENDOR="$(grep -m1 -oE 'GenuineIntel|AuthenticAMD' /proc/cpuinfo || true)"
    case "$VENDOR" in
        GenuineIntel)
            log_info "Detected Intel CPU."
            if check_repo_package intel-microcode "non-free-firmware"; then
                install_pkgs "Intel microcode" intel-microcode
            fi
            ;;
        AuthenticAMD)
            log_info "Detected AMD CPU."
            if check_repo_package amd64-microcode "non-free-firmware"; then
                install_pkgs "AMD microcode" amd64-microcode
            fi
            ;;
        *)
            log_warn "Could not detect CPU vendor from /proc/cpuinfo, skipping microcode."
            ;;
    esac
fi

# ---------------------------------------------------------------------------
# 3. fwupd — BIOS/UEFI + peripheral firmware updates via LVFS.
#    Check for updates any time with: fwupdmgr get-updates
# ---------------------------------------------------------------------------
if ask "Install fwupd (BIOS/UEFI + device firmware updates)?"; then
    install_pkgs "fwupd" fwupd

    if is_installed fwupd; then
        start_service fwupd
        log_ok "fwupd installed. Check for updates: fwupdmgr get-updates"
    fi
fi

# ---------------------------------------------------------------------------
# 4. lm-sensors — used by sway scripts for temperature warnings
# ---------------------------------------------------------------------------
install_pkgs "Hardware sensors (lm-sensors)" lm-sensors

echo -e "${GREEN}Hardware support step complete.${NC}"
log_warn "A reboot is recommended so newly installed firmware/microcode is loaded."
