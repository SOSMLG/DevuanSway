#!/usr/bin/env bash
# =======================================================
# swayctl/lib/doctor.sh — session self-check
# -------------------------------------------------------
# Read-only health report for the sway desktop: compositor,
# bar choice, theme + palette integrity, wallpaper, core
# binaries, running services. Exits non-zero on problems.
# =======================================================
[ -n "${_SWAYCTL_LIB_DOCTOR_LOADED:-}" ] && return 0
_SWAYCTL_LIB_DOCTOR_LOADED=1

check_bins() {
    local missing=0 b
    for b in "$@"; do
        if command -v "$b" >/dev/null 2>&1; then
            d_ok "$b"
        else
            d_err "missing: $b"
            missing=$((missing+1))
        fi
    done
    return "$missing"
}

doctor_run() {
    d_log "swayctl doctor — $CS_INSTALL"
    echo

    local theme_name
    theme_name="$(current_theme)"
    d_log "Theme: $theme_name"
    if load_palette "$(theme_dir "$theme_name")"; then
        d_ok "palette.sh valid (${#C_BG} bg)"
    else
        d_err "palette.sh broken"
    fi

    local i=0 total=0
    for t in "$CS_THEMES"/*/palette.sh; do
        [ -f "$t" ] && total=$((total+1))
    done
    i="$(theme_list | wc -l)"
    d_log "Themes: $i installed / $total bundled"

    if is_under_sway; then
        d_ok "sway session detected (swaymsg ok)"
        d_log "Compositor: $(swaymsg -t get_version 2>/dev/null | grep -oP '"version": "\K[^"]*' | head -1)"
    else
        d_warn "not under a live sway session"
    fi

    echo
    d_log "Core binaries:"
    check_bins sway swaymsg swaylock swayidle swaybg foot rofi grim slurp wl-copy \
               cliphist swaync playerctl gammastep kanshi brightnessctl \
               || { echo; d_err "Some core binaries are missing."; return 1; }

    echo
    d_log "Bar: sway (built-in swaybar) — no separate bar daemon"

    local bgm
    bgm="$(get_marker bg)"
    if [ -n "$bgm" ] && [ -f "$bgm" ]; then
        d_ok "Wallpaper: $bgm"
    else
        d_warn "Wallpaper marker not set — using config fallback (swayctl bg set)"
    fi

    echo
    d_log "Services:"
    for s in pipewire pipewire-pulse wireplumber kanshi swaync; do
        if pgrep -x "$s" >/dev/null 2>&1; then d_ok "$s running"; else d_warn "$s not running"; fi
    done

    echo
    d_log "Stray screenshot overlays:"
    local stray=0 p
    for p in rofi wofi wlogout slurp grim swappy wf-recorder; do
        if pgrep -x "$p" >/dev/null 2>&1; then
            d_warn "$p running — dismiss with: swayctl kill"
            stray=1
        fi
    done
    [ "$stray" -eq 0 ] && d_ok "none"

    echo
    d_ok "doctor done."
}
