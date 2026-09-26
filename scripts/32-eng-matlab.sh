#!/usr/bin/env bash
# SWAY_DESC: Matlab prep: matlab-support + `swayctl eng matlab` installer helper
# SWAY_DEFAULT: Y
# =======================================================
# 32-eng-matlab.sh — the proprietary bridge
# -------------------------------------------------------
# MathWorks doesn't publish Matlab in apt, and its installer needs
# your account credentials — so this step cannot fetch the bits for
# you. What it DOES do is make the day you download them trivial:
#
#   * installs `matlab-support` — integrates a Manning .deb (the
#     mex/LD_BRIDGE, launcher, icon, /usr/local/bin/matlab) cleanly
#     into a Debian/Devuan system
#   * installs `swayctl eng matlab <file.deb>` — takes a Matlab .deb
#     you downloaded from MathWorks, verifies it, then installs it
#     with `dpkg -i` (recommends frobbing the run script so it binds
#     the venv'd numpy/scipy, but leaves your system python alone)
#
# The toolkit never fetches MathWorks content — download the Linux
# installer from <https://www.mathworks.com/downloads/> as the
# "Matlab (version) for Linux" archive in your browser, unpack it,
# and run `./install` inside — or grab the pre-built
# `R20XXxUpdateX_<hash>.deb` when the MathWorks page offers one.
#
# Idempotent: safe to re-run.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Matlab preparation"

install_pkgs "Matlab support" matlab-support

echo
log_ok "matlab-support installed — system ready for a MathWorks .deb."
log_info "  1) Download a Linux Matlab .deb from mathworks.com (account required)."
log_info "  2) Run:   swayctl eng matlab /path/to/Matlab_*.deb   — attaches it cleanly."
log_info "  Alternatively unpack the MathWorks archive and run ./install inside it."