# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Everything below the fork entry documents the upstream (justaguy.dev)
project this was cut from, and the DebianSway rebuild that carried the engine
to its current shape. The fork keeps that history intact, but where an entry
conflicts with what this repo does today, **the fork wins** — the Nix-style
dotfiles staging and the old install-first layout do not exist here.

## [2026-09-26] — Pre-push audit: swaync schema, shellcheck, repo hygiene

- **swaync 0.11 schema violations fixed in the theme template.** The
  rendered config carried `control-center-exclusive-zone: 0` (schema wants a
  boolean) and `notification-visibility: "all"` (schema wants an object), so
  every swaync start logged two `Json-WARNING`s. Template now ships
  `exclusive-zone: true` and `notification-visibility: {}`; a headless
  smoke test reads the config warning-free.
- **Shellcheck hardening.** Fixed the flagged array-splice parse
  (`^${id}[[:space:]]` in 46-chat.sh) and the unquoted `$(theme_list)` word
  split in setup.sh (now `mapfile` + `"${_themes[@]}"`, same behavior).
  Added `.shellcheckrc` documenting the three *intentional* exclusions
  (sourced-lib vars, literal `~` in user-facing strings, shebang-less
  palette/tpl files).
- **Added `.gitignore`** (backup/merge + editor cruft) — the repo previously
  tracked nothing to exclude, matching the sway-setup/dwm-setup sibling
  convention of allow-by-default.

## [2026-09-26] — `$mod+Shift+l` conflict resolved (mango lock wins)

- **sway was logging "Overwriting binding 'Mod4+Shift+l' … from `move right`"**
  on every load/reload: the hjkl movement block already used
  `$mod+Shift+l` (`move right`, from `set $right l`) before the mango lock
  alias re-bound the same combo. sway's `bindsym` **replaces**, it doesn't
  stack — so the lock alias silently killed move-right and the log line
  became a standing error/footgun.
- **Resolution**: lock keeps `$mod+Shift+l` (dwm/mango muscle memory);
  the hjkl `move right` twin is dropped. Nothing is lost — the arrow twin
  `$mod+Shift+Right move right` already covers it, and all four hjkl
  **focus** binds are untouched. Verified headless (pixman): the only
  `Mod4+Shift+l` registration is `exec swayctl lock`, zero "Overwriting"
  lines.

## [2026-09-26] — Scratchpad drop-down hardening + script exec bits

- **`$mod+grave` drop-down no longer errors.** The old dual binding
  (`exec` + a criteria `[app_id="foot-scratch"] scratchpad show`) failed
  with sway's `No matching node.` (swaymsg exit 2) on every press before a
  scratch window existed. It's now a single binding to
  `scripts/scratch.sh`, which spawns `foot-scratch` once and then toggles
  it from the scratchpad — the `for_window` move rule stays.
- **`$mod+Shift+l` cleaned up**: trailing inline comment moved above the
  binding (parser was fine; the line reads clean now).
- **`scripts/batteryWarning.sh` / `scripts/tempWarning.sh` made executable.**
  Both were mode 644, so the `flock -n ... exec` lines in the config died
  with `flock: failed to execute ... Permission denied` at every session
  start. Now 755 in repo + live tree.

## [2026-09-26] — MangoWC/dwm muscle memory ported to sway keys

- **Core apps moved to dwm/mango slots** (per `~/.config/mango/config.conf`):
  `$mod+t` is now the terminal (foot) instead of thunar, `$mod+f` opens
  the file manager, `$mod+e` launches VSCodium, and `$mod+q` closes the
  focused window (mango `Super+q` killclient) next to the existing
  `$mod+Shift+q`.
