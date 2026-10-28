# desktop

Highly optimized desktop for Arch Linunx with blazingly-fast navigation and great looks.

## Features

- **quickshell**: bar, launcher (apps, `/` actions, `2+2`, clipboard, emoji, keys), quick actions, notifications, OSD
- **hyprlock**: password or fingerprint
- **Github theme everywhere**: `~/.config/ui/ui.toml`, applied with `apply-ui`
- Screenshots, screen recording with camera, OCR
- **Dictation** with whisper-cpp under `SUPER + D`
- Web apps on special workspaces
- Battery care, power saver, awake-mode, night-light
- `sysupdate` and `sysclean`

## Install

```sh
git clone https://github.com/loureq177/desktop.git ~/Projects/desktop && ~/Projects/desktop/install.sh
```

The installer changes the system: packages (official, AUR, flatpak), `/etc` (zram, sysctl hardening, the lock screen's PAM), autologin on tty1, zsh as the login shell.

## Keys

| Keys | Action |
| --- | --- |
| `SUPER + Return` | Terminal |
| `SUPER + Space` | Launcher |
| `SUPER + A` | Quick actions |
| `SUPER + N` | Notifications |
| `SUPER + Escape` | Lock |
| `SUPER + /` | All keys |
