#!/usr/bin/env bash
# =======================================================
# swayctl/lib/setup.sh — first-run customization wizard
# -------------------------------------------------------
# Quick interactive setup: pick a theme + wallpaper, choose
# the bar, set workspace behavior, then apply. Everything it
# does is also available as individual swayctl commands.
# =======================================================
[ -n "${_SWAYCTL_LIB_SETUP_LOADED:-}" ] && return 0
_SWAYCTL_LIB_SETUP_LOADED=1

ask_pick() {
	local prompt="$1"
	shift
	printf '%s\n' "$@" | launcher_pick "$prompt"
}

cmd_setup() {
	d_log "swayctl setup — first-run wizard"
	echo

	local theme_name
	theme_name="$(current_theme)"
	d_log "Current theme: $theme_name"

	if launcher_bin >/dev/null 2>&1; then
		mapfile -t _themes < <(theme_list)
		theme_name="$(ask_pick "Choose a theme" "${_themes[@]}")"
	else
		read -rp "Theme [$(theme_list | tr '\n' ' ')]: " theme_name
	fi
	[ -n "$theme_name" ] && theme_set "$theme_name"

	cmd_bg panel

	echo
	d_ok "Setup complete. Run 'swayctl doctor' for a health check."
}
