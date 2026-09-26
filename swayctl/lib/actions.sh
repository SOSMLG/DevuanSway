#!/usr/bin/env bash
# =======================================================
# swayctl/lib/actions.sh — every interactive/desktop action
# -------------------------------------------------------
# Implements the surface exposed by bin/swayctl: launchers,
# clipboard, screenshots, sound, network, toggles, status,
# wallpaper + bar management.
# =======================================================
[ -n "${_SWAYCTL_LIB_ACTIONS_LOADED:-}" ] && return 0
_SWAYCTL_LIB_ACTIONS_LOADED=1

# ---- launcher / menu ---------------------------------------------------------
# launcher_apps — app grid (drun mode) via the active launcher frontend.
launcher_apps() {
	local bin
	bin="$(launcher_bin)" || { d_err "No picker installed (need rofi)."; return 1; }
	case "$bin" in
		rofi) exec rofi -show drun ;;
		wofi) exec wofi --show drun --insensitive --prompt "Apps: " ;;
	esac
}

cmd_launcher() { launcher_apps; }

cmd_run() {
	local exe
	exe="$(launcher_pick "Run $(hostname)")" || return 1
	[ -n "$exe" ] && setsid --fork "$exe" >/dev/null 2>&1 &
}

cmd_menu() {
    local action="$1"
    [ -z "$action" ] && action="$(printf '%s\n' \
        "Theme set|" "Theme cycle|" "Power menu|swayctl power" \
        "Lock screen|swayctl lock" "Wallpaper panel|swayctl bg panel" \
        "Bar layout|swayctl bar panel" "Clipboard history|swayctl clip pick" \
        "Take screenshot|swayctl shot menu" "Record screen|swayctl shot record" \
        "Sound panel|swayctl sound panel" "Network panel|swayctl wire panel" \
        "Update system|swayctl update" "Doctor|swayctl doctor" \
        | sed 's/^[^|]*|//' )"
    # superseded by the interactive palette below — kept for API compatibility
    [ "$action" = "Theme set|" ] && action=""
    if [ -n "$action" ]; then
        eval "$action"
        return $?
    fi

	if ! launcher_bin >/dev/null 2>&1; then
		d_err "No picker installed — try: swayctl theme|bg|bar directly."
		return 1
	fi
    local sb
    sb="$(swayctl_bin)"
    local pick
    pick="$({
        local t
        for t in $(theme_list); do printf 'Theme  %s\n' "$t"; done
        printf '%s\n' "Wallpaper panel" "Power menu" "Lock screen" \
            "Clipboard history" "Screenshot menu" "Record screen" \
            "Sound panel" "Night light toggle" "Do-not-disturb toggle" \
            "Update system" "Doctor"
    } | launcher_pick "swayctl")"
    [ -z "$pick" ] && return 0
    case "$pick" in
        "Theme  "*)      "$sb" theme set "${pick#Theme  }" ;;
        "Wallpaper panel")      "$sb" bg panel ;;
        "Power menu")           "$sb" power ;;
        "Lock screen")          "$sb" lock ;;
        "Clipboard history")    "$sb" clip pick ;;
        "Screenshot menu")      "$sb" shot menu ;;
        "Record screen")        "$sb" shot record ;;
        "Sound panel")          "$sb" sound panel ;;
        "Night light toggle")   "$sb" toggle night ;;
        "Do-not-disturb toggle") "$sb" toggle dnd ;;
        "Update system")        "$sb" update ;;
        "Doctor")               "$sb" doctor ;;
    esac
}

cmd_keys() {
    # Second arg isn't needed: we always grep the live config.
    local cfg="$CS_CONFIG/sway/config"
    [ -f "$cfg" ] || { d_err "No sway config at $cfg"; return 1; }
    local out
    out="$(grep -nE '^\s*bindsym' "$cfg" | sed -E \
        -e 's/exec ([^ ]+)/→ \1/' \
        -e 's/exec_always ([^ ]+)/→ \1/' \
        -e 's#\s+.*exec ##' \
        | sed -E 's/^([0-9]+):\s+bindsym\s+([^ ]+)\s+(.*)$/\2: \3/')"
    if launcher_bin >/dev/null 2>&1; then
		printf '%s\n' "$out" | launcher_pick "Keybindings (from sway/config)"
	else
		printf '%s\n' "$out"
	fi
}

