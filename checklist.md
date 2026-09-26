# Smoke-Test Checklist

End-to-end pass for sway-setup, run on a fresh Devuan 6 (or Debian 13) box.
Tick `[x]` as you go; any `[ ]` left at the end needs investigation before a
release. This is "does the daily driver actually drive", so most of it is
manual.

## Step 0 — sync the test machine

```bash
cd <repo-clone>
git checkout main && git pull
./run.sh --list                 # confirm steps render
./run.sh --phase core,desktop   # minimal base first
# log out, log back in, pick "SwaySetup" at LightDM
```

## Phase 1 — Boot sanity

- [ ] LightDM greeter shows a `SwaySetup` session and login works
- [ ] `sway-setup.desktop` present in `/usr/share/wayland-sessions/`, no stale
      `debsway.desktop` (or both if keeping the old entry)
- [ ] `/etc/lightdm/lightdm.conf.d/60-sway-setup.conf` sets
      `user-session=sway-setup`
- [ ] built-in swaybar shows clock, battery, network, volume, cpu, mem
- [ ] `pgrep -x swaync foot` — notifier + terminal alive, no
      duplicates after a `Super + Shift + c` (reload)
- [ ] `swaymsg -t get_version` answers on the session bus (D-Bus wrapper ran)

## Phase 2 — Core bindings

- [ ] `Super + Return` → foot opens
- [ ] `Super + d` → swayctl menu (apps, power, screenshots, themes, eng)
- [ ] `Print` → full screenshot lands in `~/Pictures/screenshots` + clipboard
- [ ] `Super + Print` → area selection works the same way
- [ ] `Super + Shift + q` closes the focused window
- [ ] `Super + 1..0` switch workspaces; `Super + Shift + 1..0` move containers
- [ ] `Super + Alt + r` → resize mode (arrows/hjkl, Enter/Esc exits)
- [ ] `Super + Shift + c` reloads config without dropping the bar
- [ ] `Super + Escape` opens the power menu; `Super + x` locks with swaylock
- [ ] `Super + Shift + e` → swaynag confirm → exits to greeter (this is the
      one that proves the session wrapper isn't leaking the D-Bus bus)

## Phase 3 — Theme engine

- [ ] `swayctl theme list` shows 12 palettes (catppuccin-mocha, doomone,
      dracula, everforest, github_dark, gruvbox, kanagawa, monokai, moonfly,
      nord, retro, rose-pine)
- [ ] `swayctl theme set nord` re-renders foot/swaync/wofi/wlogout/
      swaylock/swaybar — open foot (`Super + Return`) and confirm the palette moved
- [ ] Files with a `SWAYCTL_KEEP` marker are untouched (edit one under
      `~/.config/swaync/`, set a KEEP comment, re-render, confirm it survives)
- [ ] `swayctl theme set catppuccin-mocha` restores the default
- [ ] `swayctl bg cycle` steps the bundled wallpapers; `swayctl bg list` works

## Phase 4 — swayctl CLI surface

```bash
swayctl status media|layout|updates
swayctl doctor                 # read-only health check
swayctl update [--apply]       # apt + flatpak
swayctl keys                   # keybinding cheat-sheet from the config
```

- [ ] `debsway doctor` resolves to `swayctl` (alias symlink intact)
- [ ] `swayctl clip watch` runs; `Super + v` picks an entry and pastes it
- [ ] `swayctl sound up|down|mute` pops a swaync OSD popup
- [ ] `swayctl eng octave|jupyter|scilab|qucs|kicad|matlab` launchers work

## Phase 5 — Steps + verification

```bash
./run.sh --full
./run.sh --verify        # or: bash verify.sh
```

- [ ] `--full` finishes with no failed steps; `~/.local/state/sway-setup/last-run.log`
      shows `result  ok`
- [ ] `verify.sh`: 0 FAIL (warnings allowed for optional apps you skipped)
- [ ] Groups: `id -nG` includes input, video, render, plugdev after a reboot
- [ ] Spot-check a step: `octave --version`,
      `python3 -c "import control"` inside `~/.local/venv/eng`,
      `codium --version`, `opencode --version` (if you ran those phases)
- [ ] A second run of `./run.sh --full` is a no-op apart from re-checks
      (idempotence)

## When something fails

1. Note the phase and what happened before touching anything.
2. Bindings dead in Phase 2? Check `~/.config/sway/config` for syntax errors
   (`swaymsg reload` prints them), then `Super + Shift + c`.
3. `swayctl doctor` fails? The doctor reads the session env — if it reports
   no session bus, the wrapper didn't run: confirm you logged into
   `SwaySetup`, not plain `sway.desktop`.
4. Theme re-render missing apps? Check the `SWAYCTL_KEEP` markers under
   `~/.config/<app>/` — a KEEP'd file is never overwritten, by design.
5. Report back with the log tail from `~/.local/state/sway-setup/last-run.log`.