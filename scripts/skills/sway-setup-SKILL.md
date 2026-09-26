# System context: Devuan (excalibur) + Sway (Wayland, swayctl)

This machine was set up with `sway-setup` (formerly DebianSway), a
post-install toolkit for a ThinkPad-class laptop running Devuan 6 (excalibur)
— binary-compatible with Debian 13 (Trixie) — running a lean **Sway** Wayland
desktop on a dark **catppuccin-mocha** rice. Keep the following in mind when
suggesting commands or diagnosing issues on this system.

## Package management
- **APT-based** (Devuan/Debian), not Arch/Fedora/Nix. Use `apt`/`apt-get`, never
  `pacman`, `dnf`, or `nix-env`.
- `apt-get install -y <pkg>` for installs, `apt-get purge -y <pkg>` to remove.
- **Backports pinning** lives in `/etc/apt/preferences.d/backports`
  (priority 100). Install newer versions deliberately with
  `doas apt install -t excalibur-backports <pkg>` — never bare `apt upgrade`.
- Flatpak/Flathub is the secondary source (Heroic, Vesktop, Telegram).
  Browser is Firefox **ESR** (hardened with Betterfox + policies). Primary GUI
  editor is **VSCodium** (apt repo); terminal editor is Neovim + LazyVim.

## Init system & services
- **OpenRC on sysvinit** (Devuan default), PID 1 is `/sbin/init`. There is
  **no `systemctl`/systemd** — enable/start services with `rc-update add <svc>
  default` / `rc-service <svc> start`, list with `rc-status`.
- Display manager is **LightDM + lightdm-gtk-greeter** (themed to match).
  The only DM — **exactly one** owns the console. Default session: **SwaySetup**
  (a Sway Wayland session: `/usr/local/bin/sway-setup-session` + D-Bus session
  bus, `/usr/share/wayland-sessions/sway-setup.desktop`).

## Desktop environment
- **Sway 1.x on Wayland**, not X11, not a stacking WM. This changes everything:
  - Config is `~/.config/sway/config` (reload: `$mod+Shift+C`). Keyboard
    shortcuts are `bindsym` lines — there is no xfconf/sway-style registry.
  - **Every desktop action goes through `swayctl`**, the toolkit's unified
    CLI (`swayctl menu|theme|bg|bar|lock|clip|shot|sound|wire|toggle|keys|
    status|eng|update|doctor|setup`; `debsway` is a symlink alias).
    Volume/brightness OSD is a swaync popup, not a separate daemon.
  - Terminal is **foot** (`$term`), launcher is **rofi** (wofi fallback —
    `SWAY_LAUNCHER=rofi|wofi`), notifications are
    **sway-notification-center (swaync)**, screen-capture is grim/slurp/swappy,
    clipboard is cliphist+wl-clipboard, screenshot archive
    `~/Pictures/screenshots`. File manager is **Thunar** + gvfs + xarchiver.
  - Status bar: sway's **built-in swaybar** — no separate bar daemon
    (`swayctl bar restart`). `~/.config/swaybar/status.sh` speaks swaybar's
    JSON protocol (named blocks, `min_width`, palette colors) and MUST stay
    executable — sway runs it via `sh -c`. **rofi** is centered on the
    current palette (`~/.config/rofi/` is theme-rendered); **wofi** stays
    as the fallback picker, anchored bottom.
  - Night-light is **gammastep**, display management is **kanshi**, audio
    volume via pactl, media keys via playerctl, battery via TLP (80% cap) plus
    in-panel monitors.
  - Lock is **swaylock** (`swayctl lock`), power menu is **wlogout**
    (`swayctl power`), idle is swayidle. Policykit agent: `lxqt-policykit-agent`.

## Theming & the tree
- The rice is the **catppuccin-mocha** palette by default, one of **12**
  installed palettes (doomone, dracula, everforest, github_dark, gruvbox,
  kanagawa, monokai, moonfly, nord, retro, rose-pine). Switch with
  `swayctl theme set <name>` — renders sway/colors.conf, foot, swaync,
  wofi+rofi, wlogout, swaylock. Wallpapers: `swayctl bg panel`.

## This toolkit's own conventions
- Scripts live in `scripts/`, numbered `??-*.sh`:
  - 1x core (10 sway core, 11 backports, 12 user-groups, 13 hardware,
    14 bluetooth, 15 codecs, 16 firefox, 17 fonts, 18 butterbash, 19 fastfetch),
    2x desktop (20 shell-tools, 21 swayctl-cli, 22 theme-default),
    3x engineering (30 math, 31 EDA, 32 matlab), 4x apps (40 desktop-apps,
    41 timeshift, 42 opencode, 43 office-mail, 44 media, 45 gaming, 46 chat,
    47 editors), 5x utils (50 maintenance, 51 backup, 52 skel-export).
    Each is independently runnable; they source `scripts/lib/common.sh`
    (ask/log/install_pkgs/priv). Metadata comes from `# SWAY_DESC:` /
    `# SWAY_DEFAULT:` headers read by `run.sh`.
- `run.sh` orchestrates (`--list/--phase/--only/--yes/--full/--verify`);
  `install.sh` is the unattended wrapper. Env vars: `SWAY_ASSUME_YES=1`,
  `SWAY_SKIP_APT_UPDATE=1`, pins `XFCE_GTK_REF=`, `XFCE_CURSOR_TAG=v2.0.0`,
  `NERD_FONT_TAG=3.4.0`, `BETTERFOX_TAG=150.0`. State lives in
  `~/.local/state/swayctl/` (also `~/.local/state/devuan-xfce-setup/last-run.log`).
- Root escalation via `priv()`: **doas** first, sudo fallback
  (`SWAY_PRIV=doas|sudo`). Never bare `sudo`. Every apt action checks what's
  installed first; backups precede destructive writes.
- Test suite (three tiers, read-only): `make check` or `./tests/run.sh`
  (lint, sandboxed unit tests, consistency guards, read-only apt-checks).
  Run it after adding a `scripts/##-*.sh` step; content deb via `make pkg-deb`,
  verify with `make check-deb`, release gate `make release-preflight`.
- Engineering stack: Octave/GUI, Jupyter, SciLab/Xcos, Qucs, KiCad, matlab
  (BYO .deb via `swayctl eng matlab <file.deb>`); Python control/slycot in
  venv `~/.local/venv/eng` (`swayctl eng venv`).

## Working style
- Verify with real, read-only commands before asserting anything; never guess a
  package name, command output, or config value.
- After changes, run the relevant check that exists (`make check`, `bash -n`,
  `./run.sh --list`) instead of assuming success.