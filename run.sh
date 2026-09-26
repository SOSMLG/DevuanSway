#!/usr/bin/env bash
# ==========================================
# sway-setup — Devuan 6 (Excalibur) + Sway — Ordered Runner
# Discovers steps from scripts/??-*.sh (sorted = run order), grouped
# into phases by leading digit: 1x core, 2x desktop, 3x engineering,
# 4x apps, 5x utils. Each step declares its own metadata:
#   # SWAY_DESC: one-line description
#   # SWAY_DEFAULT: Y|N
# asks Y/N per script with a default value.
# For a fully unattended run:  ./install.sh
# This runner is for when you want to pick-and-choose.
# ==========================================

set -uo pipefail
# NOTE: intentionally not using `set -e` here. Individual scripts manage
# their own error handling; one script failing should not silently abort
# every later step. Each script is still expected to exit non-zero on
# failure so this runner can report it.

# --- Colors ---
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[0;36m"
RESET="\033[0m"

# --- Directory setup ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

usage() {
    cat <<EOF
Usage: $0 [options]

Runs the toolkit's setup scripts in phase order, asking Y/N
per script. Options:

  --list                Print each step (phase, description, default) and exit.
  --phase a[,b]         Only run these phases: core,desktop,engineering,apps,utils
  --only a.sh,b.sh      Run only the listed scripts, in their defined order.
                        Accepts filenames with or without the '.sh' suffix,
                        with or without the numeric prefix (e.g. 'firefox'
                        matches '16-firefox.sh'). Pre-rename names still work.
  --yes, -y             Answer every prompt with its default (unattended).
  --full                Like --yes + treat every script's default as Y
                        (all optional groups included). Used by install.sh.
  --no-update           Skip the runner's single 'apt-get update'.
  --verify              After the run, run ./verify.sh and report results.
  -h, --help            Show this help.

TL;DR:  ./install.sh         one-command, everything, unattended
        ./run.sh --list      see what it would do
        ./run.sh --phase core,desktop
        ./run.sh --only firefox,useful-apps
EOF
}

# --- Flags -----------------------------------------------------------------
DO_LIST=0
DO_VERIFY=0
ASSUME_YES=0
FULL=0
SKIP_APT_UPDATE=0
ONLY_NAMES=()
PHASE_NAMES=()

while [ $# -gt 0 ]; do
    case "$1" in
        --list) DO_LIST=1 ;;
        --phase)
            [ $# -ge 2 ] || { echo -e "${RED}--phase needs a comma-separated list of phases.${RESET}"; exit 1; }
            shift
            IFS=',' read -ra _entries <<< "$1"
            PHASE_NAMES+=("${_entries[@]}")
            ;;
        --only)
            [ $# -ge 2 ] || { echo -e "${RED}--only needs a comma-separated list of scripts.${RESET}"; exit 1; }
            shift
            IFS=',' read -ra _entries <<< "$1"
            ONLY_NAMES+=("${_entries[@]}")
            ;;
        --yes|-y) ASSUME_YES=1 ;;
        --full) ASSUME_YES=1; FULL=1 ;;
        --no-update|--skip-apt-update) SKIP_APT_UPDATE=1 ;;
        --verify) DO_VERIFY=1 ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo -e "${RED}Unknown option: $1${RESET}"
            usage
            exit 1
            ;;
    esac
    shift
done

[ "$ASSUME_YES" -eq 1 ] && export SWAY_ASSUME_YES=1
[ "$FULL" -eq 1 ] && export SWAY_FULL=1

# --- Refuse to run as root directly ---
# Per-user state (Firefox profile, ~/.bashrc, sway configs, ~/.local/bin)
# must land in the real user's $HOME, not /root. Scripts escalate (doas)
# themselves for the bits that need it.
if [ "$(id -u)" -eq 0 ] && [ -z "${SUDO_USER:-${DOAS_USER:-}}" ]; then
    echo -e "${RED}Please run this as your normal user, not as root / doas bash run.sh.${RESET}"
    echo -e "${YELLOW}Each script will escalate itself (doas) for the parts that need it.${RESET}"
    exit 1
fi

