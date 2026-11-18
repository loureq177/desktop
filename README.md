# desktop

I created this desktop because I wanted full control over user space, a perfect
UI and UX, and sane defaults.

I focused on:

- Very fast and easy navigation with keyboard only and mouse as well.
- Polished, consistent look and feel.
- Ease of use and full customizability
- Compatibility with both laptops and PC's
- Low resource usage

https://github.com/user-attachments/assets/d2909d79-4228-4f4d-b8bc-892f29cc3b61

## Features

This desktop is minimalistic (~14k LOC, ~8k of them the shell), but it doesn't
compromise on functionality.

### Sane defaults

- **Hyprland:** Tiling windows, your apps on special workspaces under
  `SUPER + SHIFT + key` (quickly respond to a message, save a task, check the
  calendar, change music...): optional, picked while installing, again with
  `apply-apps --pick`, which installs a new pick and swaps it in at once, browser too
- **Quickshell**:
    - Launcher (apps, `/commands`, clipboard, emoji, keys): the most used first; typing
      also finds every command, settings and files in your home folder, by name with fd;
      `Delete` twice hides an app
    - Power menu under `SUPER + Escape`: lock, suspend, log out, reboot, power off; with
      NVIDIA beside another GPU, reboot without it (a faster boot, kept until switched back) or with it
    - Actions, notifications, OSD
    - Open windows under `SUPER + O`: a list of the launcher, every window with a
      live picture, on any workspace; also a right-click on the launcher's icon
    - Weather module, for where the network is or a town set in Settings
    - Memory on the bar above 70%, always in Actions
    - Tray: the apps running in the background (Discord, Steam)
- **Hyprlock**: password
- **Github theme**: `~/.config/ui/ui.toml`, change it with `apply-ui`: the shell,
  Hyprland, the lock screen, GTK and Qt programs (qt6ct)
- Screenshots with edits, screen recording with mic and camera!!, OCR
- **Dictation** with Parakeet under `SUPER + D`, Polish and English mixed
- Battery care, awake-mode, night-light, Focus: notifications held for a time you pick
  (counted down on the bar), the wallpaper off and other windows dimmed (both can be left
  out in Settings); notifications also held while the screen is shared
- **Settings** under `SUPER + S`: displays, sound, the look (wallpaper, accent, gaps,
  fonts), the bar, keyboard, mouse and touchpad, sleep; every other Hyprland option in
  Advanced; searchable, changed on the spot, each change undone in one place
- **LocalSend** for files to and from the phone: started from the launcher, in the tray while it runs
- **Cloud drives** as folders: `cloud-drive add Cloud` signs in to Google Drive in the
  browser and mounts it at `~/Cloud` (any rclone backend: `cloud-drive add OneDrive onedrive`);
  files come down as they are opened, saves go up in seconds, changes from the phone show
  within half a minute
- **Keys** under `SUPER + /`: every bind, Enter gives it new keys, Delete twice
  removes it, the first row adds a new one (kept in `~/.config/hypr/keys.lua`),
  Ctrl+R gives the config's back
- `sysupdate` and `sysclean` scripts, their steps run at once
- A notification when the system runs out of RAM and kills an app
- Wallpaper switcher with grow animation (a picker in Settings)

### Laptop features

- Prioritizes low battery usage
- Battery care
- Keep awake (close the lid and your agent doesn't stop)
- Gestures for special workspace open/close and workspace switching

## Requirements

For now this desktop only works on Arch Linux. Install script takes care of
dependencies and symlinks.

## Install

```sh
git clone https://github.com/loureq177/desktop.git ~/Projects/desktop && ~/Projects/desktop/install.sh
```

It first shows what it will do; Enter starts it, Ctrl+C stops it. Then the sudo
password, once, and one screen of choices: your browser (Firefox, Zen,
Chromium or Helium, which also runs the web apps; Zen and Helium are built from their
makers' releases once picked) and the apps on special workspaces, each with its
key, starting from the standard set (calendar, mail, messages, music, files, notes; the
activity monitor is always there). `+ Add an app` offers the rest (AI, social,
video, maps, code, work chat, meetings...) or your own, a site or a program. The answers stay in `~/.config/apps/apps.toml`; `install.sh --defaults` skips
the questions.

The installer changes the system: packages (official, flatpak, and a few built from
their makers' own releases in `home/.local/share/pkgbuilds`, never from the AUR),
`/etc` (the session on tty1, zram, sysctl hardening, the lock screen's PAM), autologin
on tty1. It also clones and installs [`.files`](https://github.com/loureq177/.files)
(zsh as the login shell, Ghostty, nvim and the terminal tools);
`--no-dotfiles` leaves it out and the desktop still starts.

`install.sh` asks, then runs two parts: `install/system.sh` as root (packages, `/etc`,
autologin; it also runs in a chroot, leaving what needs the running system for its next
boot) and `install/user.sh` as you (flatpaks, the packages built here, `.files`, the links
into `~`, the theme and the session's units).

## Keys

| Keys             | Action        |
| ---------------- | ------------- |
| `SUPER + /`      | All keys      |
| `SUPER + Space`  | Launcher      |
| `SUPER + A`      | Actions       |
| `SUPER + N`      | Notifications |
| `SUPER + S`      | Settings      |
| `SUPER + Escape` | Power menu    |

## Workarounds

Fixes for other projects' bugs. `sysupdate` names the ones to retest when their package
updates; drop each once its cause is fixed upstream.

| Package       | Bug                                                                    | Here                                                                                          | Drop when                        |
| ------------- | ---------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | -------------------------------- |
| hyprland      | Hiding a special leaves the keyboard on its hidden window             | `specials.toggle` moves the cursor off the bar; the bar's special icons act on release        | Hyprland refocuses on hide       |
| hyprland      | The pointer is not re-entered when a layer under it shrinks           | `StandbyWindow` calls `Hypr.refreshPointer`                                                   | a click after a panel closes lands |
| wireplumber   | Device reservation races a suspend or VT switch: only "Dummy Output"  | `wireplumber.conf.d/54-no-device-reservation.conf`                                            | WirePlumber fixes reserve-device |
| nvidia-utils  | Idle clocks drop frames on the dock's monitors                        | `etc/nvidia-clock-floor.sh`, its udev rule and unit                                           | animations are smooth without it |
| nvidia-utils  | A monitor on the dock's MST stays black                               | `etc/modprobe.d/nvidia-display-sync.conf`                                                     | it lights up without it          |
| nvidia-utils  | The panel can stay on the frame from the moment of sleep              | `etc/systemd/system/suspend-settle.service`, `refresh_panel` in `monitors.lua`                | long sleeps wake without it      |
