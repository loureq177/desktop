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
mv ~/.config/starship.toml ~/.files/common/.config/starship.toml
stow --restow --target ~ common

# Restow configs after pulling changes (Arch Linux)
stow --restow --target ~ common
stow --restow --target ~ archlinux

# ...or on macOS
stow --restow --target ~ common
stow --restow --target ~ macos
```

## Layout

```text
archlinux/.local/bin/   Arch-only executable scripts (on PATH)
macos/.local/bin/       macOS-only scripts (sysclean, sysupdate)
archlinux/.config/
  ui/                   ui.toml (theme source) + generated ui.sh
  hypr/                 hyprland.lua, hyprlock.conf, hypridle.conf, generated ui.{lua,conf}
  quickshell/           shell.qml + Theme/Notifications singletons
    views/              bar, launcher, clipboard, notifications, OSD, polkit
    widgets/            reusable components (SearchBar, notification parts)
common/                 cross-platform shell, editor, tools
macos/                  macOS-only configs
```

Arch executable scripts live in `archlinux/.local/bin/` (with macOS
equivalents in `macos/.local/bin/`): session helpers
(`screenshot`, `ocr`, `record-screen`, `volume`, `brightness`,
`touchpad`, `caffeine-toggle`, `power-save`, `battery-status` for hyprlock,
`emoji-insert`) and maintenance tools (`apply-ui`, `firefox-apply`, `sysclean`,
`sysupdate`, `check-updates`, `rclone-sync`, `bedtime`).

## UI Configuration & Theming

Desktop appearance (roundings, paddings, borders, gaps, fonts, colors) is
centralized in a single configuration file:

- **Config**:
  [`archlinux/.config/ui/ui.toml`](archlinux/.config/ui/ui.toml)
- **Apply & Live Reload**: run `apply-ui`
- **Verify**: `apply-ui --check`

Components synchronized:

- **Hyprland** (generated `hypr/ui.lua`): window rounding, border size,
  inner/outer gaps, opacities, colors, cursor, UI fonts
- **Quickshell** (generated `Theme.qml`): bar, launcher, keybindings menu,
  notifications, OSD and clipboard picker — roundings, borders, paddings,
  fonts, color palette
- **Hyprlock** (generated `hypr/ui.conf`): input field rounding, outline
  thickness, font, color palette
- **Ly**: display manager colors + VT console palette
- **Yazi**: theme.toml
- **Shell** (generated `ui.sh`): only variables with real consumers
  (screenshot colors, fzf theme)

## Host-Specific Configuration

Machine-local configurations are gitignored and safe from Stow:

- **Hyprland** (`~/.config/hypr/local.lua`): GPU DRM devices, monitor layouts, input overrides. See [`archlinux/.config/hypr/local.lua.example`](archlinux/.config/hypr/local.lua.example).
- **Git** (`~/.config/git/config.local`): Local name, email, GPG signing key. See [`common/.config/git/config.local.example`](common/.config/git/config.local.example).
- **Shell** (`~/.config/zsh/.zshrc.local`): Machine-specific environment variables, tokens, and aliases.
