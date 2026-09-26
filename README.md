# SwaySetup — Sway (Wayland) desktop toolkit for Devuan 6 (excalibur)

A post-install toolkit for a ThinkPad-class laptop running **Devuan 6
(excalibur)** — binary-compatible with Debian 13 (Trixie) — that stands up a
lean **Sway** Wayland desktop: one compositor, one bar, one notifier, one
launcher, one terminal, a 12-palette theme engine, and a unified
**`swayctl`** CLI that owns every desktop surface.

No systemd. No GNOME/KDE. No XFCE. OpenRC/sysvinit + LightDM, exactly one
display manager owning the console.

## Highlights

- **Sway 1.x on Wayland** as the LightDM default session (`SwaySetup`), started
  on its own D-Bus session bus; XFCE remains selectable as a manual fallback,
  never auto-started.
- **`swayctl`** — one command for theme/bg/bar/lock/power/clip/shot/sound/wire/
  toggle/status/update/doctor/setup and the engineering launchers
  (the old `debsway` name is kept as a symlink alias).
- **Theme engine, 12 palettes**: catppuccin-mocha (default), doomone, dracula,
  everforest, github_dark, gruvbox, kanagawa, monokai, moonfly, nord, retro,
  rose-pine. `swayctl theme set <name>` re-renders sway/swaybar, foot,
  swaync, wofi, wlogout, swaylock and soft-reloads the session.
- **One bar, built-in**: sway's own swaybar (no separate bar daemon).
  `swayctl bar restart` re-applies it; themed via colors.conf tokens.
  Status: `~/.config/swaybar/status.sh` — swaybar's JSON protocol (named
  blocks, `min_width`, palette colors), must stay executable; **wofi** is
  anchored bottom so it rises from just above the bar.
- **Lean footprint**: every step uses `--no-install-recommends` where it
  matters; `./run.sh --phase core,desktop` is the minimal desktop; everything
  else is your call (engineering default-on, apps default-Y).
- **Engineering, default-on**: Octave, Jupyter, SciLab/Xcos, Qucs, KiCad,
  matlab (BYO `.deb`), and a Python control-theory venv
  (`~/.local/venv/eng`, `python-control`).
- **Verify, read-only**: `run.sh --verify` / `verify.sh` audits the
  expected end state (packages, swayctl, theme engine, greeter session,
  services) without touching anything; exit non-zero flags issues.

## Install

```sh
git clone https://github.com/SOSMLG/sway-setup.git
cd sway-setup
./run.sh            # interactive — pick steps per phase
# or unattended:
./install.sh        # SWAY_ASSUME_YES=1 ./install.sh
```

Then log out and pick **SwaySetup** in the LightDM greeter.

`run.sh` flags: `--list` (show all steps), `--phase core,desktop`,
`--only <name>` (single step or old-name alias), `--yes`, `--full`,
`--verify` (post-install audit via `verify.sh`),
`--no-update`. `--minimal` means core+desktop only.

## Layout

```
run.sh               step runner (discovery, phases core·desktop·engineering·apps·utils)
install.sh           unattended one-shot wrapper
verify.sh            read-only end-state audit (run.sh --verify)
swayctl/             the swayctl CLI: bin/swayctl router
                     lib/{common,theme,actions,doctor,setup,eng}.sh
                     themes/_base/tpl  (templates with @@TOKEN@@)
                     themes/<name>/palette.sh  (12 palettes)
configs/             static user configs (sway, gammastep, kanshi,
                     mpv, swaybar/status.sh, sway/scripts, sway/wallpapers)
scripts/             steps ??-*.sh, see below
assets/  butterbash/ bundled extras
QUICKSTART.md        how to actually live here (keybindings, everyday tasks)
checklist.md         end-to-end smoke test for a fresh install
docs/                troubleshooting etc.
CONTRIBUTING.md      how to change the kit
AGENTS.md            project conventions for AI/agents working on the repo
CHANGELOG.md         fork history
```

## Steps

Phase **core** — the lean desktop itself (`--phase core`):

| Step | What it does |
|------|--------------|
| `10-sway-core.sh` | Sway stack (built-in swaybar) + swaybg/idle/lock + sway-notification-center + foot + wofi + grim/slurp/swappy/cliphist/wf-recorder + lxqt-policykit + thunar/gvfs/xarchiver + xdg-desktop-portal-wlr + fonts; deploys `configs/`; makes **SwaySetup** the LightDM default session; adds `~/.local/bin` to PATH |
| `11-backports.sh` | Enables the excalibur-backports repo (priority 100 pinning) |
| `12-user-groups.sh` | Adds the user to input/video/render/plugdev/lpadmin |
| `13-hardware.sh` | Power `tlp`, firmware, `mesa-vulkan-drivers`, GPU/driver tuning |
| `14-bluetooth.sh` | BlueZ + blueman, enables the bluetooth service |
| `15-codecs.sh` | ffmpeg + libavcodec-extra, codec plugins |
| `16-firefox.sh` | Firefox ESR + Betterfox + enterprise policies (hardened) |
| `17-fonts.sh` | JetBrainsMono Nerd Font + Fallback + fontconfig |
| `18-butterbash.sh` | ButterBash (bash it up — aliases, prompt, fkeys) |
| `19-fastfetch.sh` | fastfetch + bundled system ascii art |

