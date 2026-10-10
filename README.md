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
