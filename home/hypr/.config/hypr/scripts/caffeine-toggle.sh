#!/usr/bin/env bash
PID_FILE="/tmp/hypridle-caffeine.pid"

_status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo '{"text": "💤", "alt": "on", "class": "caffeine-off", "tooltip": "Idle on"}'
    else
        echo '{"text": "☕", "alt": "off", "class": "caffeine-on", "tooltip": "Stay awake"}'
    fi
}

_toggle() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        kill "$(cat "$PID_FILE")" 2>/dev/null
        rm -f "$PID_FILE"
    else
        pkill -x hypridle 2>/dev/null
        hypridle &
        echo $! > "$PID_FILE"
    fi
    _status
}

case "${1:-}" in
--status) _status ;;
*) _toggle ;;
esac
