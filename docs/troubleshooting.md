# Troubleshooting

## Session starts, no bar / no notifications (missing D-Bus bus)

Sway itself runs without a session bus, but swaync and the xdg
portals need one. If you launched plain `sway` (the package's
`/usr/share/wayland-sessions/sway.desktop`) instead of `SwaySetup`, the
wrapper `dbus-run-session -- sway` never ran.

- Confirm: `echo $XDG_SESSION_TYPE` should be `wayland`, and
  `pgrep -x dbus-run-session` should list a bus for this session.
- Fix: log out, pick `SwaySetup` in the greeter. If it's missing,
  `scripts/10-sway-core.sh` installs `/usr/local/bin/sway-setup-session`
  and `/usr/share/wayland-sessions/sway-setup.desktop`; re-run it (needs
  `doas`).

## Notifications don't appear

`swaync` is exec'd from `~/.config/sway/config`. If nothing pops:

- `pgrep -x swaync` — if dead, `swaync &` once to see its stderr.
- Config path: swaync runs with `-c ~/.config/sway/swaync/config.json -s
  ~/.config/sway/swaync/style.css`; missing files mean the theme engine
  hasn't rendered yet (`swayctl theme set catppuccin-mocha`).

## Theme doesn't re-render

- `swayctl theme set <name>` renders `swayctl/themes/_base/tpl/` templates
  into `~/.config`. If a file is untouched, look for the `SWAYCTL_KEEP`
  marker inside it — KEEP'd files are never overwritten on purpose. Remove
  the marker (or the file) to let the engine take it back.
- Palettes live in `swayctl/themes/<name>/palette.sh` (hex WITHOUT `#`).
  A typo'd token renders empty CSS, not an error — re-run with `set -x` on
  `swayctl/lib/theme.sh:render_palette()` if a color is missing.

## Portals (file pickers, screen share) fail

`xdg-desktop-portal-wlr` is installed by step 10 and talks to the session
bus. If `xdg-open` or a screen-share dialog hangs:

- `pgrep -af portal` — if dead or hung, kill the portal processes and reload
  (`Super + Shift + c`); swaync respawns its bus connection on its own,
  and the portal picks the session bus back up on next spawn.
- Flatpak apps additionally need `xdg-desktop-portal-gtk` (step 10 installs
  it) — file chooser dialogs coming from the GTK portal are expected.

## NVIDIA: black screen / flicker

Sway on NVIDIA needs the proprietary driver with GBM support and
`nvidia_drm.modeset=1` on the kernel command line. Without it the session
starts on the fbdev backend — no hardware cursors, no atomic modesetting.

- Confirm: `cat /proc/cmdline` contains `nvidia_drm.modeset=1`. Add it via
  the boot loader (`GRUB_CMDLINE_LINUX`) if not, then update-grub.
- Cursor invisible: `WLR_NO_HARDWARE_CURSORS=1` in
  `~/.config/environment.d/sway-setup.conf` is the escape hatch.

## Wayland app scaling looks wrong

Fractional scaling on Wayland is compositor-side and application-side.
`sway` configures scale per output; GTK/Qt apps honour it through the
portals, XWayland apps (`X11_SCALE_FACTOR`) do not. For the ThinkPad panel
(1.0 scale) this is a non-issue; external HiDPI monitors may need
`output <name> scale 2`.

## LightDM session list looks wrong

Exactly one DM must own the console. `60-sway-setup.conf` (step 10) sets
`user-session=sway-setup`; if another conf under
`/etc/lightdm/lightdm.conf.d/` sets a different `user-session`, the lexicographically
last one wins. Check with `grep -r user-session /etc/lightdm/`.

## Stuck in resize mode

`Super + Alt + r` enters it; `Return` or `Escape` leaves. If the config
errored mid-edit and the mode never bound `Escape`, `swaymsg mode default`
from a terminal gets you out.

## Old state paths after rebrand

The rebrand moved runtime state to `~/.local/state/sway-setup` (from
`deb-sway`/`deb-sway-thinkpad`/`debsway`), and `21-swayctl-cli.sh` migrates
the old `debsway` state dir on first run. Leftovers under
`~/.local/state/debsway` and `~/.local/share/debsway` are safe to remove
after a successful `swayctl status`.