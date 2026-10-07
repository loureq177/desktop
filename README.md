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
# Restow configs
stow --restow --target ~ common
stow --restow --target ~ archlinux  # or macos

# Apply & reload UI theme (Arch)
apply-ui

# Maintenance
sysupdate   # update packages, AUR/Homebrew, tools
sysclean    # clean caches and orphans
```
