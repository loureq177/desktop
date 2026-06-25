#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
SPEECH_DIR="$(realpath "$SCRIPT_DIR/../..")"
VENV_PYTHON="$SPEECH_DIR/.venv/bin/python"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
AUDIO_FILE="$RUNTIME_DIR/dictate_recording.wav"
STATUS_FILE="$RUNTIME_DIR/dictate_status"

ensure_venv() {
    if [ ! -f "$VENV_PYTHON" ]; then
        notify-send --app-name "Dictate" -t 5000 "Dictate" "Recreating Python venv..."
        python3 -m venv "$SPEECH_DIR/.venv"
        "$SPEECH_DIR/.venv/bin/pip" install --quiet --upgrade \
            faster-whisper \
            nvidia-cublas-cu12 \
            nvidia-cudnn-cu12
    fi
}

update_waybar() {
    echo "$1" >"$STATUS_FILE"
    pkill -RTMIN+8 waybar || true
}

start_recording() {
    pkill -f "dictate_backend.py" || true
    rm -f "$AUDIO_FILE"

    ensure_venv

    export DICTATE_AUDIO_FILE="$AUDIO_FILE"
    SITE_PACKAGES=$("$VENV_PYTHON" -c "import sysconfig; print(sysconfig.get_path('purelib'))")
    if [ -d "${SITE_PACKAGES}/nvidia/cublas/lib" ] && [ -d "${SITE_PACKAGES}/nvidia/cudnn/lib" ]; then
        export LD_LIBRARY_PATH="${SITE_PACKAGES}/nvidia/cublas/lib:${SITE_PACKAGES}/nvidia/cudnn/lib:${LD_LIBRARY_PATH:-}"
    fi

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
