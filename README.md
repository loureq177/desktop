# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Split into
OS-specific and common configs.

## Apply configs

```sh
git clone <repo-url> ~/.files

# Apply shared configs (macOS & Linux)
cd ~/.files/common && stow --restow --target ~ */

# Apply Arch Linux configs
cd ~/.files/archlinux && stow --restow --target ~ */
```

## Manage packages

```sh
# Add a new config
mkdir -p ~/.files/common/starship/.config
mv ~/.config/starship.toml ~/.files/common/starship/.config/
cd ~/.files/common && stow --restow --target  ~ starship

# Remove a config
cd ~/.files/common && stow -D -t ~ starship
```