# --- Distro check (Devuan/Devuan; both ship /etc/debian_version) ---
if [ -f /etc/debian_version ]; then
    echo -e "${GREEN}Debian-based system detected: $(cat /etc/debian_version)${RESET}"
    if [ -f /etc/devuan_version ]; then
        echo -e "${GREEN}Devuan detected: $(cat /etc/devuan_version) — OpenRC service handling active.${RESET}"
    fi
else
    echo -e "${YELLOW}Warning: this toolkit targets Devuan/Debian. Your system may not be compatible.${RESET}"
    if [ -z "${SWAY_ASSUME_YES:-}" ]; then
        read -r -p "Continue anyway? (y/N): " continue_anyway
        [[ "$continue_anyway" =~ ^[Yy]$ ]] || exit 1
    fi
fi

# --- Step discovery ----------------------------------------------------------
# Steps are scripts/??-*.sh, sorted. Phase comes from the leading digit.
# Description/default come from the script's own SWAY_* header lines.
phase_of() {
    case "${1:0:1}" in
        1) echo "core" ;;
        2) echo "desktop" ;;
        3) echo "engineering" ;;
        4) echo "apps" ;;
        5) echo "utils" ;;
        *) echo "misc" ;;
    esac
}

step_desc() {  # step_desc <file> — SWAY_DESC header (DEBSWAY_DESC legacy fallback)
    local d
    d="$(grep -m1 '^# SWAY_DESC:\|^# DEBSWAY_DESC:' "$1" 2>/dev/null \
        | sed -e 's/^# SWAY_DESC: *//' -e 's/^# DEBSWAY_DESC: *//')"
    printf '%s' "${d:-No description (add a SWAY_DESC header)}"
}

step_default() {  # step_default <file> — SWAY_DEFAULT header (DEBSWAY_DEFAULT legacy fallback)
    local d
    d="$(grep -m1 '^# SWAY_DEFAULT:\|^# DEBSWAY_DEFAULT:' "$1" 2>/dev/null \
        | sed -e 's/^# SWAY_DEFAULT: *//' -e 's/^# DEBSWAY_DEFAULT: *//' | tr -d '[:space:]')"
    case "${d^^}" in Y) echo "Y" ;; *) echo "N" ;; esac
}

# Pre-rename aliases (old name -> new file) so saved --only lists keep working.
# The Sep-2026 rehaul collapsed the old optional phase into "apps" and
# renumbered 3x=engineering / 4x=apps; old names still resolve here.
declare -A RENAMED=(
    [00-sway-core]=10-sway-core.sh [01-backports]=11-backports.sh
    [addUserToGroups]=12-user-groups.sh [hardwareSupport]=13-hardware.sh
    [bluetoothSetup]=14-bluetooth.sh [multimediaCodecs]=15-codecs.sh
    [firefoxHarden]=16-firefox.sh [installFonts]=17-fonts.sh
    [terminalButterbash]=18-butterbash.sh [fastfetchConfig]=19-fastfetch.sh
    [20-shell-upgrade]=20-shell-tools.sh [25-swayShellUpgrade]=20-shell-tools.sh
    [21-debsway-cli]=21-swayctl-cli.sh [26-debswayCli]=21-swayctl-cli.sh
    [catppuccinSway]=22-theme-default.sh [shellUpgrade]=20-shell-tools.sh
    [30-desktop-essentials]=40-desktop-apps.sh [desktopEssentials]=40-desktop-apps.sh
    [31-timeshift]=41-timeshift.sh [timeshiftSetup]=41-timeshift.sh
    [32-time-sync]=40-desktop-apps.sh [networkTimeSync]=40-desktop-apps.sh
    [33-useful-apps]=40-desktop-apps.sh [usefulApps]=40-desktop-apps.sh
    [34-opencode-agent]=42-opencode-agent.sh [aiOpencode]=42-opencode-agent.sh
    [40-vscodium]=47-editors.sh [installVscodium]=47-editors.sh
    [41-dev-essentials]=30-eng-math.sh [vscodiumDevSetup]=30-eng-math.sh
    [41-vscodium-dev]=47-editors.sh [vscodium-dev]=47-editors.sh
    [42-dev-extras]=30-eng-math.sh [dev-extras]=30-eng-math.sh
    [43-photogimp]=44-media.sh [installPhotogimp]=44-media.sh
    [44-gaming]=45-gaming.sh [gamingSetup]=45-gaming.sh
    [45-chat]=46-chat.sh [vesktopTelegram]=46-chat.sh
    [46-neovim]=47-editors.sh [neovimSetup]=47-editors.sh
    [systemMaintenance]=50-maintenance.sh [configBackup]=51-backup.sh
    [exportToSkel]=52-skel-export.sh
)

