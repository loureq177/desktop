#!/bin/bash
set -euo pipefail

VENV_PYTHON="$HOME/.files/.venv/bin/python"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
AUDIO_FILE="$RUNTIME_DIR/dictate_recording.wav"
PY_PID_FILE="$RUNTIME_DIR/dictate_py.pid"
REC_PID_FILE="$RUNTIME_DIR/dictate_rec.pid"
STATUS_FILE="$RUNTIME_DIR/dictate_status"

SITE_PACKAGES=$("$VENV_PYTHON" -c "import sysconfig; print(sysconfig.get_path('purelib'))")
export LD_LIBRARY_PATH="${SITE_PACKAGES}/nvidia/cublas/lib:${SITE_PACKAGES}/nvidia/cudnn/lib:${LD_LIBRARY_PATH:-}"
export DICTATE_AUDIO_FILE="$AUDIO_FILE"

stop_dictation() {
    if [ -f "$REC_PID_FILE" ]; then
        kill "$(cat "$REC_PID_FILE")" 2>/dev/null || true
        rm -f "$REC_PID_FILE"
    fi

    if [ -f "$PY_PID_FILE" ]; then
        kill -SIGUSR1 "$(cat "$PY_PID_FILE")" 2>/dev/null || true
        rm -f "$PY_PID_FILE"
    fi

    echo "idle" >"$STATUS_FILE"
    pkill -RTMIN+8 waybar || true
}

if [ -f "$REC_PID_FILE" ] && kill -0 "$(cat "$REC_PID_FILE")" 2>/dev/null; then
    stop_dictation
else
    stop_dictation

    echo "listening" >"$STATUS_FILE"
    pkill -RTMIN+8 waybar || true

    "$VENV_PYTHON" "$(dirname "$(realpath "$0")")/dictate_backend.py" &
    echo $! >"$PY_PID_FILE"

    rm -f "$AUDIO_FILE"
    pw-record --channels=1 --rate=16000 --format=s16 "$AUDIO_FILE" &>/dev/null &
    echo $! >"$REC_PID_FILE"

    notify-send -a "Speech to Text" -i "audio-input-microphone" -t 1000 "Listening..."
fi
