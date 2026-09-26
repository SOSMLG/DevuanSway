#!/usr/bin/env bash
# SWAY_DESC: Media: OBS Studio, Kdenlive, GIMP + PhotoGIMP layout
# SWAY_DEFAULT: Y
# =======================================================
# Media & graphics
# -------------------------------------------------------
#   obs-studio   streaming/screen/Qt capture (best audio via pipewire)
#   kdenlive     non-linear video editor
#   gimp         image editor, then PhotoGIMP's Photoshop-like layout
#
# PhotoGIMP (https://github.com/Diolinux/PhotoGIMP) is fetched live
# and applied to GIMP's *actual* config dir (2.10 vs 3.0 checked at
# runtime); a 3.0 config is never forced onto a 2.10 profile.
# Native apt GIMP, not Flatpak — the .desktop Exec line is rewritten
# to /usr/bin/gimp.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Media & graphics"

install_pkgs "OBS Studio" obs-studio
install_pkgs "Kdenlive" kdenlive
install_pkgs "GIMP" gimp

# ---- PhotoGIMP layout (best-effort) ------------------------------------------
GIMP_MAJOR="$(dpkg-query -W -f='${Version}' gimp 2>/dev/null | cut -d. -f1)"
case "$GIMP_MAJOR" in
    3) GIMP_CFG="$HOME/.config/GIMP/3.0" ;;
    2) GIMP_CFG="$HOME/.config/GIMP/2.10" ;;
    *) GIMP_CFG="" ;;
esac

if [ -n "$GIMP_CFG" ] && ask "Apply PhotoGIMP's Photoshop-like layout to GIMP?"; then
    TMP="$(mktemp -d)"
    log_info "Fetching PhotoGIMP (github)..."
    if curl -fsSL --max-time 60 https://github.com/Diolinux/PhotoGIMP/archive/refs/heads/master.tar.gz \
        -o "$TMP/photogimp.tgz" && verify_download "$TMP/photogimp.tgz" 1024; then
        tar -xzf "$TMP/photogimp.tgz" -C "$TMP"
        SRC_DIR="$(find "$TMP" -maxdepth 2 -type d -iname 'PhotoGIMP*' | head -1)"
        if [ -n "$SRC_DIR" ] && [ -d "$SRC_DIR/.local/share/applications" ]; then
            mkdir -p "$GIMP_CFG" "$HOME/.local/share/applications"
            cp -a "$SRC_DIR/.config/GIMP/3.0/." "$GIMP_CFG/" 2>/dev/null || \
            cp -a "$SRC_DIR/.config/GIMP/2.10/." "$GIMP_CFG/" 2>/dev/null || true
            # Rewrite the (flatpak-flavoured) launcher to native gimp.
            if [ -f "$SRC_DIR/.local/share/applications/org.gimp.GIMP.desktop" ]; then
                sed -E 's#Exec=flatpak run [^ ]*(org\.gimp\.GIMP)?#Exec=/usr/bin/gimp#' \
                    "$SRC_DIR/.local/share/applications/org.gimp.GIMP.desktop" \
                    > "$HOME/.local/share/applications/org.gimp.GIMP.desktop" 2>/dev/null || true
            fi
            log_ok "PhotoGIMP layout applied to GIMP $GIMP_MAJOR ($GIMP_CFG)."
        else
            log_warn "PhotoGIMP layout structure not found in upstream tarball."
        fi
    else
        log_warn "PhotoGIMP fetch failed — GIMP installed with defaults."
    fi
    rm -rf "$TMP"
else
    log_ok "GIMP installed with its default layout."
fi

echo
log_ok "Media & graphics done."
log_info "  OBS + pipewire: check Inputs → Audio → use the PulseAudio device."