# .files

Dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). Split into
OS-specific and common configs.

## Features

- **Arch Linux specific:** Hyprland, Waybar, Rofi, Mako, Ly, Wireplumber,
  Systemd
- **Common:** Neovim, Ghostty, Zsh, Starship, Yazi, Bat, Btop, Git, SSH

## Prerequisites

- `stow`

## Installation

```bash
git clone [https://github.com/loureq177/.files.git](https://github.com/loureq177/.files.git) ~/.files
cd ~/.files
./install.sh
```

## Manage packages

```bash
# Add a new config (package structure: common/<pkg>/.config/<app>/)
mkdir -p ~/.files/common/starship/.config/starship
mv ~/.config/starship.toml ~/.files/common/starship/.config/starship/
stow --restow --target ~ -d common starship

# Remove a config
stow -D --target ~ -d common starship
```
