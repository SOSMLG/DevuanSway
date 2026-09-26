#!/usr/bin/env bash
# =======================================================
# swayctl/lib/theme.sh — the Theme Engine
# -------------------------------------------------------
# One palette per theme (themes/<name>/palette.sh), rendered
# into every themed app via templates under themes/_base/tpl/
# with @@TOKEN@@ placeholders (hex WITHOUT '#'; templates add
# the '#' or alpha where their consumer wants CSS hex).
# `swayctl theme set <name>` renders -> ~/.config -> soft reload.
# =======================================================
[ -n "${_SWAYCTL_LIB_THEME_LOADED:-}" ] && return 0
_SWAYCTL_LIB_THEME_LOADED=1

# render_palette <theme-name> [dst-root]
render_palette() {
    local name="$1" dst="${2:-$CS_CONFIG}"
    load_palette "$(theme_dir "$name")" || return 1

    local tpl rel out
    local sedexpr=()
    local tok var
    for tok in BG MANTLE CRUST SURFACE0 SURFACE1 SURFACE2 OVERLAY \
               TEXT SUBTEXT0 SUBTEXT1 ACCENT \
               RED GREEN YELLOW BLUE PURPLE PINK TEAL ORANGE \
               T0 T1 T2 T3 T4 T5 T6 T7 TB0 TB1 TB2 TB3 TB4 TB5 TB6 TB7; do
        var="C_$tok"
        sedexpr+=(-e "s|@@${tok}@@|${!var:-}|g")
    done

    while IFS= read -r -d '' tpl; do
        [ -f "$tpl" ] || continue
        rel="${tpl#"$CS_TPL"/}"
        out="$dst/$rel"
        if [ -f "$out" ] && grep -q 'SWAYCTL_KEEP\|SWAY_KEEP' "$out" 2>/dev/null; then
            d_warn "Kept custom $out (KEEP marker) — not re-rendered."
            continue
        fi
        mkdir -p "$(dirname "$out")"
        sed "${sedexpr[@]}" "$tpl" > "$out"
    done < <(find "$CS_TPL" -type f -print0)
    return 0
}

# theme_list — installed theme names, one per line
theme_list() {
    local t
    for t in "$CS_THEMES"/*/; do
        [ -d "$t" ] || continue
        [ -f "$t/palette.sh" ] || continue
        basename "$t"
    done
}

# theme_apply <name> [dst] — render + persist marker
theme_apply() {
    local name="$1" dst="${2:-$CS_CONFIG}"
    local dir
    dir="$(theme_dir "$name")"
    [ -d "$dir" ] || { d_err "Unknown theme: $name"; return 1; }
    render_palette "$name" "$dst" || return 1
    set_marker theme "$name"
}

# theme_set <name> [dst] — render + persist + refresh session
theme_set() {
    theme_apply "$1" "${2:-$CS_CONFIG}" || return 1
    gtk_dark
    d_ok "Theme applied: $(current_theme)"
    theme_reload
}

# theme_reload — soft-reload live session (best-effort)
theme_reload() {
    if is_under_sway; then
        swaymsg reload >/dev/null 2>&1 || true
        pkill -x swaync 2>/dev/null
        sleep 0.2
        command -v swaync >/dev/null 2>&1 && setsid --fork swaync >/dev/null 2>&1 &
        local bg_marker
        bg_marker="$(get_marker bg)"
        if [ -n "$bg_marker" ] && [ -f "$bg_marker" ]; then
            swaymsg "output * bg \"$bg_marker\" fill" >/dev/null 2>&1 || true
        fi
    fi
}

# gtk_dark — nudge GTK apps toward dark
gtk_dark() {
    command -v gsettings >/dev/null 2>&1 || return 0
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark >/dev/null 2>&1 || true
}
