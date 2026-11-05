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
    - Launcher (apps, `/commands`, clipboard, emoji, keys)
    - Files under `SUPER + G`: your home folder searched by name as you type, with fd
    - Actions, notifications, OSD
    - Hot corners: the top left opens the launcher, the top right Actions
    - Open windows under `SUPER + O`: a list of the launcher, every window with a
      live picture, on any workspace; also a right-click on the launcher's icon
    - Weather module
    - Memory on the bar above 70%, always in Actions
    - Tray: the apps running in the background (Discord, Steam)
- **Hyprlock**: password or fingerprint
- **Github theme**: `~/.config/ui/ui.toml`, change it with `apply-ui`: the shell,
  Hyprland, the lock screen, GTK and Qt programs (qt6ct)
- Screenshots with edits, screen recording with mic and camera!!, OCR
- **Dictation** with Parakeet under `SUPER + D`, Polish and English mixed
- Battery care, awake-mode, night-light
- **Settings** under `SUPER + S`: displays, Wi-Fi, Bluetooth, audio, and every option
  of Hyprland and the theme, searchable, changed on the spot
- **LocalSend** in the tray from the start, for files to and from the phone
- **Keys** under `SUPER + /`: every bind, Enter gives it new keys, Delete twice
  removes it, the first row adds a new one (kept in `~/.config/hypr/keys.lua`),
  Ctrl+R gives the config's back
- `sysupdate` and `sysclean` scripts, their steps run at once
- A notification when the system runs out of RAM and kills an app
- Wallpaper switcher with grow animation (SUPER + P)

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
password, once, and one screen of choices: your browser (Firefox, LibreWolf,
Waterfox, Zen, Chromium, ungoogled-chromium, Brave or Chrome, which also runs the web
apps) and the apps on special workspaces, each with its key, starting from the standard
set (calendar, mail, tasks, messages, music, files, activity). `+ Add an app` offers the
rest (notes, social, video, maps, code, work chat, meetings...) or your own, a site or a
program. The answers stay in `~/.config/apps/apps.toml`; `install.sh --defaults` skips
the questions.

The installer changes the system: packages (official, flatpak, and a few built from
their makers' own releases in `home/.local/share/pkgbuilds`, never from the AUR),
`/etc` (the session on tty1, zram, sysctl hardening, the lock screen's PAM), autologin
on tty1. It also clones and installs [`.files`](https://github.com/loureq177/.files)
(zsh as the login shell, Ghostty, nvim and the terminal tools);
`--no-dotfiles` leaves it out and the desktop still starts.

## Keys

| Keys             | Action        |
| ---------------- | ------------- |
| `SUPER + /`      | All keys      |
| `SUPER + Space`  | Launcher      |
| `SUPER + A`      | Actions       |
| `SUPER + N`      | Notifications |
| `SUPER + S`      | Settings      |
| `SUPER + Escape` | Lock          |
