# .files

My own dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).
Organized into 3 main Stow packages mirroring `$HOME`: `common`, `archlinux`,
and `macos`.

## Installation

```bash
git clone https://github.com/loureq177/.files.git ~/.files
cd ~/.files
./install.sh
```

## Adding & Managing Configs

With the flattened Stow package structure, `common`, `archlinux`, and `macos`
mirror your home directory directly:

```bash
# Add a new common config (e.g. starship)
mkdir -p ~/.files/common/.config/starship
mv ~/.config/starship.toml ~/.files/common/.config/starship/
stow --restow --target ~ common

# Restow configs after pulling changes
stow --restow --target ~ common archlinux
```

## UI Configuration & Theming

Desktop appearance (roundings, paddings, borders, gaps, fonts, colors) is
centralized in a single configuration file:

- **Config**:
  [`~/.config/ui/ui.toml`](file:///home/mlorenc/.files/archlinux/.config/ui/ui.toml)
- **Apply & Live Reload**: run `apply-ui`

Components synchronized:

- **Hyprland**: window rounding, border size, inner/outer gaps, opacities,
  colors, cursor, UI fonts
- **Waybar**: margins, spacing, module padding, border-radius, color palette
- **SwayNC**: notification & control center border-radius, padding, borders,
  color palette
- **Rofi**: window & element roundings, borders, paddings, fonts, color palette
- **Hyprlock**: input field rounding, outline thickness, font, color palette
