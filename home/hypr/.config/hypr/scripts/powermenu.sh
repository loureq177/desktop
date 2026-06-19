#!/usr/bin/env bash
set -euo pipefail

entry=$(printf " lock\n logout\n suspend\n reboot\n poweroff" | rofi -dmenu -p 'Power' -format s -theme ~/.config/rofi/powermenu.rasi)

case "$entry" in
" lock") hyprlock --immediate-render --no-fade-in ;;
" logout") hyprctl dispatch exit ;;
" suspend") systemctl suspend ;;
" reboot") hyprshutdown --post-cmd "systemctl reboot" ;;
" poweroff") hyprshutdown --post-cmd "systemctl poweroff" ;;
esac
