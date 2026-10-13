# .files

Dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). Automatically detects Arch Linux or macOS and applies the matching configuration and packages.

## Installation

```bash
git clone https://github.com/loureq177/.files.git ~/.files
cd ~/.files
./install.sh
```

On Arch the installer also changes the system: it upgrades and installs packages, enables autologin on tty1 for the current user, copies `archlinux/etc` into `/etc` (keyd, zram and memory tuning) and enables the user timers. AUR packages need `paru` to be installed first.

## Layout

- `common/` – configs shared by both systems, linked into `~`
- `archlinux/` – Hyprland, quickshell, scripts and package lists; `archlinux/etc` is copied to `/etc` instead of linked
- `macos/` – Brewfile and scripts

## Usage

```bash
stow --restow --target ~ common
stow --restow --target ~ archlinux

apply-ui

sysupdate
sysclean
```

## Testing

```bash
tests/run                # everything
tests/run install power  # selected suites (tests/*.bats, or "js")
tests/run -f wallpaper   # tests whose name matches
```

Needs `bats`; `shellcheck`, `node`, `lua`, `stow`, Qt6 `qmllint` and `Hyprland` widen the coverage, and tests that need a missing tool are skipped. Scripts run against a temporary `$HOME` with every system command stubbed, so the suite never touches the running session.
