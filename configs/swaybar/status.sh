#!/usr/bin/env bash
# swaybar status script — built-in swaybar status provider.
#
# Speaks swaybar's JSON status-line protocol (swaybar-protocol(7)):
#   line 1: {"version":1}
#   then one JSON array per status update (an infinite stream).
# Blocks are named and carry per-block palette colors. Colors come from ~/.config/swaybar/palette.env, which
# the swayctl theme engine renders from the same 12-palette source as
# sway/colors.conf; neutral fallbacks apply when that file is missing.
#
# Pointer events: swaybar reports clicks on named blocks to the status
# command's stdin as one-line JSON — the reader at the bottom routes
# them to swayctl (network → wire menu, clock → power grid, volume →
# mute/panel, battery → lock, updates → check). Clicks are the cheap
# productivity layer; nothing that needs the session survives if the
# command is unavailable or not under sway.
#
# NOTE: sway executes status_command via `sh -c`, so this file MUST stay
# executable — otherwise swaybar prints "error reading from status command".
# verify.sh guards the exec bit.

# ---------------------------------------------------------------- palette
PALETTE="${XDG_CONFIG_HOME:-$HOME/.config}/swaybar/palette.env"
if [ -r "$PALETTE" ]; then
	# shellcheck disable=SC1090
	. "$PALETTE"
fi
: "${SWAYBAR_ACCENT:=88c0d0}" # hex, no '#'
: "${SWAYBAR_GREEN:=a3be8c}"
: "${SWAYBAR_RED:=bf616a}"
: "${SWAYBAR_YELLOW:=ebcb8b}"
: "${SWAYBAR_TEXT:=eceff4}"
: "${SWAYBAR_SUBTEXT:=d8dee9}"

# ---------------------------------------------------------------- icons
# Nerd Font glyphs (the bar font is JetBrainsMono Nerd Font). Written as
# \uXXXX escapes so the file stays ASCII-safe; bash expands them at
# runtime. Kept as a map so a glyph or two can be swapped without hunting
# through emit().
I_CLOCK="$(printf '\uf017')"   #  clock
I_LAYOUT="$(printf '\uf11c')"  #  keyboard (layout)
I_WIFI="$(printf '\uf1eb')"    #  wifi
I_VOL="$(printf '\uf028')"     #  volume-high (speaker)
I_MUTE="$(printf '\uf026')"    #  volume-mute (speaker-off)
I_BRIGHT="$(printf '\uf185')"  #  sun (brightness)
I_CPU="$(printf '\uf2db')"     #  microchip
I_MEM="$(printf '\uf1c0')"     #  database (memory usage)
I_DISK="$(printf '\uf0a0')"    #  hdd
I_UPD="$(printf '\uf021')"     #  refresh (updates)
I_BAT4="$(printf '\uf240')"    #  battery-full (~full)
I_BAT3="$(printf '\uf241')"    #  battery-three-quarters
I_BAT2="$(printf '\uf242')"    #  battery-half
I_BAT1="$(printf '\uf243')"    #  battery-quarter
I_BAT0="$(printf '\uf244')"    #  battery-empty
I_BOLT="$(printf '\uf0e7')"    #  bolt (charging)
I_PLUG="$(printf '\uf1e6')"    #  plug (AC)
I_LOAD="$(printf '\uf0e4')"    #  tachometer (load)

# ---------------------------------------------------------------- helpers
json_escape() { # stdin -> stdout: JSON string escaping (\ " tab newline)
	sed -e 's/\\/\\\\/g' -e 's/\t/\\t/g' -e 's/\n/\\n/g' -e 's/"/\\"/g'
}

block() { # block <text> <name> <color> <min_width>; empty text -> skipped
	local t="$1" n="$2" c="$3" m="$4"
	[ -n "$t" ] || return 0
	printf '{"full_text":"%s"' "$(printf '%s' "$t" | json_escape)"
	[ -n "$n" ] && printf ',"name":"%s"' "$(printf '%s' "$n" | json_escape)"
	[ -n "$c" ] && printf ',"color":"#%s"' "$c"
	[ -n "$m" ] && printf ',"min_width":"%s"' "$(printf '%s' "$m" | json_escape)"
	printf '}'
}