- **New MangoWC compat block** — all on previously-free keys, using
  sway-native commands: `$mod+p` app launcher (`swayctl launcher`, rofi
  drun), `$mod+Shift+l` lock alias (dwm muscle memory; `$mod+x` stays),
  `$mod+grave` drop-down foot scratchpad (`foot-scratch`, launch-then-
  toggle), `$mod+Ctrl+b` bar toggle (`$mod+b` stays splith), firefox
  private window and the Ctrl-app launches (vesktop/heroic/gimp/obs),
  `$mod+comma`/`$mod+period` to focus outputs (Shift+ variants send the
  focused window instead), and `$mod+F10/11/12` volume aliases.
- **Floating parity**: mpv, eog, galculator, transmission-gtk and thunar
  progress/confirm dialogs now float and center like mangowc floats them.
- `$mod+grave` spawn-guards the drop-down: it only creates `foot-scratch`
  when no such window exists (`swaymsg get_tree` check), so holding the key
  can't stack terminals — the screenshot-respawn bug, again.
- Mango actions sway structurally lacks (incnmaster/setmfact,
  exchange_client, focusstack, overview, master-stack layouts, tag 11/12)
  are intentionally not bound; sway keeps its vim focus, its screenshot
  scheme and the `$mod+d` menu launcher.

## [2026-09-26] — Lock/wake: no stale pickers after unlocking the lid

