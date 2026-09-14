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

## Layout

```text
archlinux/.local/bin/   every executable script (on PATH)
archlinux/.config/
  ui/                   ui.toml (theme source) + generated ui.sh
  hypr/                 hyprland.lua, hyprlock.conf, hypridle.conf, generated ui.{lua,conf}
  quickshell/           shell.qml + Theme/Notifications singletons
    views/              bar, launcher, clipboard, notifications, OSD, polkit
    widgets/            reusable components (SearchBar, notification parts)
common/                 cross-platform shell, editor, tools
macos/                  macOS-only configs
```

All executable scripts live in `archlinux/.local/bin/`: session helpers
(`screenshot.sh`, `ocr.sh`, `record-screen.sh`, `volume.sh`, `brightness.sh`,
`caffeine-toggle.sh`, `power-save.sh`, `battery-status.sh` for hyprlock,
`emoji-insert.sh`) and maintenance tools (`apply-ui`, `sysclean`, `sysupdate`,
`check-updates`, `rclone_sync`, `bedtime.sh`).

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
