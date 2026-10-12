# .files

Dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). Automatically detects Arch Linux or macOS and applies the matching configuration and packages.

## Installation

```bash
git clone https://github.com/loureq177/.files.git ~/.files
cd ~/.files
./install.sh
```

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