- **`swayctl lock` is now idempotent and self-cleaning.** The timeout lock,
  the `lock` event and `before-sleep` can all fire in one suspend cycle — a
  bare `exec swaylock` stacked a second lock screen for each, so waking meant
  unlocking twice. `cmd_lock` now skips when a swaylock is already up, and
  after the screen unlocks it flushes whatever surfaced while locked
  (pickers/overlays via `cmd_kill q`, plus pavucontrol left behind by the
  menu's "Sound panel").
- **swayidle gained `lock` and `after-resume` handlers.** Any
  compositor/logind lock request now funnels through `swayctl lock` (overlay
  kill included), and `after-resume` runs `swayctl kill q` then
  `swaymsg reload` — clearing stuck pickers and resetting input state so the
  first keyboard taps after waking can't cascade `$mod+d` → menu →
  slurp → pavucontrol.

## [2026-09-26] — Launcher: rofi replaces wofi, swappable via SWAY_LAUNCHER

- **rofi is now the default picker** everywhere wofi used to be (launcher,
  run, menus, clipboard, screenshots, wallpaper, toggles, engineering, setup
  wizard). Every call path funnels through `launcher_bin`/`launcher_pick` /
  `launcher_apps` in `swayctl/lib/common.sh` — rofi when installed, wofi as
  the fallback. `SWAY_LAUNCHER=rofi|wofi` forces one; a bogus value warns
  and falls back.
- **Theme-engine templates**: `swayctl/themes/_base/tpl/rofi/` renders
  `~/.config/rofi/{config,theme}.rasi` per palette (same flat/2px look as
  the wofi CSS — BG/MANTLE/SURFACE0/SURFACE1/TEXT/ACCENT/PINK), so
  `swayctl theme set` themes both pickers. Validated against rofi 2.0
  (`rofi -dump-config`/`-dump-theme` parse clean).
- **rofi added to the 10-sway-core package list** (comes Wayland-native via
  the fork's apt repo; Debian `rofi` 1.7.5 is the fallback source), and to
  verify.sh's package + config checks (89 passed).
- `cmd_kill` / doctor's stray-overlay scan now cover `rofi` pickers too.
- User's existing `~/.config/rofi/{keybinds,power}.rasi` placeholders are
  left untouched.

## [2026-09-26] — Swaybar: drop text labels, swap memory glyph, kill min_width gaps

- **cpu/mem/disk blocks**: the "cpu:"/"mem:"/"disk:" text labels are gone —
  the blocks are now just the Nerd Font glyph plus the percent (e.g. ` 2%`).
- **Memory glyph**: FontAwesome 6 "memory" (the chip with "MEM" letters boxed
  in) rendered as a square with letters — swapped for the database cylinder
  (`/uf1c0`), verified present in JetBrainsMono Nerd Font's charset via
  fc-query.
- **Gaps between wifi/volume/brightness**: the whitespace came from `min_width`
  reserves in status.sh — the network block reserved an 18-character slot and
  volume/brightness reserved room for "100% (M)" / "100%", so shorter content
  got right-padded and created visible gaps. Removed `min_width` from every
  block; blocks now sit flush with the single-space separator (trade-off:
  the bar width breathes slightly as values change).

## [2026-09-26] — Swaybar: tighter spacing; swaync: compact center, time-based cleanup

- **Bar spacing**: `separator_symbol "  "` -> `" "` and `status_padding 3` -> `2`
  in `configs/sway/config` — uniform single-space gaps between status blocks,
  no more airy spread-out look. tray_padding stays 3.
- **Swaync was full-screen-tall by design**: `fit-to-screen: true` expands the
  control center to both screen edges, and `control-center-height` is *ignored*
  while it is set (swaync 0.11 schema). Now `fit-to-screen: false`, width
  420->360, height 600->400, notification icons 48->36, body images 200x100->
  160x80.
- **Pruned 15 keys swaync 0.11 silently ignores** (notification-preserve,
  relative-time-shortcuts, notification-grouping, transition-duration, ...) and
  switched to the schema-valid equivalents: `relative-timestamps: true` (shows
  "x minutes ago") and `transition-time: 200`.
- **Time-based expiry**: `timeout-critical` 0 -> 12000 so critical notifications
  also clear automatically; normal/low keep 4s. The center now self-cleans by
  time instead of holding everything until "Clear all".
- Both live `~/.config/swaync/` files re-rendered from the theme templates
  (installed tree re-synced first) and `~/.config/sway/config` redeployed.

## [2026-09-26] — Swaybar: glyph blocks, systray polish, click actions

- **status.sh** (`configs/swaybar/`) was rebuilt around the new bar design:
  every block now carries a Nerd Font glyph (clock, layout, wifi, volume,
  brightness, cpu, memory, disk, updates, battery, load) instead of bare
  `cpu:NN%`-style text; peri-block colors stay driven by the palette engine
  (`~/.config/swaybar/palette.env`).
- **Three new blocks**: brightness (`brightnessctl`, laptop-backlight %),
  root-filesystem disk usage (`df /`), and keyboard layout (via
  `swayctl status layout`, empty off-sway). Existing blocks were upgraded: the
  wifi block falls back to `nmcli` (NetworkManager is guaranteed; the `iw`
  package isn't) and tints yellow on weak signal (/proc/net/wireless < 30);
  battery picks a fill-level glyph, switches to a bolt while charging and a
  plug on AC; updates shows `[REBOOT]` in red.
- **Fixed two silent bugs while in there**: the cpu block never rendered —
  its sample counters lived in globals, but emit() calls it inside a command
  substitution (a subshell), so the delta was always "first sample"; state
  now lives in `$XDG_RUNTIME_DIR/swaybar-cpu.prev` with a 30s staleness
  guard. The brightness % never matched because `brightnessctl -m` lines end
  with `,255` — the sed was anchored to end-of-line.
- **Click actions**: swaybar feeds pointer events to the status command's
  stdin; a small background reader routes them to swayctl — left-click
  network → `swayctl wire panel`, volume → `swayctl sound mute` (right →
  sound panel), clock → `swayctl power`, battery → `swayctl lock`,
  updates → `swayctl update`. Actions are detached and quiet, so they no-op
  harmlessly off-sway.
- **Bar config** (`configs/sway/config`): bar-level `font
  pango:JetBrainsMono Nerd Font 9` (regular, not bold — crisper at 26px),
  `separator_symbol "  "` for breathing room, `status_padding`/`tray_padding
  3`, and a `separator` color so block gaps match the palette. No sway
  keys used beyond what sway-bar(5) documents (verified against 1.10.1).
- verify.sh untouched: existing guards (exec bit, palette.env) still cover
  both files.

## [2026-09-24] — Fix: unstoppable screenshot menu keeps respawning

- **Root cause**: `swayctl shot menu` (the wofi "Screenshot" picker) had no
  cancel guard — Escape returned an empty pick, which re-invoked `cmd_shot`
  into the `*` default case and respawned the picker in an instant,
  unkillable loop. The menu survived lock/unlock because the loop kept
  running behind swaylock. One-line fix: `[ -z "$act" ] && return 0`.
- **`swayctl kill` escape hatch**: new subcommand that deterministically
  kills any stuck overlay (`wofi`, `wlogout`, `slurp`, `grim`, `swappy`,
  and `wf-recorder` via SIGINT so recordings finalize). Wired to
  `bindsym --locked $mod+Ctrl+Escape exec swayctl kill` — works even right
  after an unlock, when a stray overlay is most likely to ignore input.
- **Lock-time cleanup**: `cmd_lock` now kills leftover overlays *before*
  `swaylock` runs, so nothing survives an unlock cycle.
- **`slurp` self-guard**: area/annotate selections cancel silently on
  Escape and auto-abort after 30s — no more bare `grim -g ""` noise.
- **doctor.sh** now reports stray screenshot overlays with a
  `swayctl kill` hint; verify.sh guards all of the above.
- **Removed**: the no-op "Bar (built-in swaybar)" entry from `swayctl
  menu`, plus stale `~/.config/sway` files nothing references
  (`keybindings.conf`, `scripts/{autostart.sh,screenshot,power,
  screen-off,changevolume,help,sway-layout-menu.sh,thememenu,status.sh}`)
  and leftover migration backups.

## [2026-09-24] — Bar fix: correct i3bar framing + wofi geometry

- **swaybar JSON stream now truly speaks i3bar**: header, one opening
  `[`, then `[{...}],` per update — the infinite array is never closed.
  The previous framing (a self-closed array per line) tripped swaybar's
  incremental parser (`expected ',' but encountered ']'`) which printed
  "invalid i3bar json". Verified against swaybar's actual parse loop with
  the system's libjson-c.
- **wofi template geometry fixed**: `width=44` was 44 **pixels** — wofi
  treats plain numbers as px, only `%` values are percent. Now `width=44%`.
  Dropped `lines=10` (height `60%` sizes the window instead): with
  `lines>0`, wofi 1.4.1 computes the scroll height before rows are
  measured and raises `Gtk-CRITICAL: gtk_widget_set_size_request:
  assertion 'height >= -1' failed` on every launch.

## [2026-09-24] — Bar hardening

- **Built-in swaybar speaks the JSON protocol** (`swaybar-protocol(7)`):
  `configs/swaybar/status.sh` emits a `{"version":1}` header and one JSON
  array of named blocks per update (`name`, `min_width`, per-block palette
  colors) — stable layout, no width jitter.
- **`status.sh` is now executable** (`100755`): sway runs `status_command`
  via `sh -c`, so a non-executable script made swaybar print
  "error reading from status command". verify.sh now guards the exec bit.
- **Palette-driven status colors**: new theme template
  `swayctl/themes/_base/tpl/swaybar/palette.env` renders per-block colors
  from the active palette (accent cpu/mem, red mute/low-battery/reboot,
  yellow updates) into `~/.config/swaybar/palette.env`.
- **Cheaper updates check**: `apt-get -s upgrade` throttled to one scan
  per 5 minutes (cached in `~/.cache/swaybar-upd`); the cheap
  `reboot-required` probe still runs every cycle.
- **wofi anchored to the bar**: template uses `location=bottom` (+30 px)
  so the launcher rises from just above the bottom bar. Previously
  `location=center` + `yoffset` silently forced `top_left` (wofi(7)).
- **verify.sh** gains guards: status.sh exec bit, wofi `location=bottom`,
  palette.env presence.

## [2026-09-24] — Fork: sway-setup (SOSMLG)

This is the fork: the DebianSway rebuild, rebranded and republished as
SOSMLG/sway-setup. The headline change is naming, not code — the Sway-focused
toolkit (foot/swaync/wofi + the 12-palette swayctl engine) carried
over intact, and now carries the repo name that matches the session it
installs (`sway-setup.desktop` / `sway-setup-session`).

### Changed (bar)

- **One bar, built-in.** The status bar is now sway's own swaybar — no
  separate `waybar` daemon, no waybar config/style.css, no toggle. `swayctl
  bar restart|reload|swaybar` re-applies it (the old `waybar` subcommand and
  the waybar choice in `swayctl setup` are gone). The built-in bar is themed
  by the same 12-palette engine via `colors.conf` tokens and gained a tray
  (`tray_output *`, e.g. Blueman) plus cpu/mem readings in
  `configs/swaybar/status.sh`.

### Changed

- **Rebrand: DebianSway → SwaySetup.** Repo moved to `~/sway-setup`
  (history preserved), all `DEBSWAY_*` env vars and `# DEBSWAY_DESC:` /
  `# DEBSWAY_DEFAULT:` step headers are now `SWAY_*` — the old names still
  parse for muscle-memory and external copies (one-line shim in
  `scripts/lib/common.sh`, header fallback in `run.sh`).
- **Session renamed.** The LightDM Greeter entry is now `sway-setup.desktop`
  (Name=SwaySetup, Exec/TryExec=`/usr/local/bin/sway-setup-session`), and the
  LightDM conf fragment moved from `60-debsway.conf` to `60-sway-setup.conf`
  with `user-session=sway-setup`. The `debsway → swayctl` CLI symlink alias is
  kept as a continuity alias; `run.sh --only` keeps the old step-name aliases
  working.
- **State paths renamed.** Runtime state moved from `~/.local/state/deb-sway`
  and `deb-sway-thinkpad` to `~/.local/state/sway-setup`; the APT component
  snippet helper now writes `sway-setup-<component>.sources` (legacy
  `debsway-*.sources` are still detected and backed up). The swayctl CLI's
  old-state migration (`debsway` → `swayctl`) is unchanged.
- **verify.sh moved to the repo root** (was `scripts/verifySetup.sh`);
  `run.sh --verify` and `install.sh` updated. Dropped the README's false
  claim of a `tests/`-based test suite — verification is the read-only
  `verify.sh` audit (which does exist and covers the greeter session,
  swayctl + 12-palette engine, packages, configs and services).
- **Docs added.** `QUICKSTART.md` (rewritten to match the actual keybindings),
  `AGENTS.md` (project conventions), `CONTRIBUTING.md`, `CHANGELOG.md`,
  `checklist.md`, `docs/troubleshooting.md`, plus the GPL-2 `LICENSE` from
  the upstream lineage.
- **Payload brand touch-ups.** `configs/environment.d/debsway.conf` renamed
  to `sway-setup.conf`; comments in `configs/sway/config`, `configs/waybar/`,
  `configs/mpv/`, `swayctl/bin/swayctl` and the wofi template now say
  SwaySetup.

### Fixed

- `verify.sh` now checks for `/usr/share/wayland-sessions/sway-setup.desktop`
  (was the old `debsway.desktop`), so the audit matches what the scripts
  actually install.

## [2026-09-23] — Rebuild: DebianSway (SOSMLG)

The single-project rebuild: the previous justaguy sway-setup fork became this
Sway-focused toolkit under the DebianSway name. Verified state: sway engine
live at ~/.config/sway with swayctl + 12-palette theme engine, sway session
selectable at LightDM.

## Upstream — justaguy.dev/sway-setup (pre-fork)

Everything below documents the upstream project this was cut from. The fork
keeps the history for reference; the runtime described there (Nix-style
dotfiles, `install.sh`-first layout) does not match this repo.