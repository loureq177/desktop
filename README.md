# .files

Dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). Automatically detects Arch Linux or macOS and applies the matching configuration and packages.

## Installation

```bash
git clone https://github.com/loureq177/.files.git ~/.files
cd ~/.files
./install.sh
```

On Arch the installer changes the system, not only the home directory:

- upgrades the system and installs `archlinux/packages.txt` (plus `packages-laptop.txt` on a machine with a battery), the flatpaks, and the AUR packages; `paru` is built from the AUR if it is missing
- links `common/` and `archlinux/` into `~`
- enables autologin on tty1 for the current user and makes zsh the login shell: the login shell starts Hyprland and the shell locks the session at once
- copies `archlinux/etc` into `/etc` (keyd, zram, memory tuning, lid-switch inhibitors), backing up files that differ
- enables the user units of this repo that have an `[Install]` section, and `hypridle`
- downloads the speech model that `dictation` needs (about 140 MB)

Everything in the package lists is in `core`, `extra` or the AUR; nothing needs `multilib`.

### After the first run

- `~/.config/hypr/local.lua` holds what belongs to one machine: GPU order, monitor layout, startup commands. Start from `local.lua.example`.
- Firefox gets its defaults (`firefox-defaults/user.js`) at the first login after it has run once.
- The lock screen accepts a fingerprint if one is enrolled (`fprintd-enroll`).

## Layout

- `common/` – configs shared by both systems, linked into `~`
- `archlinux/` – Hyprland, quickshell, scripts and package lists; `archlinux/etc` is copied to `/etc` instead of linked
- `macos/` – Brewfile and scripts

Machine-local files (`local.lua`, `config.local`, `.zshrc.local`, `~/.ssh/config`) are ignored by git and stow; each has an `.example` next to it.

## Usage

```bash
stow --restow --target ~ common
stow --restow --target ~ archlinux

apply-ui

sysupdate
sysclean
```

`sysupdate` upgrades the official packages without asking, then shows what changed in the AUR packages and asks before building them.

### Theme

`~/.config/ui/ui.toml` is the source for colors, fonts, spacing and animation timing. `apply-ui` writes them into Hyprland, quickshell, yazi, btop, lazygit, the fallback lock screen, fzf and slurp; the generated files are committed, and the tests fail when they are stale. Palette-only configs are plain templates in `~/.config/ui/templates`.

Ghostty, Neovim, bat, delta and opencode use their upstream GitHub Dark themes and do not follow `ui.toml`.

### Key binds

`SUPER + /` shows every key bind. The ones to know first:

| Keys | Action |
| --- | --- |
| `SUPER + Return` | Terminal |
| `SUPER + Space` | Launcher (apps, `>` commands, calculator, power menu) |
| `SUPER + A` | Quick settings (Wi-Fi, Bluetooth, capture, power-save) |
| `SUPER + N` | Notification center |
| `SUPER + C` / `SUPER + E` | Clipboard history / emoji |
| `SUPER + D` | Dictation: press, speak, press again |
| `Print` | Screenshot of a region |
| `SUPER + Escape` | Lock |

### Good to know

- The session is locked by quickshell. If it cannot start, `quickshell-session` locks with `hyprlock` instead, so autologin never ends in an open desktop.
- Without a location set in the weather panel, the forecast asks `ipwho.is` where this IP address is.

## Testing

```bash
tests/run                # everything
tests/run install power  # selected suites (tests/*.bats, or "js")
tests/run -f wallpaper   # tests whose name matches
```

Needs `bats`; `shellcheck`, `node`, `lua`, `stow`, Qt6 `qmllint` and `Hyprland` widen the coverage, and tests that need a missing tool are skipped. Scripts run against a temporary `$HOME` with every system command stubbed, so the suite never touches the running session.

The shell scripts and the installer are tested for behaviour. The quickshell QML is checked for syntax, for references between files and for the IPC calls the scripts make; what it looks like and how it behaves on screen is not tested.
