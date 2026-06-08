#!/usr/bin/env bash

entry=$(printf " lock\n logout\n suspend\n reboot\n shutdown" | rofi -dmenu -p 'Power' -format s)

case "$entry" in
" lock") hyprlock ;;
" logout") hyprctl dispatch exit ;;
" suspend") systemctl suspend ;;
" reboot") hyprshutdown --post-cmd "systemctl reboot" ;;
" shutdown") hyprshutdown --post-cmd "systemctl poweroff" ;;
esac