# ---- wallpaper ---------------------------------------------------------------
WALLPAPER_DIR="$CS_CONFIG/sway/wallpapers"

cmd_bg() {
    case "$1" in
        set)
            local f="${2:-}"
            [ -n "$f" ] || f="$(launcher_pick "Wallpaper")" < <(ls "$WALLPAPER_DIR" 2>/dev/null)
            [ -n "$f" ] || return 1
            [[ "$f" != /* ]] && f="$WALLPAPER_DIR/$f"
            [ -f "$f" ] || { d_err "No such file: $f"; return 1; }
            swaymsg "output * bg \"$f\" fill" >/dev/null 2>&1
            set_marker bg "$f"
            notify "Wallpaper" "$(basename "$f")"
            ;;
        cycle)
            local f
            f="$(ls "$WALLPAPER_DIR"/*.png "$WALLPAPER_DIR"/*.jpg "$WALLPAPER_DIR"/*.jpeg "$WALLPAPER_DIR"/*.webp 2>/dev/null | shuf -n 1)"
            [ -n "$f" ] && cmd_bg set "$f"
            ;;
        random) cmd_bg cycle ;;
        reset)
            rm -f "$CS_STATE/bg"
            if is_under_sway; then
                swaymsg reload >/dev/null 2>&1
            fi
            ;;
        apply)
            local m
            m="$(get_marker bg)"
            if [ -n "$m" ] && [ -f "$m" ]; then
                swaymsg "output * bg \"$m\" fill" >/dev/null 2>&1
            elif is_under_sway; then
                swaymsg reload >/dev/null 2>&1
            fi
            ;;
        panel|*) cmd_bg set ;;
    esac
}

# ---- bar ----------------------------------------------------------------------
cmd_bar() {
    local mode="$1"
    case "$mode" in
        restart|reload|swaybar)
            is_under_sway && swaymsg reload >/dev/null 2>&1 || true
            d_ok "Bar: sway (built-in swaybar)"
            ;;
        panel)
            d_ok "Bar: sway (built-in swaybar) — nothing to configure"
            ;;
        *) usage ;;
    esac
}

# ---- clipboard ----------------------------------------------------------------
cmd_clip() {
    case "$1" in
        watch)
            command -v cliphist >/dev/null 2>&1 && cliphist watch >/dev/null 2>&1 &
            ;;
        pick)
            local sel
            sel="$(cliphist list 2>/dev/null | launcher_pick "Clipboard")"
            [ -n "$sel" ] && printf '%s\n' "$sel" | cliphist decode | wl-copy
            ;;
        clear)
            cliphist clear
            d_ok "Clipboard history cleared."
            ;;
    esac
}

# ---- screenshots ----------------------------------------------------------------
SHOT_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/screenshots"

cmd_shot() {
    mkdir -p "$SHOT_DIR"
    local name
    case "$1" in
        full)   name="$SHOT_DIR/$(date +%F_%H%M%S).png"; grim "$name" ;;
        area)
            # Abandoned selection (Esc) or >30s idle cancels silently — an
            # empty geometry would make grim error to stderr for nothing.
            local geo
            geo="$(timeout 30 slurp -d)" || return 0
            name="$SHOT_DIR/$(date +%F_%H%M%S).png"
            grim -g "$geo" "$name"
            ;;
        annotate)
            local geo
            geo="$(timeout 30 slurp -d)" || return 0
            name="$(mktemp --suffix=.png)"
            grim -g "$geo" "$name"
            command -v swappy >/dev/null 2>&1 && swappy -f "$name" -o "$SHOT_DIR/$(date +%F_%H%M%S)_edit.png"
            ;;
        record)
            local rec="$SHOT_DIR/$(date +%F_%H%M%S).mp4"
            if pgrep -x wf-recorder >/dev/null 2>&1; then
                pkill -INT -x wf-recorder 2>/dev/null
                notify "Recording saved" "$(ls -t "$SHOT_DIR"/*.mp4 2>/dev/null | head -1)"
            else
                d_ok "Recording to $rec — use the same shortcut again to stop."
                notify "Recording" "$(basename "$rec") — same key to stop."
                wf-recorder -f "$rec" >/dev/null 2>&1 &
            fi
            ;;
        menu|*)
            local act
            act="$(printf '%s\n' "full" "area" "annotate (swappy)" "record" | launcher_pick "Screenshot")"
            # Cancel (Escape) must exit cleanly: re-invoking with an empty
            # pick recurses into the `*` default and respawns the picker in
            # an instant, unkillable loop — the original bug.
            [ -z "$act" ] && return 0
            cmd_shot "$act"
            ;;
    esac
    case "$1" in full|area)
        [ -f "$name" ] && { wl-copy < "$name"; notify "Screenshot" "$(basename "$name") (copied)"; }
        ;;
    esac
}

# cmd_kill — "get me out": deterministically kill any stuck screenshot
# overlay (rofi/wofi pickers, swappy editor, wlogout grid, slurp selection,
# grim). Wired to $mod+Ctrl+Escape (--locked, so it works even right after
# an unlock) and folded into cmd_lock so overlays never survive a lock
# cycle. Only exact process names are touched — clipboard daemons (cliphist
# watch / wl-paste) are never affected.
#   swayctl kill [q]   (q = quiet: only say what was actually killed)
cmd_kill() {
    local p killed=0
    for p in rofi wofi wlogout slurp grim swappy; do
        command -v "$p" >/dev/null 2>&1 || continue
        pkill -x "$p" 2>/dev/null && { d_ok "killed $p"; killed=1; }
    done
    # wf-recorder finalizes its file on SIGINT (same as the record toggle).
    if command -v wf-recorder >/dev/null 2>&1 && pgrep -x wf-recorder >/dev/null 2>&1; then
        pkill -INT -x wf-recorder 2>/dev/null
        d_ok "stopped wf-recorder"
        killed=1
    fi
    [ "$killed" -eq 0 ] && [ "${1:-}" != q ] && d_ok "No stuck screenshot overlays."
}

# ---- sound ----------------------------------------------------------------------
cmd_sound() {
    case "$1" in
        panel)
            command -v pavucontrol >/dev/null 2>&1 && setsid --fork pavucontrol >/dev/null 2>&1 &
            ;;
        up)
            pactl set-sink-volume @DEFAULT_SINK@ +5%
            cmd_osd "Volume" "$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -1)"
            ;;
        down)
            pactl set-sink-volume @DEFAULT_SINK@ -5%
            cmd_osd "Volume" "$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -1)"
            ;;
        mute)
            pactl set-sink-mute @DEFAULT_SINK@ toggle
            cmd_osd "Mute" "$(pactl get-sink-mute @DEFAULT_SINK@ | grep -o 'yes\|no')"
            ;;
    esac
}

# cmd_osd — lightweight notification popup used as an on-screen display
cmd_osd() {
    command -v notify-send >/dev/null 2>&1 && notify-send -a swayctl -h int:transient:1 -t 900 "$1" "$2" >/dev/null 2>&1
}

# ---- network ---------------------------------------------------------------------
cmd_wire() {
    case "$1" in
        panel)
            command -v nm-connection-editor >/dev/null 2>&1 \
                && setsid --fork nm-connection-editor >/dev/null 2>&1 &
            ;;
        status)
            nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev status 2>/dev/null \
                | grep -Ev 'loopback' || true
            ;;
    esac
}

# ---- toggles ----------------------------------------------------------------------
cmd_toggle() {
    case "$1" in
        night)
            if pgrep -x gammastep >/dev/null 2>&1; then
                pkill -x gammastep 2>/dev/null; notify "Night light" "off"
            else
                setsid --fork gammastep >/dev/null 2>&1 & notify "Night light" "on"
            fi
            ;;
        dnd)
            if command -v swaync-client >/dev/null 2>&1; then
                swaync-client -t >/dev/null 2>&1
                sleep 0.1
                d_ok "Do-not-disturb toggled"
            fi
            ;;
        touchpad)
            if is_under_sway; then
                swaymsg input type:touchpad events toggle >/dev/null 2>&1
                d_ok "Touchpad toggled"
            fi
            ;;
        layout)
            if is_under_sway; then
                swaymsg input type:keyboard xkb_switch_layout next >/dev/null 2>&1
            fi
            ;;
        *) printf '%s\n' "night" "dnd" "touchpad" "layout" | launcher_pick "Toggle" | while read -r t; do cmd_toggle "$t"; done ;;
    esac
}

# ---- status (bar backends) ---------------------------------------------------------
cmd_status() {
    case "$1" in
        media)
            command -v playerctl >/dev/null 2>&1 || return 0
            playerctl metadata --format '{"text": "{{ artist }} — {{ title }}", "class": "custom-media"}' 2>/dev/null || echo '{"text": ""}'
            ;;
        layout)
            [ -n "${SWAYSOCK:-}" ] || return 0
            local ids lays
            ids="$(swaymsg -t get_inputs 2>/dev/null | grep -oP '"identifier": "\K[^"]*' | head -1)"
            lays="$(swaymsg -t get_inputs 2>/dev/null | grep -oP '"active_layout_name": "\K[^"]*' | head -1)"
            printf '%s' "${lays:-}"
            ;;
        updates)
            if [ -f "/var/run/reboot-required" ]; then
                printf '{"text": " REBOOT ", "class": "reboot"}'
            elif command -v apt >/dev/null 2>&1; then
                local n
                n="$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst ') "
                printf '{"text": " %s "}' "${n:-0}"
            fi
            ;;
    esac
}

# ---- lock ---------------------------------------------------------------------------
cmd_lock() {
    command -v swaylock >/dev/null 2>&1 || { d_err "swaylock not installed."; return 1; }
    # Kill any overlay left open so nothing survives the unlock (mirrors the
    # shot-menu respawn fix — a rofi/wofi picker or swappy/slurp left behind can look
    # unkillable once swaylock owns the keyboard grab).
    cmd_kill q
    # Idempotent: timeout / lock / before-sleep events can all call us in one
    # suspend cycle; a second swaylock means having to unlock twice.
    if pgrep -x swaylock >/dev/null 2>&1; then
        return 0
    fi
    # ~/.config/swaylock/config is theme-rendered; fall back to plain flags.
    if [ -f "$CS_CONFIG/swaylock/config" ]; then
        swaylock
    else
        swaylock -f
    fi
    # After unlock, flush anything that surfaced while the screen was locked —
    # pickers/overlays left open around the lid cycle (plus pavucontrol from the
    # menu's "Sound panel") so a wake never re-opens onto stale windows.
    cmd_kill q
    command -v pavucontrol >/dev/null 2>&1 && pkill -x pavucontrol 2>/dev/null
}

# ---- system update ---------------------------------------------------------------------
cmd_update() {
    local mode="${1:-check}"
    case "$mode" in
        check)
            priv apt-get update >/dev/null 2>&1
            local apt_n flat_n
            apt_n="$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst ')"
            flat_n="$(command -v flatpak >/dev/null 2>&1 && flatpak update --appstream 2>/dev/null && flatpak list --updates 2>/dev/null | wc -l || true)"
            echo "apt: $apt_n upgradeable | flatpak: ${flat_n:-0} updates"
            [ "${apt_n:-0}" -gt 0 ] && notify "Updates available" "${apt_n} apt package(s), ${flat_n:-0} flatpak"
            ;;
        apply)
            priv apt-get upgrade -y >/dev/null 2>&1 &
            d_ok "apt upgrade started"
            command -v flatpak >/dev/null 2>&1 && flatpak update -y >/dev/null 2>&1 &
            d_ok "flatpak update started"
            ;;
    esac
}
