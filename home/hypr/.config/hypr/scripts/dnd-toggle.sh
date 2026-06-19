#!/usr/bin/env bash
set -euo pipefail

status() {
    if makoctl mode 2>/dev/null | grep -q dnd; then
        echo '{"text": "󰂛", "class": "dnd-on", "tooltip": "Do Not Disturb"}'
    else
        echo '{"text": "󰂚", "class": "dnd-off", "tooltip": "Notifications on"}'
    fi
}

toggle() {
    makoctl mode -t dnd >/dev/null 2>&1
    status
    killall -RTMIN+1 waybar 2>/dev/null || true
}

case "${1:-}" in
--status) status ;;
*) toggle ;;
esac
