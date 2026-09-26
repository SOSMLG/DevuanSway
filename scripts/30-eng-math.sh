#!/usr/bin/env bash
# SWAY_DESC: Engineering math: Octave, Jupyter/IPython, SciPy stack + python-control venv, dev toolchain
# SWAY_DEFAULT: Y
# =======================================================
# 30-eng-math.sh — numerical / control-engineering core
# -------------------------------------------------------
# The MathWorks-free control-engineering daily driver:
#
#   octave                  GNU Octave + octave packages (signal/control)
#   jupyter-notebook        notebooks + ipython REPL
#   python3 - numpy/scipy/sympy/pandas/matplotlib (apt, system)
#   ~/.local/venv/eng       small pip venv with `control` (+ slycot when
#                           available) so python-control never touches apt
#   build-essential/cmake/git/curl/python3-pip   the dev toolchain
#
# Launchers come from the swayctl CLI (`swayctl eng octave|jupyter|…`).
# SymPy/PAAS tools install alongside the Debian copies — nothing here
# replaces the distro packages, so a plain `python3` still works.
#
# Idempotent: safe to re-run; the venv is created once.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Engineering math — Octave / Jupyter / control stack"

install_pkgs "Dev toolchain" \
    build-essential cmake git curl wget ca-certificates \
    python3-pip python3-venv python3-dev

install_pkgs "Numerical python (system)" \
    python3-numpy python3-scipy python3-sympy python3-pandas python3-matplotlib

install_pkgs "Octave + notebooks" \
    octave octave-control octave-signal octave-image \
    jupyter-notebook python3-ipython

# ---- python-control venv (pip world, kept out of apt) ------------------------
VENV="$HOME/.local/venv/eng"
if [ ! -x "$VENV/bin/python" ]; then
    log_info "Creating python-control venv at $VENV ..."
    mkdir -p "$HOME/.local/venv"
    if python3 -m venv "$VENV"; then
        "$VENV/bin/pip" install --upgrade pip
        "$VENV/bin/pip" install control  # python-control: pure-python backend by default
        if "$VENV/bin/pip" install slycot >/dev/null 2>&1; then
            log_ok "  slycot (BLAS backend) installed too."
        else
            log_warn "  slycot unavailable/unsupported here — control falls back to pure-python (fine)."
        fi
        log_ok "venv created: $VENV"
    else
        log_warn "  python3 -m venv failed — skipping python-control venv."
    fi
else
    # Refresh on re-run only if control is somehow missing.
    "$VENV/bin/pip" show control >/dev/null 2>&1 \
        || "$VENV/bin/pip" install control || true
    log_ok "python-control venv already present: $VENV"
fi

# ---- `swayctl eng` demos / convenience ---------------------------------------
mkdir -p "$HOME/.local/bin"
for launcher in octave jupyter; do
    if command -v $launcher >/dev/null 2>&1; then
        log_ok "$launcher: $(command -v $launcher)"
    fi
done

echo
log_ok "Engineering math stack ready."
log_info "  python -c 'import control'   in the $VENV venv"
log_info "  swayctl eng jupyter / swayctl eng octave — open them from sway"
log_info "  Matlab add-on: scripts/32-eng-matlab.sh"