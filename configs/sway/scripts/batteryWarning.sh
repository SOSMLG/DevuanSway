#!/usr/bin/env bash
# batteryWarning.sh — Battery monitor (upower-based, battery auto-discovered).
# Notifies once per discharge cycle at 30% (low) and 20% (critical); the
# markers reset when charging or back above 35%, so a day at 19% means two
# notifications, not 288. All external tools are guarded — missing upower
# (desktop) or notify-send exits quietly instead of spamming stderr.
# Singleton via flock in the sway autostart line (see configs/sway/config).

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/swayctl"
LOW_MARK="$STATE_DIR/battery-low.notified"
CRIT_MARK="$STATE_DIR/battery-crit.notified"

command -v upower >/dev/null 2>&1 || exit 0
command -v notify-send >/dev/null 2>&1 || exit 0
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

BATDEV="$(upower -e 2>/dev/null | grep -i battery | head -1)"
[ -n "$BATDEV" ] || exit 0

check_battery() {
    local info batt state
    info="$(upower -i "$BATDEV" 2>/dev/null)" || return 0
    batt="$(printf '%s' "$info" | awk '/percentage/ {print $2}' | tr -d '%')"
    state="$(printf '%s' "$info" | awk '/state/ {print $2}')"
    [[ "$batt" =~ ^[0-9]+$ ]] || return 0

    # Charging (or full): clear the cycle markers, stay silent.
    if [ "$state" != "discharging" ]; then
        rm -f "$LOW_MARK" "$CRIT_MARK"
        return 0
    fi
    # Recovered above the band: clear too (cable was briefly unplugged).
    if [ "$batt" -gt 35 ]; then
        rm -f "$LOW_MARK" "$CRIT_MARK"
        return 0
    fi

    if [ "$batt" -le 20 ] && [ ! -f "$CRIT_MARK" ]; then
        notify-send -u critical "Need Juice" "Battery is at ${batt}%"
        : > "$CRIT_MARK"
    elif [ "$batt" -le 30 ] && [ ! -f "$LOW_MARK" ]; then
        notify-send -u low "Low Battery" "Battery is at ${batt}%"
        : > "$LOW_MARK"
    fi
}

while true; do
    check_battery
    sleep 300
done
