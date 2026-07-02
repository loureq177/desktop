#!/usr/bin/env bash
set -euo pipefail

menu_options=(
    "suspend\0icon\x1fsystem-suspend"
    "reboot\0icon\x1fsystem-reboot"
    "poweroff\0icon\x1fsystem-shutdown"
)

entry=$(printf "%b\n" "${menu_options[@]}" | rofi \
    -dmenu \
    -p 'Power' \
    -show-icons \
    -theme-str 'configuration { icon-theme: "Papirus"; }' \
    -format s \
    -theme ~/.config/rofi/tokyonight.rasi) || exit 0

case "$entry" in
"suspend") systemctl suspend ;;
"reboot") hyprshutdown --post-cmd "systemctl reboot" ;;
"poweroff") hyprshutdown --post-cmd "systemctl poweroff" ;;
esac