# Normalize a --only/--phase token to a step filename (no dir) or empty.
resolve_step() {  # resolve_step <token> -> filename
    local tok="$1" base f
    tok="${tok%.sh}"
    # Exact filename (with or without numeric prefix already included).
    for f in "$SCRIPTS_DIR"/??-*.sh; do
        [ -f "$f" ] || continue
        base="$(basename "$f" .sh)"
        if [ "$base" = "$tok" ]; then printf '%s\n' "$(basename "$f")"; return 0; fi
    done
    # Short name: suffix after the numeric prefix.
    for f in "$SCRIPTS_DIR"/??-*.sh; do
        [ -f "$f" ] || continue
        base="$(basename "$f" .sh)"
        if [ "${base#??-}" = "$tok" ]; then printf '%s\n' "$(basename "$f")"; return 0; fi
    done
    # Pre-rename alias.
    if [ -n "${RENAMED[$tok]+x}" ]; then
        echo -e "${YELLOW}Note: '$tok' was renamed to '${RENAMED[$tok]}' — update your notes.${RESET}" >&2
        printf '%s\n' "${RENAMED[$tok]}"
        return 0
    fi
    return 1
}

# Ordered step list: "file|phase|desc|default"
STEPS=()
shopt -s nullglob
for _f in "$SCRIPTS_DIR"/??-*.sh; do
    _b="$(basename "$_f")"
    STEPS+=("$_b|$(phase_of "$_b")|$(step_desc "$_f")|$(step_default "$_f")")
done
shopt -u nullglob
unset _f _b

if [ "${#STEPS[@]}" -eq 0 ]; then
    echo -e "${RED}No steps found in $SCRIPTS_DIR/??-*.sh — broken checkout?${RESET}"
    exit 1
fi

# --- --list: print the ordering and exit ----------------------------------
if [ "$DO_LIST" -eq 1 ]; then
    echo -e "${BLUE}Toolkit steps, in run order (by phase):${RESET}\n"
    _last_phase=""
    i=1
    for ENTRY in "${STEPS[@]}"; do
        SCRIPT="${ENTRY%%|*}"
        REST="${ENTRY#*|}"
        PHASE="${REST%%|*}"
        REST="${REST#*|}"
        DESC="${REST%%|*}"
        DEFAULT="${REST##*|}"
        if [ "$PHASE" != "$_last_phase" ]; then
            echo -e "${CYAN}── $PHASE ──${RESET}"
            _last_phase="$PHASE"
        fi
        printf '  %2d.  %-28s default: %-1s  %s\n' "$i" "$SCRIPT" "$DEFAULT" "$DESC"
        ((i++)) || true
    done
    unset _last_phase
    echo
    echo -e "Phases: core desktop engineering apps utils  (filter: ${CYAN}./run.sh --phase core,desktop${RESET})"
echo -e "Minimal (no applications): ${CYAN}./run.sh --phase core,desktop${RESET}"
    echo -e "Run everything unattended: ${CYAN}./install.sh${RESET}"
    echo -e "Run everything interactively: ${CYAN}./run.sh${RESET}"
    exit 0
fi