Phase **desktop**:

| Step | What it does |
|------|--------------|
| `20-shell-tools.sh` | gammastep (night light), kanshi, brightnessctl, playerctl, iio-sensor-proxy |
| `21-swayctl-cli.sh` | Installs `swayctl` + theme engine, symlinks (user+system+`debsway` alias), migrates old state, applies catppuccin-mocha |
| `22-theme-default.sh` | Re-applies the default palette + wallpaper (theme override via `SWAY_THEME`) |

Phase **engineering** (default-on):

| Step | What it does |
|------|--------------|
| `30-eng-math.sh` | Dev toolchain + numpy/scipy/sympy/pandas/matplotlib + Octave + Jupyter + `python-control` venv (`~/.local/venv/eng`, `swayctl eng venv`) |
| `31-eng-eda.sh` | SciLab/Xcos, Qucs, KiCad |
| `32-eng-matlab.sh` | matlab-support + `swayctl eng matlab <file.deb>` (Matlab itself comes from MathWorks) |

Phase **apps**:
`40-desktop-apps.sh` (flatpak/cups/ufw/gparted/mpv/zathura/qbittorrent/TLP/
btop-eza-bat-zoxide-fd/yazi), `41-timeshift.sh`, `42-opencode-agent.sh`
(OpenCode + Super+A + system skill file), `43-office-mail.sh`
(LibreOffice writer+calc, Thunderbird, KeePassXC, gnome-keyring),
`44-media.sh` (OBS, Kdenlive, GIMP + PhotoGIMP layout), `45-gaming.sh`
(Heroic, Steam, Wine), `46-chat.sh` (Vesktop, Telegram — Flatpak),
`47-editors.sh` (VSCodium via apt repo, Neovim + LazyVim bootstrap).

Phase **utils**: `50-maintenance.sh`, `51-backup.sh`, `52-skel-export.sh`.

## `swayctl` in one breath

```
swayctl menu|launcher|run             app launcher / runner / palette
swayctl theme set <name>              switch palette (12 installed)
swayctl bg panel|cycle|random         wallpaper
swayctl bar restart                 re-apply the built-in swaybar
swayctl power|lock                    wlogout grid / themed swaylock
swayctl clip pick                     clipboard history
swayctl shot full|area|annotate|record
swayctl sound up|down|mute            + swaync OSD popup
swayctl wire panel                    nm-connection-editor
swayctl toggle night|dnd|touchpad|layout
swayctl keys                          keybinding cheat-sheet from sway/config
swayctl status media|layout|updates   bar-module backends
swayctl eng octave|jupyter|scilab|qucs|kicad|matlab|venv
swayctl update [--apply]              apt + flatpak
swayctl doctor                        read-only session health check
swayctl setup                         first-run wizard
```

## Conventions for extending

- Steps are `scripts/??-*.sh`, each with `# SWAY_DESC:` / `# SWAY_DEFAULT:`
  headers and sourcing `scripts/lib/common.sh` (`ask`, `log_*`, `install_pkgs`,
  `priv` = doas→sudo). New steps are auto-discovered by `run.sh`.
- Add a palette: copy `swayctl/themes/<name>/palette.sh` from any existing one
  (tokens are `C_BG..C_ORANGE`, `C_T0-7`, `C_TB0-7`, hex WITHOUT `#`).
- Add a themed app: drop a template in `swayctl/themes/_base/tpl/<app>/`.
- Root escalation: `priv()` — never bare `sudo` in new code.
- Backups (`*.bak.<timestamp>`) precede any destructive write; scripts are
  safe to re-run.

## Session & services notes

- Init is OpenRC/sysvinit — `rc-update add <svc> default` / `rc-service <svc> start`,
  `rc-status`. `systemctl` does not exist.
- LightDM owns the console; the `SwaySetup` wayland session provides its own
  D-Bus session bus so swaync/portals work.
- Engineering Python: the venv is `--system-site-packages`, so it reuses
  apt's numpy/scipy while adding pip-only `control` (and optionally `slycot`).# DevuanSway
# DevuanSway
# DevuanSway
