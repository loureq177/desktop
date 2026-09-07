#!/usr/bin/env bash
# Rofi power menu for session suspend, reboot, and poweroff.
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
    -theme-str 'configuration { icon-theme: "Papirus"; } window { width: 680px; yoffset: -150; } listview { columns: 1; lines: 3; } element { orientation: horizontal; padding: 10px 14px; } element-icon { size: 1.8em; padding: 0 14px 0 0; } element-text { horizontal-align: 0; vertical-align: 0.5; }' \
    -format s \
    -theme ~/.config/rofi/github-dark-default.rasi) || exit 0

case "$entry" in
"suspend") loginctl lock-session && systemctl suspend ;;
"reboot") hyprshutdown --post-cmd "systemctl reboot" ;;
"poweroff") hyprshutdown --post-cmd "systemctl poweroff" ;;
esac
