# QUICKSTART — sway-setup (catppuccin-mocha)

You just installed the base system and logged into a SwaySetup session. Here's
the short version of how to live here.

## First things first

- **`Super + /` is the whole manual.** It opens a searchable wofi list of
  every keybind, generated from the live config (`swayctl keys`). When you're
  lost, press it.
- `Super + Return` opens a terminal — **foot**, the default.
- `Super + d` is the launcher (`swayctl menu` — apps, power, screenshots,
  themes, engineering tools all live here). Start there.
- `Print` takes a full screenshot, `Super + Print` a selection — both land in
  `~/Pictures/screenshots` and hit the clipboard. `Super + v` opens the
  clipboard history.
- `Super + Shift + q` closes whatever's focused (there is no plain
  `Super + q` binding).

## Everyday tasks

**Change the theme.** `swayctl theme set nord` (or pick from `swayctl menu`,
or `swayctl theme list`) re-renders sway/swaybar, foot, swaync, wofi,
wlogout and swaylock from the 12 bundled palettes and soft-reloads the
session — no logout. Defaults stick across logins.

**Wallpaper.** `swayctl bg cycle` steps the bundled set; `swayctl bg list`
shows them. Drop your own images into `~/.config/sway/wallpapers/` and they
join the list.

**Volume & brightness.** Hardware keys (XF86*) only — mute pops a swaync OSD,
media keys drive playerctl. `pavucontrol` is in the menu for the rest.
Brightness keys use `brightnessctl`.

**Notifications.** swaync runs at session start; notifications scroll in
bottom-right. There's no toggle keybind — `swayctl` doesn't manage the daemon,
`pkill -x swaync` isn't the way either; if a popup is in the way, click it.

**Clipboard.** `swayctl clip watch` runs at session start (cliphist). `Super +
v` opens the picker; `y` pastes the highlighted entry.

**Power.** `Super + Escape` (or `Super + Ctrl + p`) opens the power menu.
`Super + x` locks with swaylock (swayidle auto-locks on idle, auto-suspends on
lid close). `Super + Shift + e` exits to the greeter.

**Resize a window.** `Super + Alt + r` enters resize mode (arrows or
`h/j/k/l`, `Return`/`Escape` to leave).

**Add the app phases.** The base install is deliberately lean. When you want
the rest:

```bash
cd sway-setup
./run.sh --list                 # see what exists
./run.sh --phase core,apps      # pick by phase
./run.sh --full                 # everything, unattended
```

Reboot when it finishes — the first steps add you to the input/video/render/
plugdev groups, and that only matters on the next login.

## Where things live

- Config root: `~/.config/sway/` — `config`, `colors.conf`, `scripts/`
  (battery/temp warnings, OSD, clip watch), `wallpapers/`
- Themed configs: `~/.config/foot/`, `~/.config/swaybar/` (built-in bar status),
  `~/.config/swaync/`, `~/.config/wofi/`, `~/.config/swaylock/`,
  `~/.config/wlogout/`
- Theme palettes: `~/.local/share/swayctl/themes/` — re-rendered on every
  `swayctl theme set`
- Setup steps: `scripts/` in the repo, run via `./run.sh`
- Run and verify logs: `~/.local/state/sway-setup/`

## Docs

- `README.md` — full step table, swayctl reference, conventions
- `docs/troubleshooting.md` — known gotchas (Wayland quirks, NVIDIA, portals)
- `checklist.md` — end-to-end smoke test for a fresh install
- `CHANGELOG.md` — what changed since the DebianSway rebuild