# ---------------------------------------------------------------- backends
clock_now() { printf '%s %s' "$I_CLOCK" "$(date '+%a %d %b %H:%M')"; }

vol_now() { # "<glyph> NN%" / "... (M)" when muted; empty if pactl unavailable
	command -v pactl >/dev/null 2>&1 || return 0
	local v m
	v="$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\d+%' | head -1)"
	[ -n "$v" ] || return 0
	m="$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -oP '(?<=Mute: ).*')"
	if [ "$m" = yes ]; then
		printf '%s %s (M)' "$I_MUTE" "$v"
	else
		printf '%s %s' "$I_VOL" "$v"
	fi
}

bat_now() { # "<glyph> NN%C" / "<glyph> NN%C" charging / " AC"; empty if BAT0 missing
	[ -d /sys/class/power_supply/BAT0 ] || {
		printf '%s AC' "$I_PLUG"
		return 0
	}
	local cap st
	cap="$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)"
	st="$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)"
	[ -n "$cap" ] || {
		printf '%s AC' "$I_PLUG"
		return 0
	}
	local bic
	case "$cap" in
	100 | 9?) bic="$I_BAT4" ;;
	8? | 7?) bic="$I_BAT3" ;;
	6? | 5?) bic="$I_BAT2" ;;
	4? | 3?) bic="$I_BAT1" ;;
	*) bic="$I_BAT0" ;;
	esac
	[ "$st" = Charging ] && bic="$I_BOLT"
	printf '%s %s%%%s' "$bic" "$cap" "${st:0:1}"
}

cap_now() { # battery percent as a number (empty on AC)
	cat /sys/class/power_supply/BAT0/capacity 2>/dev/null
}

net_now() { # "<glyph> SSID", "<glyph> offline", or empty
	local s
	# nmcli beats iwgetid here: it ships with NetworkManager (swayctl wire
	# uses it anyway) while the `iw` package isn't guaranteed. iwgetid is
	# kept as a fallback for bare wpa_supplicant setups.
	if command -v nmcli >/dev/null 2>&1; then
		s="$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')"
	fi
	if [ -z "$s" ] && command -v iwgetid >/dev/null 2>&1; then
		s="$(iwgetid -r 2>/dev/null)"
	fi
	# Weak signal shows up as a tinted block (see emit); the quality is read
	# there in one cheap awk so it stays out of the block text.
	if [ -n "$s" ]; then
		printf '%s %s' "$I_WIFI" "$s"
	else
		printf '%s offline' "$I_WIFI"
	fi
}

CPU_STATE="${XDG_RUNTIME_DIR:-/tmp}/swaybar-cpu.prev"

cpu_now() { # "<glyph> NN%" from a delta between samples; empty until the 2nd
	# Sample state lives in a file, not globals: emit() calls cpu_now in a
	# command substitution (a subshell), so exported globals would be lost
	# between samples and the block would stay empty forever.
	local idle total ts p_idle p_total p_ts
	idle="$(awk '/^cpu /{print $5+$6}' /proc/stat 2>/dev/null)"
	total="$(awk '/^cpu /{for(i=2;i<=NF;i++)t+=$i; print t}' /proc/stat 2>/dev/null)"
	ts="$(date +%s)"
	p_idle='' p_total='' p_ts=0
	[ -r "$CPU_STATE" ] && read -r p_idle p_total p_ts <"$CPU_STATE"
	# stale state (bar restarted) yields one bogus sample — skip it
	if [ -n "$p_idle" ] && [ -n "$p_total" ] && [ "$p_ts" -gt $((ts - 30)) ]; then
		local d_idle d_total
		d_idle=$((idle - p_idle))
		d_total=$((total - p_total))
		if [ "$d_total" -gt 0 ]; then
			printf '%s %s%%' "$I_CPU" "$((100 - d_idle * 100 / d_total))"
		fi
	fi
	printf '%s %s %s\n' "$idle" "$total" "$ts" >"$CPU_STATE" 2>/dev/null
}