# --- Selection: --phase and/or --only, keeping defined order ----------------
SELECTED=()
if [ "${#ONLY_NAMES[@]}" -gt 0 ] || [ "${#PHASE_NAMES[@]}" -gt 0 ]; then
    declare -A WANT_STEPS=() WANT_PHASES=()
    for n in "${ONLY_NAMES[@]:-}"; do
        [ -z "$n" ] && continue
        if _r="$(resolve_step "$n")"; then
            WANT_STEPS["$_r"]=1
        else
            echo -e "${YELLOW}⚠ Not a toolkit step, ignoring: $n${RESET}"
        fi
    done
    for p in "${PHASE_NAMES[@]:-}"; do
        [ -z "$p" ] && continue
        case "$p" in
            core|desktop|engineering|apps|utils|misc) WANT_PHASES["$p"]=1 ;;
            *) echo -e "${YELLOW}⚠ Unknown phase, ignoring: $p (core|desktop|engineering|apps|utils)${RESET}" ;;
        esac
    done
    unset n p
    for ENTRY in "${STEPS[@]}"; do
        SCRIPT="${ENTRY%%|*}"
        REST="${ENTRY#*|}"
        PHASE="${REST%%|*}"
        _hit=0
        [ "${#ONLY_NAMES[@]}" -gt 0 ] && [ -n "${WANT_STEPS[$SCRIPT]+x}" ] && _hit=1
        [ "${#PHASE_NAMES[@]}" -gt 0 ] && [ -n "${WANT_PHASES[$PHASE]+x}" ] && _hit=1
        # Both filters given: step must satisfy at least one (union).
        if [ "$_hit" -eq 1 ]; then
            SELECTED+=("$ENTRY")
        fi
    done
    unset _hit
    if [ "${#SELECTED[@]}" -eq 0 ]; then
        echo -e "${RED}No matching steps. Use --list to see available ones.${RESET}"
        exit 1
    fi
else
    SELECTED=("${STEPS[@]}")
fi

echo -e "${BLUE}=========================================================${RESET}"
echo -e "${BLUE}   sway-setup — Devuan 6 (Excalibur) + Sway${RESET}"
echo -e "${BLUE}=========================================================${RESET}\n"

# --- One apt refresh, then let the scripts skip their own ------------------
# NOTE: run.sh never sources scripts/lib/common.sh, so it keeps a local
# priv() instead of the shared helper (same contract: doas first, sudo fallback).
priv() {
    if command -v doas >/dev/null 2>&1; then doas "$@"; else sudo "$@"; fi
}

# --- One password prompt for the whole run -----------------------------------
# doas `persist` caches auth only ~5 min after the last privileged call; a
# full toolkit run takes far longer, so without this you'd re-type your
# password every few steps. Prime the timestamp once (this is the one
# prompt), then refresh it every minute in the background so it never
# expires mid-run. Both escalators are refreshed: the box may start on
# sudo and gain doas halfway through (10-sway-core.sh installs opendoas
# and writes the persist rule), while priv() prefers doas whenever present.
echo -e "${CYAN}[*] Caching privilege — one password prompt for the whole run...${RESET}"
if ! priv true; then
    if command -v sudo >/dev/null 2>&1 && sudo -v; then
        echo -e "${YELLOW}[!] doas not usable yet — continuing on sudo; 12-user-groups.sh sets up doas persist mid-run.${RESET}"
    else
        echo -e "${RED}Privilege escalation failed — fix doas/sudo setup, then re-run.${RESET}"
        exit 1
    fi
fi
KEEPALIVE_PID=""
_priv_keepalive() {
    while true; do
        sleep 60
        if command -v sudo >/dev/null 2>&1; then sudo -n true >/dev/null 2>&1 || true; fi
        if command -v doas >/dev/null 2>&1; then doas -n true >/dev/null 2>&1 || true; fi
    done
}
_priv_keepalive &
KEEPALIVE_PID=$!
_stop_keepalive() {
    if [ -n "${KEEPALIVE_PID:-}" ]; then kill "$KEEPALIVE_PID" 2>/dev/null || true; fi
}
trap _stop_keepalive EXIT INT TERM

export SWAY_SKIP_APT_UPDATE=1
if [ "$SKIP_APT_UPDATE" -eq 0 ]; then
    echo -e "${CYAN}[*] Refreshing package lists once (scripts skip their own refreshes)...${RESET}"
    if ! priv apt-get update; then
        echo -e "${YELLOW}[!] apt-get update failed — continuing anyway. Some installs may fail if lists are stale.${RESET}"
    fi
fi

# --- Summary log -----------------------------------------------------------
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sway-setup"
mkdir -p "$STATE_DIR"
LOG_FILE="$STATE_DIR/last-run.log"
record_run() { printf '%(%F %T)T  %s\n' -1 "$1" >> "$LOG_FILE"; }

