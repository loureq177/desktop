# .files

My own dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).
Organized into 3 main Stow packages mirroring `$HOME`: `common`, `archlinux`, and `macos`.

## Installation

```bash
git clone https://github.com/loureq177/.files.git ~/.files
cd ~/.files
./install.sh
```

## Adding & Managing Configs

With the flattened Stow package structure, `common`, `archlinux`, and `macos` mirror your home directory directly:

```bash
# Add a new common config (e.g. starship)
mkdir -p ~/.files/common/.config/starship
mv ~/.config/starship.toml ~/.files/common/.config/starship/
stow --restow --target ~ common

# Restow configs after pulling changes
stow --restow --target ~ common archlinux
```

## Package Dependencies

- **Arch Linux**: Listed in `archlinux/packages.txt` (official), `archlinux/aur.txt` (AUR), and `archlinux/flatpak.txt` (Flatpak).
- **macOS**: Managed via `macos/Brewfile` (`brew bundle`).

