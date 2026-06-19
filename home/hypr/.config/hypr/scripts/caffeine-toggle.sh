#!/usr/bin/env bash
set -euo pipefail

_status() {
    if pgrep -x hypridle >/dev/null 2>&1; then
        echo '{"text": "💤", "alt": "on", "class": "caffeine-off", "tooltip": "Idle on"}'
    else
        echo '{"text": "☕", "alt": "off", "class": "caffeine-on", "tooltip": "Stay awake"}'
    fi
}

_toggle() {
    if pgrep -x hypridle >/dev/null 2>&1; then
        pkill -x hypridle 2>/dev/null || true
    else
        hypridle &
    fi
    _status
    killall -RTMIN+1 waybar 2>/dev/null || true
}

case "${1:-}" in
--status) _status ;;
*) _toggle ;;
esac
