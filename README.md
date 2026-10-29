# desktop

I created this desktop because I wanted full control over user space, a perfect
UI and UX, and sane defaults.

I focused on:

- Very fast and easy navigation with keyboard only and mouse as well.
- Polished, cosistent look and feel.
- Ease of use and full customizability
- Compatibility with both laptops and PC's
- Low resource usage

https://github.com/user-attachments/assets/d2909d79-4228-4f4d-b8bc-892f29cc3b61

## Features

This desktop is minimalistic (~8k LOC), but it doesn't compromise on
functionality.

### Sane defaults

- **Hyprland:** Tiling windows, web apps on special workspaces with shortcuts
  (quickly respond to message, save task, check calendar, change music...)
- **Quickshell**:
    - Launcher (apps, `/actions`, clipboard, emoji, keys)
    - quick actions, notifications, OSD
    - Weather module
    - RAM usage indicatorr
    - Tray: the apps running in the background (Discord, Steam)
- **Hyprlock**: password or fingerprint
- **Github theme**: `~/.config/ui/ui.toml`, change it with `apply-ui`
- Screenshots with edits, screen recording with mic and camera!!, OCR
- **Dictation** with whisper-cpp under `SUPER + D`
- Battery care, power saver, awake-mode, night-light
- **Settings** under `SUPER + S`: every option of Hyprland, the theme and the
  desktop's modes, searchable, changed on the spot
- `sysupdate` and `sysclean` scripts, their steps run at once
- A notification when the system runs out of RAM and kills an app
- Wallpaper swither with grow animation (SUPER + P)

### Laptop features

- Prioritizes low battery usage
- Battery saver
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

The installer changes the system: packages (official, AUR, flatpak), `/etc`
(zram, sysctl hardening, the lock screen's PAM), autologin on tty1, zsh as the
login shell. It also clones and installs [`.files`](https://github.com/loureq177/.files)
(zsh, Ghostty, nvim), which the login and the terminal need.

## Keys

| Keys                     | Action        |
| ------------------------ | ------------- |
| `SUPER + /`              | All keys      |
| `SUPER + Space`          | Launcher      |
| `SUPER + A`              | Quick actions |
| `SUPER + N`              | Notifications |
| `SUPER + S`              | Settings      |
| `SUPER + Escape`         | Lock          |
| `SUPER + SHIFT + Escape` | Power menu    |