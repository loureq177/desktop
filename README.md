# .files

My own dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).
Split into OS-specific and common configs.

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

# Edit a config
# This is only needed when **adding or removing** files in a package.
stow --restow <folder>
```
