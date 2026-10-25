# desktop

A Hyprland desktop for Arch Linux, built on [.files](https://github.com/loureq177/.files).

## Features

- **quickshell**: bar, launcher (apps, actions, `2+2`, clipboard, emoji, keys), quick actions, notifications, OSD, polkit dialog
- **hyprlock**: password or fingerprint, locks right at login (autologin on tty1, no display manager)
- **One theme**: `~/.config/ui/ui.toml`, applied everywhere with `apply-ui`
- Screenshots, screen recording, OCR, dictation
- Web apps on special workspaces
- Battery care, power saver, idle, night light
- `sysupdate` and `sysclean`

## Install

```sh
git clone https://github.com/loureq177/.files.git ~/.files && ~/.files/install.sh
git clone https://github.com/loureq177/desktop.git ~/Projects/desktop && ~/Projects/desktop/install.sh
```

The installer changes the system: packages (official, AUR, flatpak), `/etc` (zram, the lock screen's PAM), autologin on tty1, zsh as the login shell.

Then copy `~/.config/hypr/local.lua.example` to `local.lua` for this machine's keyboard and monitors, and enroll a finger with `fprintd-enroll`.

## Keys

| Keys | Action |
| --- | --- |
| `SUPER + Return` | Terminal |
| `SUPER + Space` | Launcher |
| `SUPER + A` | Quick actions |
| `SUPER + N` | Notifications |
| `SUPER + Escape` | Lock |
| `SUPER + /` | All keys |
