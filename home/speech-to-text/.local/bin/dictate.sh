#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
SPEECH_DIR="$(realpath "$SCRIPT_DIR/../..")"
VENV_PYTHON="$SPEECH_DIR/.venv/bin/python"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
AUDIO_FILE="$RUNTIME_DIR/dictate_recording.wav"
STATUS_FILE="$RUNTIME_DIR/dictate_status"

update_waybar() {
    echo "$1" >"$STATUS_FILE"
    pkill -RTMIN+8 waybar || true
}

start_recording() {
    pkill -f "dictate_backend.py" || true
    rm -f "$AUDIO_FILE"
    export DICTATE_AUDIO_FILE="$AUDIO_FILE"
    update_waybar "listening"
    nohup pw-record --channels=1 --rate=16000 --format=s16 "$AUDIO_FILE" >/dev/null 2>&1 &
    "$VENV_PYTHON" "$SCRIPT_DIR/dictate_backend.py" &
}

stop_recording() {
    if ! pgrep -f "pw-record.*$AUDIO_FILE" >/dev/null; then
        exit 0
    fi

    pkill -f "pw-record.*$AUDIO_FILE" || true
    pkill -SIGUSR1 -f "dictate_backend.py" || true
    update_waybar "idle"
}

case "${1:-}" in
start) start_recording ;;
stop) stop_recording ;;
*)
    echo "Usage: $0 {start|stop}" >&2
    exit 1
    ;;
esac
