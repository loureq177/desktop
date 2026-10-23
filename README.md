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
- copies `archlinux/etc` into `/etc` (zram, memory tuning, lid-switch inhibitors), backing up files that differ
- enables the user units of this repo that have an `[Install]` section, and `hypridle` and `hyprsunset`
- downloads the speech model that `dictation` needs (about 140 MB)

Everything in the package lists is in `core`, `extra` or the AUR; nothing needs `multilib`.

### After the first run

- `~/.config/hypr/local.lua` holds what belongs to one machine: keyboard layout (`us` without it), GPU order, monitor layout, startup commands. Start from `local.lua.example`, and keep it in a repository of the machine's own, stowed next to these links (`~/.config/hypr` is a real directory for that).
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

`~/.config/ui/ui.toml` holds the colors, fonts and sizes the desktop's programs share. `apply-ui` renders it through the templates in `~/.config/ui/templates` into Hyprland, the fallback lock screen, slurp, yazi, btop and lazygit, hands it to quickshell as `ui.js` and sets the GTK settings (Hyprland sets them again at every start with `apply-ui --gtk`); the generated files are committed, and the tests fail when they are stale. What only the shell uses (its sizes and animation timing) is set in `quickshell/Theme.qml`, and the fzf colors are written out in `.zshrc` because macOS has no `apply-ui`.

Ghostty, Neovim, bat, delta and opencode use their upstream GitHub Dark themes and do not follow `ui.toml`.

### Key binds

The launcher finds apps, the web apps and the other special workspaces among them, and the desktop's actions by name: capture, battery saver, update, lock, suspend, reboot and power off (the last three on a second Enter). `2+2` calculates on the spot. `/` and a name finds files and folders in `~` with fd, and Enter opens one. Quick actions (`SUPER + A`) has the tiles and the Capture page. `SUPER + /` lists the keys, leaving out the ones a panel prints on its tiles and buttons. The ones to know first:

| Keys | Action |
| --- | --- |
| `SUPER + Return` | Terminal |
| `SUPER + Space` | Launcher: apps and actions, `2+2` calculates, `/` finds files |
| `SUPER + A` | Quick actions (Wi-Fi, Bluetooth, capture, battery saver) |
| `SUPER + N` | Notification center |
| `SUPER + V` / `SUPER + E` | Clipboard history / emoji |
| `SUPER + Tab` | Back to the previous window |
| `SUPER + D` | Dictation: press, speak, press again |
| `Print` | Screenshot of a region |
| `SUPER + Escape` | Lock |

Everything also works with the mouse: the grid icon at the left of the bar opens the launcher, the empty field of the launcher offers its other lists (apps, emoji, clipboard, keys), and a right click on a special workspace's icon in the bar closes it.

### Good to know

- The session is locked by quickshell, which the session target starts (`quickshell.service`, restarted when it crashes). A shell that dies before the session was unlocked leaves it to `lock-fallback`, which locks with `hyprlock` instead, so autologin never ends in an open desktop.
- The weather is for the place in `~/.config/weather.json` (`{ "name": "Krakow", "latitude": 50.06, "longitude": 19.94 }`); without it the forecast asks `ipwho.is` where this IP address is.

## Testing

```bash
tests/run                # everything
tests/run install power  # selected suites (tests/*.bats, or "js")
tests/run -f wallpaper   # tests whose name matches
```

Needs `bats`; `shellcheck`, `node`, `lua`, `stow`, Qt6 `qmllint` and `Hyprland` widen the coverage, and tests that need a missing tool are skipped. Scripts run against a temporary `$HOME` with every system command stubbed, so the suite never touches the running session.

The shell scripts and the installer are tested for behaviour. The quickshell QML is checked for syntax, for references between files and for the IPC calls the scripts make; what it looks like and how it behaves on screen is not tested.
