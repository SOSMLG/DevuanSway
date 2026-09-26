#!/usr/bin/env bash
# =======================================================
# swayctl/lib/eng.sh — Engineering tooling launcher
# -------------------------------------------------------
# Handles the engineering stack installed by scripts/
# 30-eng-math / 31-eng-eda / 32-eng-matlab: validates that
# the tool exists on this machine (never installs silently),
# then opens it in the right context (foot terminal for CLI
# tools, windowed for GUI tools).
# =======================================================
[ -n "${_SWAYCTL_LIB_ENG_LOADED:-}" ] && return 0
_SWAYCTL_LIB_ENG_LOADED=1

ENG_VENV="$HOME/.local/venv/eng"

_eng_require() {
    command -v "$1" >/dev/null 2>&1 || {
        d_err "$1 not installed — run scripts/${2:-}.sh from SwaySetup."
        return 1
    }
}

_eng_in_term() {
    local bin="$1"; shift
    local tb
    tb="$(term_bin)" || { d_err "no terminal found"; return 1; }
    exec "$tb" -e "$bin" "$@" >/dev/null 2>&1 &
}

cmd_eng() {
    case "$1" in
        octave)
            _eng_require octave 30-eng-math.sh || return 1
            setsid --fork octave --gui >/dev/null 2>&1 &
            ;;
        jupyter|notebook)
            [ -x "$ENG_VENV/bin/jupyter" ] || _eng_require jupyter-notebook 30-eng-math.sh || return 1
            local jb
            if [ -x "$ENG_VENV/bin/jupyter" ]; then jb="$ENG_VENV/bin/jupyter"; else jb="$(command -v jupyter-notebook)"; fi
            setsid --fork "$jb" --notebook-dir="$HOME" >/dev/null 2>&1 &
            d_ok "Jupyter starting in ~ — browser opens automatically."
            ;;
        scilab)
            _eng_require scilab 31-eng-eda.sh || return 1
            setsid --fork scilab >/dev/null 2>&1 &
            ;;
        qucs)
            _eng_require qucs 31-eng-eda.sh || return 1
            setsid --fork qucs >/dev/null 2>&1 &
            ;;
        kicad)
            _eng_require kicad 31-eng-eda.sh || return 1
            setsid --fork kicad >/dev/null 2>&1 &
            ;;
        matlab)
            # Proprietary: matlab-support is what we install from Debian; the
            # actual Matlab tarball/.deb must be obtained from MathWorks by the
            # user. `swayctl eng matlab <file.deb>` installs a provided .deb.
            if [ -n "${2:-}" ]; then
                [ -f "$2" ] || { d_err "No such file: $2"; return 1; }
                if command -v matlab >/dev/null 2>&1; then
                    d_ok "matlab already installed."
                else
                    d_log "Installing $2..."
                    priv dpkg -i "$2" || { priv apt-get -f install -y || return 1; }
                    d_ok "matlab installed."
                fi
            elif command -v matlab >/dev/null 2>&1; then
                setsid --fork matlab -desktop >/dev/null 2>&1 &
            else
                d_log "Matlab not installed yet. Get the installer from"
                d_log "  https://www.mathworks.com/downloads/"
                d_log "then run: swayctl eng matlab /path/to/matlab.deb"
            fi
            ;;
        venv|env)
            # Engineering Python environment (~/.local/venv/eng).
            if [ -x "$ENG_VENV/bin/python" ]; then
                d_ok "venv exists: $ENG_VENV (python $( "$ENG_VENV/bin/python" -c 'import sys;print(sys.version_info[:2])' 2>/dev/null ))"
                if ! "$ENG_VENV/bin/python" -c 'import control' >/dev/null 2>&1; then
                    d_log "Installing python-control into the venv..."
                    "$ENG_VENV/bin/pip" install --upgrade control >/dev/null 2>&1 \
                        && d_ok "python-control installed" || d_warn "python-control install failed"
                fi
            else
                d_log "Creating engineering venv at $ENG_VENV (first run)..."
                command -v python3 >/dev/null 2>&1 || { d_err "python3 missing."; return 1; }
                python3 -m venv --system-site-packages "$ENG_VENV" 2>/dev/null || python3 -m venv "$ENG_VENV"
                "$ENG_VENV/bin/pip" install --upgrade pip >/dev/null 2>&1
                "$ENG_VENV/bin/pip" install control >/dev/null 2>&1 \
                    && d_ok "python-control installed" || d_warn "python-control pip install failed (network?)"
                d_ok "venv ready: source $ENG_VENV/bin/activate"
            fi
            ;;
        list)
            printf '  %-8s %s\n' "octave"  "MATLAB-like numerical computing (GUI)"
            printf '  %-8s %s\n' "jupyter" "Notebooks (venv or apt)"
            printf '  %-8s %s\n' "scilab"  "Xcos + SciLab (block schemes)"
            printf '  %-8s %s\n' "qucs"    "SPICE + RF schematics"
            printf '  %-8s %s\n' "kicad"   "PCB design"
            printf '  %-8s %s\n' "matlab"  "MathWorks Matlab (BYO .deb)"
            printf '  %-8s %s\n' "venv"    "~/.local/venv/eng (python-control)"
            ;;
        *)
            printf '%s\n' "octave" "jupyter" "scilab" "qucs" "kicad" "matlab" "venv" | launcher_pick "ENGINEERING" | while read -r t; do cmd_eng "$t"; done
            ;;
    esac
}