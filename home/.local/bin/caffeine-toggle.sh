#!/usr/bin/env bash
# Toggles idle inhibition via systemd-inhibit and signals the bar. Usage: [--status]
set -euo pipefail

INHIBIT_PID_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/caffeine_inhibit.pid"

_is_active() {
    [[ -f "$INHIBIT_PID_FILE" ]] && kill -0 "$(<"$INHIBIT_PID_FILE")" 2>/dev/null
}

_status() {
    if _is_active; then
        echo '{"text": "", "alt": "on", "class": "on", "tooltip": "Stay awake"}'
    else
        rm -f "$INHIBIT_PID_FILE"
        echo '{"text": "", "alt": "off", "class": "off", "tooltip": "Idle"}'
    fi
}

_toggle() {
    if _is_active; then
        kill "$(<"$INHIBIT_PID_FILE")" 2>/dev/null || true
        rm -f "$INHIBIT_PID_FILE"
    else
        setsid systemd-inhibit --what=idle --who=caffeine --why="User requested stay awake" --mode=block sleep infinity &
        echo $! > "$INHIBIT_PID_FILE"
    fi
}

case "${1:-}" in
--status) _status ;;
*) _toggle ;;
esac
