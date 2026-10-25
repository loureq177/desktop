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
- enables autologin on tty1 for the current user and makes zsh the login shell: the login shell starts Hyprland, which locks the session at once with `hyprlock`
- copies `archlinux/etc` into `/etc` (zram and its sysctls, zswap off, the lock screen's PAM file), backing up files that differ
- enables the user units of this repo that have an `[Install]` section, and `hypridle` and `hyprsunset`
- downloads the speech model that `dictation` needs (about 140 MB)

Everything in the package lists is in `core`, `extra` or the AUR; nothing needs `multilib`.

### After the first run

- `~/.config/hypr/local.lua` holds what belongs to one machine: keyboard layout (`us` without it), GPU order, monitor layout, startup commands. Start from `local.lua.example`, and keep it in a repository of the machine's own, stowed next to these links (`~/.config/hypr` is a real directory for that).
- Firefox gets its defaults (`firefox-defaults/user.js`) at the first login after it has run once.
- The lock screen accepts a fingerprint if one is enrolled (`fprintd-enroll`).

## Layout

- `common/` – configs shared by both systems, linked into `~`, and the Brewfile of macOS
- `archlinux/` – Hyprland, quickshell, scripts and package lists; `archlinux/etc` is copied to `/etc` instead of linked

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

`~/.config/ui/ui.toml` holds the colors, fonts and sizes the desktop's programs share. `apply-ui` renders it through the templates in `~/.config/ui/templates` into Hyprland, the lock screen (`hyprlock`), Hyprland's own dialogs and `hyprshutdown` (`hyprtoolkit.conf`), slurp, yazi, btop and lazygit, hands it to quickshell as `ui.js` and sets the GTK settings (Hyprland sets them again at every start with `apply-ui --gtk`); the generated files are committed, and the tests fail when they are stale. What only the shell uses (its sizes and animation timing) is set in `quickshell/Theme.qml`, and the fzf colors are written out in `.zshrc` because macOS has no `apply-ui`.

Ghostty, Neovim, bat, delta and opencode use their upstream GitHub Dark themes and do not follow `ui.toml`.

### Key binds

The launcher finds apps, the web apps and the other special workspaces among them, and the desktop's actions by name: capture, battery saver, update, lock, suspend, reboot and power off (the last three on a second Enter). `2+2` calculates on the spot. Quick actions (`SUPER + A`) has the tiles and the Capture page. `SUPER + /` lists the keys, leaving out the ones a panel prints on its tiles and buttons. The ones to know first:

| Keys | Action |
| --- | --- |
| `SUPER + Return` | Terminal |
| `SUPER + Space` | Launcher: apps and actions, `2+2` calculates |
| `SUPER + A` | Quick actions (Wi-Fi, Bluetooth, capture, battery saver) |
| `SUPER + N` | Notification center |
| `SUPER + V` / `SUPER + E` | Clipboard history / emoji |
| `SUPER + Tab` | Back to the previous window |
| `SUPER + D` | Dictation: press, speak, press again |
| `Print` | Screenshot of a region |
| `SUPER + Escape` | Lock |

Everything also works with the mouse: the grid icon at the left of the bar opens the launcher, the empty field of the launcher offers its other lists (apps, emoji, clipboard, keys), and a right click on a special workspace's icon in the bar closes it.

### Good to know

- The session is locked by `hyprlock`: at login (`hyprland.lua`, over the blurred wallpaper with `hyprlock-boot.conf`) and when `hypridle` asks (`SUPER + Escape`, idle, suspend). It is its own process, so the shell (`quickshell.service`, restarted when it crashes) can fail without leaving the session open.
- The weather is for the place in `~/.config/weather.json` (`{ "name": "Krakow", "latitude": 50.06, "longitude": 19.94 }`); without it the forecast asks `ipwho.is` where this IP address is.

## Testing

```bash
tests/run                # everything
tests/run static         # selected suites (tests/*.bats)
tests/run -f hyprland    # tests whose name matches
```

Needs `bats`; `shellcheck`, `node`, `luac`, `stow`, Qt6 `qmllint` and `Hyprland` widen the coverage, and tests that need a missing tool are skipped. Nothing is run against the running session.

Every file is checked for syntax by the program that reads it (Hyprland loads `hyprland.lua` itself), and the repo for agreeing with itself: the IPC calls the scripts make, the files QML refers to, the scripts and units that refer to each other, the stow links, the package lists and the files `apply-ui` generates. What the scripts do and how the desktop looks is not tested.
