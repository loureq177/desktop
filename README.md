# dotfiles

Managed with GNU Stow. Clone to `~/.files` and symlink configs into `$HOME`.

```sh
git clone <repo-url> ~/.files
cd ~/.files

# install one package (creates symlinks into $HOME)
stow -t ~ zsh

# install everything in this repo
stow -t ~ */

# add a new config
mkdir -p starship/.config
mv ~/.config/starship.toml starship/.config/starship.toml
stow -t ~ starship

# re-link after edits / conflicts
stow -R -t ~ starship

# remove links
stow -D -t ~ starship
```