mem_now() { # "<glyph> NN%"
	local t a
	t="$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null)"
	a="$(awk '/^MemAvailable:/{print $2}' /proc/meminfo 2>/dev/null)"
	[ -n "$t" ] && [ "$t" -gt 0 ] && [ -n "$a" ] || return 0
	printf '%s %s%%' "$I_MEM" "$(((t - a) * 100 / t))"
}

disk_now() { # "<glyph> NN%" for /
	local p
	p="$(df -P / 2>/dev/null | awk 'NR==2{ gsub(/%/,"",$5); print $5 }')"
	[ -n "$p" ] || return 0
	printf '%s %s%%' "$I_DISK" "$p"
}

brightness_now() { # "<glyph> NN%"; empty when no backlight
	local p
	p="$(brightnessctl -m 2>/dev/null | sed -n '1s/.*,\([0-9][0-9]*%\).*/\1/p')"
	[ -n "$p" ] || return 0
	printf '%s %s' "$I_BRIGHT" "$p"
}

layout_now() { # "<glyph> <layout>" / "" when not under sway
	local l
	command -v swayctl >/dev/null 2>&1 || return 0
	l="$(swayctl status layout 2>/dev/null)"
	[ -n "$l" ] && printf '%s %s' "$I_LAYOUT" "$l"
}

UPD_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/swaybar-upd"
UPD_MAX_AGE=300

upd_now() { # "[upd:N]" / "[REBOOT]" / empty; apt simulated scan <= 1/5min
	if [ -f /var/run/reboot-required ]; then
		printf '%s [REBOOT]' "$I_UPD"
		return 0
	fi
	local now last n
	now="$(date +%s)"
	last=0
	n=""
	if [ -f "$UPD_CACHE" ]; then
		last="$(stat -c %Y "$UPD_CACHE" 2>/dev/null || echo 0)"
		n="$(cat "$UPD_CACHE" 2>/dev/null)"
	fi
	if [ -z "$n" ] || [ $((now - last)) -ge "$UPD_MAX_AGE" ]; then
		if command -v apt-get >/dev/null 2>&1; then
			n="$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst ')"
		else
			n=0
		fi
		mkdir -p "$(dirname "$UPD_CACHE")"
		printf '%s' "$n" >"$UPD_CACHE" 2>/dev/null
	fi
	[ "${n:-0}" -gt 0 ] && printf '%s [upd:%s]' "$I_UPD" "$n"
}

load_now() { printf '%s load:%s' "$I_LOAD" "$(cut -d' ' -f1 /proc/loadavg 2>/dev/null)"; }

