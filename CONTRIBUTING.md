# Contributing

Pull requests are welcome. The fork lives on GitHub at
[SOSMLG/sway-setup](https://github.com/SOSMLG/sway-setup) — fork it, branch
off `main`, and open a PR. There's no CI gate yet, so the review is whatever
the maintainer is in the mood for, but the checklist below is what gets a
change merged without back-and-forth.

## The rules of the road

These aren't cosmetic. The repo is Devuan-first and that shows up in every
script, so keep it that way:

- **Never write bare `sudo`.** Escalation goes through `priv()` from
  `scripts/lib/common.sh` (doas first, sudo fallback, `SWAY_PRIV` override —
  the legacy `DEBSWAY_PRIV` still works).
- **Never assume systemd.** Services go through the OpenRC-aware helpers in
  `common.sh`. No `systemctl` in new code, no systemd timers. `rc-update` /
  `rc-service` on Devuan, sysvinit fallback elsewhere.
- **No root, ever.** Steps refuse to run as root and escalate only the small
  parts that need elevation. Per-user state lands in the real user's `$HOME`,
  which is why `run.sh` and every step check `id -u` up front.
- **Nothing remote is piped into bash.** Install step content runs from files
  on disk and from local payloads (butterbash/, configs/, swayctl/). When a
  tool needs an installer, install the artifact through a real package path
  (apt, Flatpak, npm, a `.deb`) or print the command for the user to run
  themselves.
- **No bare `apt upgrade`.** Steps install specific packages. If a step needs
  a newer version from backports, it pins deliberately with
  `-t excalibur-backports` — never a blanket upgrade.

## Adding or changing a step

Steps live in `scripts/##-*.sh`. The leading digit decides the phase — `1`
core, `2` desktop, `3` engineering, `4` apps, `5` utils — and `run.sh` sorts
by filename, so number accordingly.

- Every step carries two headers near the top, no exceptions:
  `# SWAY_DESC:` (one line) and `# SWAY_DEFAULT:` (`Y` or `N`). `./run.sh
  --list` reads them, and the README's phase table is generated from the same
  source. The old `DEBSWAY_DESC:`/`DEBSWAY_DEFAULT:` header names are still
  parsed if you forked from an older copy — but write new ones as `SWAY_*`.
- Source `scripts/lib/common.sh` and use its helpers: `ask()`,
  `install_pkgs()` (which skips what's already installed and checks the apt
  cache before touching anything), `apt_update()`, `ensure_repo_component()`,
  `require_not_root()`, `priv()`, `die()`.
- Be idempotent. Every script is safe to re-run: check before installing,
  skip what's present, and never force-purge. Backup (`*.bak.<timestamp>`)
  before any destructive config write.
- Keep the script honest about its failures. `install_pkgs` records a warning
  when something is skipped; if a step genuinely can't proceed, exit non-zero
  and say why.

## Changing the theme engine

The 12-palette engine is `swayctl/` — the router in `swayctl/bin/swayctl`,
the libs in `swayctl/lib/` (`common`, `theme`, `actions`, `doctor`, `setup`,
`eng`), palettes in `swayctl/themes/<name>/palette.sh`, templates in
`swayctl/themes/_base/tpl/<app>/`.

- Palette tokens are `C_BG..C_ORANGE`, `C_T0-7`, `C_TB0-7` — hex **without**
  the `#` (templates add it). Add a palette by copying any existing one and
  changing the values; the 12-palette list is: catppuccin-mocha (default),
  doomone, dracula, everforest, github_dark, gruvbox, kanagawa, monokai,
  moonfly, nord, retro, rose-pine.
- Templates are `@@TOKEN@@` placeholders rendered by `render_palette()` in
  `swayctl/lib/theme.sh`. If you change a template, note that already-rendered
  copies under `~/.config/` won't re-render unless the file is regenerated —
  and files carrying a `SWAYCTL_KEEP` marker are never overwritten, by design.
- If you touch a palette, you touched everything: sway (swaybar built in), foot,
  swaync, wofi, wlogout, swaylock. `verify.sh` spot-checks the default
  palette, and it will tell you.

## Before you push

1. `bash -n` anything you touched, and run `shellcheck` on it if you have it.
2. `./run.sh --list` — if you changed a step's headers, confirm they render
   with the right phase/description/default.
3. If your change affects the end state, run `./run.sh --verify` (or `bash
   verify.sh`) — a read-only audit that must exit with zero FAILs.
4. Update the CHANGELOG fork section for user-visible changes. Keep the
   historical upstream entries below it untouched.

## Docs

The README, QUICKSTART and this file are read by people who just installed
the thing. Keep them in a human voice and make sure they match the code — if
a binding or a script changed, the keybinding table and the configuration
tree changed with it. There's no wiki; if it isn't in the repo, it doesn't
exist.