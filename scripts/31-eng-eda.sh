#!/usr/bin/env bash
# SWAY_DESC: Engineering EDA: Scilab/Xcos, Qucs, KiCad
# SWAY_DEFAULT: Y
# =======================================================
# 31-eng-eda.sh — circuit / PCB / block-diagram design
# -------------------------------------------------------
# The heavier analysis + design packages, split out from the math
# core so a box that only needs Octave+Jupyter stays lean:
#
#   scilab   (+ Xcos block-diagram / control simulation UI)  ~650 MB
#   qucs     (circuit simulation)
#   kicad    (PCB design)                                      ~1.2 GB
#
# All three are from excalibur/trixie — no third-party repos.
# Launch them from the grid menu or `swayctl eng <scilab|qucs|kicad>`.
#
# Idempotent: safe to re-run.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Engineering EDA — Scilab / Qucs / KiCad"

install_pkgs "Scilab + Xcos" scilab
install_pkgs "Circuit simulation" qucs
install_pkgs "PCB design" kicad

for bin in scilab qucs kicad; do
    if command -v "$bin" >/dev/null 2>&1; then
        log_ok "$bin: $(command -v "$bin")"
    else
        # kicad's entry is kicad; qucs is qucs; scilab's CLI is scilab-cli.
        log_warn "$bin not on PATH after install (expected for GUI-only variants)."
    fi
done

echo
log_ok "EDA tools installed."
log_info "  swayctl eng kicad   — PCB editor"
log_info "  swayctl eng scilab  — Xcos block-diagram editor"