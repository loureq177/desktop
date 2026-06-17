# .files

Dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). Split into
OS-specific and common configs.

## Features

- **Arch Linux specific:** Hyprland, Waybar, Rofi, Mako, Ly, Wireplumber,
  Systemd
- **Common:** Neovim, Ghostty, Zsh, Starship, Yazi, Bat, Btop, Git, SSH,
  Prettier

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
# Add a new config
mkdir -p ~/.files/common/starship/.config
mv ~/.config/starship.toml ~/.files/common/starship/.config/
cd ~/.files/common && stow --restow --target ~ starship

# Remove a config
cd ~/.files/common && stow -D -t ~ starship
```