# ---------------------------------------------------------------- emit
emit() {
	local clock layout net vol bright cpu mem disk upd bat cap load st q
	local c_clock c_layout c_net c_vol c_bright c_cpu c_mem c_disk c_upd c_bat c_load
	clock="$(clock_now)"
	layout="$(layout_now)"
	net="$(net_now)"
	vol="$(vol_now)"
	bright="$(brightness_now)"
	cpu="$(cpu_now)"
	mem="$(mem_now)"
	disk="$(disk_now)"
	upd="$(upd_now)"
	bat="$(bat_now)"
	cap="$(cap_now)"
	load="$(load_now)"

	c_clock="$SWAYBAR_SUBTEXT"
	c_layout="$SWAYBAR_ACCENT"
	c_net="$SWAYBAR_TEXT"
	q="$(awk 'NR==3{print int($4)+0}' /proc/net/wireless 2>/dev/null)"
	[ -n "$q" ] && [ "$q" -gt 0 ] && [ "$q" -lt 30 ] && c_net="$SWAYBAR_YELLOW"
	[[ "$net" == *offline* ]] && c_net="$SWAYBAR_SUBTEXT"
	c_vol="$SWAYBAR_ACCENT"
	[[ "$vol" == *"(M)"* ]] && c_vol="$SWAYBAR_RED"
	c_bright="$SWAYBAR_YELLOW"
	c_cpu="$SWAYBAR_ACCENT"
	c_mem="$SWAYBAR_ACCENT"
	c_disk="$SWAYBAR_TEXT"
	c_upd="$SWAYBAR_YELLOW"
	[[ "$upd" == "[REBOOT]" ]] && c_upd="$SWAYBAR_RED"
	c_bat="$SWAYBAR_TEXT"
	if [ -n "$cap" ]; then
		if [ "$cap" -le 20 ]; then
			c_bat="$SWAYBAR_RED"
		elif [ -d /sys/class/power_supply/BAT0 ]; then
			st="$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)"
			[ "$st" = Charging ] && c_bat="$SWAYBAR_GREEN"
		fi
	fi
	c_load="$SWAYBAR_SUBTEXT"

	local arr=() b
	b="$(block "$clock" clock "$c_clock")"
	[ -n "$b" ] && arr+=("$b")
	b="$(block "$layout" layout "$c_layout")"
	[ -n "$b" ] && arr+=("$b")
	b="$(block "$net" network "$c_net")"
	[ -n "$b" ] && arr+=("$b")
	b="$(block "$vol" volume "$c_vol")"
	[ -n "$b" ] && arr+=("$b")
	b="$(block "$bright" brightness "$c_bright")"
	[ -n "$b" ] && arr+=("$b")
	b="$(block "$cpu" cpu "$c_cpu")"
	[ -n "$b" ] && arr+=("$b")
	b="$(block "$mem" memory "$c_mem")"
	[ -n "$b" ] && arr+=("$b")
	b="$(block "$disk" disk "$c_disk")"
	[ -n "$b" ] && arr+=("$b")
	b="$(block "$upd" updates "$c_upd")"
	[ -n "$b" ] && arr+=("$b")
	b="$(block "$bat" battery "$c_bat")"
	[ -n "$b" ] && arr+=("$b")
	b="$(block "$load" load "$c_load")"
	[ -n "$b" ] && arr+=("$b")

	local joined=""
	local i
	for i in "${arr[@]}"; do
		[ -n "$joined" ] && joined="$joined,"
		joined="$joined$i"
	done
	# An element must never be empty: swaybar expects a value after the
	# opening '[' (or the previous comma), not another comma.
	[ -z "$joined" ] && joined='{"full_text":""}'
	printf '[%s],\n' "$joined"
}

# ---------------------------------------------------------------- clicks
# swaybar click events (swaybar-protocol(7)) arrive one per line on stdin:
#   {"name":"volume","button":3,"x":0,"y":0,"modifiers":[]}
# Run actions detached and quiet; they fail gracefully off-sway.
run_click() { # run_click <cmd...>
	command -v "$1" >/dev/null 2>&1 || return 0
	"$@" >/dev/null 2>&1 &
}

click_handle() { # click_handle <event-json>
	local ev="$1" name btn
	name="$(printf '%s' "$ev" | jq -r '.name // empty' 2>/dev/null)"
	[ -n "$name" ] || return 0
	btn="$(printf '%s' "$ev" | jq -r '.button // 0' 2>/dev/null)"
	case "$name" in
	network) [ "$btn" = 1 ] && run_click swayctl wire panel ;;
	volume) case "$btn" in 1) run_click swayctl sound mute ;;
	3) run_click swayctl sound panel ;; esac ;;
	clock) [ "$btn" = 1 ] && run_click swayctl power ;;
	battery) [ "$btn" = 1 ] && run_click swayctl lock ;;
	updates) [ "$btn" = 1 ] && run_click swayctl update ;;
	esac
}

# ---------------------------------------------------------------- main
# swaybar's i3bar protocol is an INFINITE array: the header, one opening
# '[', then one element per update, each followed by a comma. The array is
# NEVER closed (that is what swaybar's parser expects; emitting a closed
# array per line makes it print "invalid i3bar json"). Match i3status:
#   {"version":1}\n
#   [\n
#   [{...}],\n
#   [{...}],\n
printf '{"version":1}\n'
printf '[\n'
(while IFS= read -r ev; do [ -n "$ev" ] && click_handle "$ev"; done) &
while true; do
	emit
	sleep "${SWAYBAR_INTERVAL:-10}"
done
