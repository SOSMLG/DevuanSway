#!/usr/bin/env bash
# tempWarning.sh — CPU temperature monitor (Ryzen k10temp `Tctl` first,
# Intel `Package id 0` fallback). Notifies once per heat event at 80°C+ and
# stays silent until the CPU cools 5° below threshold (hysteresis), so a
# long compile means one notification, not one every 40 seconds.
# Singleton via flock in the sway autostart line (see configs/sway/config).

THRESHOLD=80
HYSTERESIS=5
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/swayctl"
HOT_MARK="$STATE_DIR/temp-hot.notified"

command -v sensors >/dev/null 2>&1 || exit 0
command -v notify-send >/dev/null 2>&1 || exit 0
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

check_temp() {
    local temp raw
    raw="$(sensors 2>/dev/null | grep -m 1 -E 'Tctl:|Package id 0' \
        | grep -oE '[+-]?[0-9]+(\.[0-9]+)?°?C' | head -1 | tr -d '+°C')"
    temp="${raw%%.*}"
    [[ "$temp" =~ ^[0-9]+$ ]] || return 0

    if [ "$temp" -ge "$THRESHOLD" ] && [ ! -f "$HOT_MARK" ]; then
        notify-send -u critical "High Temperature" "CPU Temp is ${raw}°C"
        : > "$HOT_MARK"
    elif [ "$temp" -lt $((THRESHOLD - HYSTERESIS)) ]; then
        rm -f "$HOT_MARK"
    fi
}

while true; do
    check_temp
    sleep 40
done
