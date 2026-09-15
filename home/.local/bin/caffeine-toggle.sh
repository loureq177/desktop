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
        # setsid only forks when it is already a process group leader, so $! is
        # not reliably systemd-inhibit's pid. Let the inhibited command record
        # its own pid instead: killing it ends the command, so systemd-inhibit
        # exits and releases the idle inhibitor (no orphaned sleep left behind).
        # stderr goes to /dev/null: systemd-inhibit reports its command's
        # signal death on the way out, which is expected here, not an error.
        # shellcheck disable=SC2016 # $$ must expand in the inner sh, not here
        setsid systemd-inhibit --what=idle --who=caffeine \
            --why="User requested stay awake" --mode=block \
            sh -c 'echo $$ >"$1.tmp"; mv -f "$1.tmp" "$1"; exec sleep infinity' \
            sh "$INHIBIT_PID_FILE" >/dev/null 2>&1 &
        disown
    fi
}

case "${1:-}" in
--status) _status ;;
*) _toggle ;;
esac
