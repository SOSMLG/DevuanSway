# sway-setup — project conventions

This is the working copy of the Sway Wayland desktop kit for Devuan 6
(excalibur) / Debian 13 (trixie), rebranded from the DebianSway rebuild
(which itself split from the justaguy.dev sway-setup lineage). The runtime is
a lean **Sway Wayland** desktop: sway (built-in swaybar) + foot + swaync +
rofi (+ wofi fallback) + swaylock/wlogout + grim/slurp — with a 12-palette theme engine behind
a single **`swayctl`** CLI that owns theme/bg/bar/lock/power/clip/shot/sound/
wire/toggle/status/update/doctor/setup. The old `debsway` name is kept as a
symlink alias; the old `DEBSWAY_*` env vars still work (one-line shim in
`scripts/lib/common.sh`).

When working on this repo:

- **Init & privileges.** Devuan runs OpenRC on sysvinit — there is no
  `systemctl`. Enable/start services with the OpenRC-aware helpers in
  `scripts/lib/common.sh` (`rc-update add` / `rc-service start`). Escalate
  through the `priv()` helper (doas first, sudo fallback, `DEBSWAY_PRIV` /
  `SWAY_PRIV` to force one). Never write bare `sudo`.
- **No remote install scripts.** Steps run from files in the repo and from
  local payloads (configs/, butterbash/, swayctl/); no `curl | bash`, no
  fetching scripts at install time. Downloads are packages/tarballs with
  `verify_download` size checks.
- **APT discipline.** Devuan/Debian only. No bare `apt upgrade` anywhere —
  steps install specific packages, and backports installs pin deliberately
  (`-t excalibur-backports`). Check names against `apt-cache` and use
  `install_pkgs` (installs only what's missing).
- **The steps runner.** `run.sh` discovers `scripts/##-*.sh` (phase from the
  leading digit: 1x core, 2x desktop, 3x engineering, 4x apps, 5x utils).
  Every step has `# SWAY_DESC:` / `# SWAY_DEFAULT:` headers (read by
  `--list`; the pre-rebrand `# DEBSWAY_DESC:` names still parse) and sources
  `scripts/lib/common.sh`. New step scripts must pass `bash -n` + shellcheck
  and be safe to re-run (no blind force-purges; back up before destructive
  writes). `run.sh --only` keeps the old step-name aliases working.
- **Configs.** `configs/` is canonical and deploys to `~/.config` — the live
  box mirrors it. The theme engine re-renders themed apps
  (foot/swaync/wofi+rofi/wlogout/swaylock) from
  `swayctl/themes/_base/tpl/`; files carrying a `SWAYCTL_KEEP` marker are
  never overwritten.
- **Session.** `scripts/10-sway-core.sh` owns the LightDM Greeter session —
  `sway-setup.desktop` + `sway-setup-session` wrapper (D-Bus session bus so
  swaync/portals work), exactly one DM owning the console.
- **Verification.** `verify.sh` (moved from `scripts/verifySetup.sh`) is a
  read-only audit (groups, packages, swayctl + 12-palette engine, greeter
  session, configs, services). Run it after touching configs or steps;
  `run.sh --verify` wraps it.
- **No AI tells.** This is a published fork — keep comments concrete and
  varied (say *what* and *why*, never a documentarian's monotone), no filler
  sections, no grand summaries. Match the terse style of the existing
  scripts.