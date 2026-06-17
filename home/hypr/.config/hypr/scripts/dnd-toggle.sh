#!/usr/bin/env bash

status() {
    if makoctl mode 2>/dev/null | grep -q dnd; then
        echo '{"text": "󰂛", "class": "dnd-on", "tooltip": "Do Not Disturb"}'
    else
        echo '{"text": "󰂚", "class": "dnd-off", "tooltip": "Notifications on"}'
    fi
}

toggle() {
    if makoctl mode 2>/dev/null | grep -q dnd; then
        makoctl mode -r dnd >/dev/null 2>&1
    else
        makoctl mode -a dnd >/dev/null 2>&1
    fi
    status
}

case "${1:-}" in
--status) status ;;
*) toggle ;;
esac