record_run "$0 ${ONLY_NAMES[*]:-all} phases:${PHASE_NAMES[*]:-all} (assume-yes=${ASSUME_YES:-0}, full=${FULL:-0}, skip-apt=${SKIP_APT_UPDATE:-0})"

FAILED=()
SKIPPED=()

for ENTRY in "${SELECTED[@]}"; do
    SCRIPT="${ENTRY%%|*}"
    REST="${ENTRY#*|}"
    PHASE="${REST%%|*}"
    REST="${REST#*|}"
    DESC="${REST%%|*}"
    DEFAULT="${REST##*|}"
    SCRIPT_PATH="$SCRIPTS_DIR/$SCRIPT"

    echo -e "${YELLOW}▶ [$PHASE] ${SCRIPT}${RESET}"
    echo -e "   ${CYAN}${DESC}${RESET}"

    if [ ! -f "$SCRIPT_PATH" ]; then
        echo -e "${RED}   ❌ Script not found: $SCRIPT_PATH${RESET}\n"
        FAILED+=("$SCRIPT (missing)")
        record_run "$SCRIPT  missing"
        continue
    fi

    if [ -n "${SWAY_FULL:-}" ]; then
        DEFAULT="Y"
    fi
    DEFAULT=${DEFAULT^^}
    PROMPT="   ➤ Run this script? (y/N): "
    [ "$DEFAULT" = "Y" ] && PROMPT="   ➤ Run this script? (Y/n): "

    if [ -n "${SWAY_ASSUME_YES:-}" ]; then
        ANSWER="$DEFAULT"
        echo -e "${CYAN}   (unattended) → ${ANSWER}${RESET}"
    else
        read -rp "$PROMPT" ANSWER
        ANSWER=${ANSWER:-$DEFAULT}
    fi
    echo

    case "${ANSWER^^}" in
        Y)
            echo -e "${GREEN}   ✅ Running $SCRIPT...${RESET}"
            if bash "$SCRIPT_PATH"; then
                echo -e "${GREEN}   ✅ Done: $SCRIPT${RESET}\n"
                record_run "$SCRIPT  ok"
            else
                echo -e "${RED}   ❌ $SCRIPT exited with an error (continuing with the rest)${RESET}\n"
                FAILED+=("$SCRIPT")
                record_run "$SCRIPT  failed"
            fi
            ;;
        *)
            echo -e "${YELLOW}   ⚠ Skipped: $SCRIPT${RESET}\n"
            SKIPPED+=("$SCRIPT")
            record_run "$SCRIPT  skipped"
            ;;
    esac
done

# --- --verify: end-state audit --------------------------------------------
if [ "$DO_VERIFY" -eq 1 ]; then
    VERIFY_PATH="$SCRIPT_DIR/verify.sh"
    if [ -f "$VERIFY_PATH" ]; then
        echo -e "${BLUE}=========================================================${RESET}"
        echo -e "${BLUE}   🔍 Verifying setup...${RESET}"
        echo -e "${BLUE}=========================================================${RESET}\n"
        if bash "$VERIFY_PATH"; then
            record_run "verify  ok"
        else
            record_run "verify  issues"
        fi
    else
        echo -e "${YELLOW}⚠ verify.sh not found — skipping --verify.${RESET}"
    fi
fi

echo -e "${BLUE}=========================================================${RESET}"
echo -e "${BLUE}   🏁 All tasks processed.${RESET}"
echo -e "${BLUE}=========================================================${RESET}"

if [ "${#SKIPPED[@]}" -gt 0 ]; then
    echo -e "${YELLOW}Skipped: ${SKIPPED[*]}${RESET}"
fi

if [ "${#FAILED[@]}" -gt 0 ]; then
    echo -e "${RED}Failed:  ${FAILED[*]}${RESET}"
    echo -e "${YELLOW}Re-run individual scripts directly with: bash scripts/<name>.sh${RESET}"
    record_run "result  failed"
    exit 1
fi

echo -e "${GREEN}Done. A reboot is recommended (group membership + new services).${RESET}"
record_run "result  ok"
echo -e "${CYAN}Full log: $LOG_FILE${RESET}"
