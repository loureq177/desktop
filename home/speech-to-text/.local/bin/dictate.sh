#!/bin/bash
set -euo pipefail

VENV_PYTHON="$HOME/.files/archlinux/speech-to-text/.venv/bin/python"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
AUDIO_FILE="$RUNTIME_DIR/dictate_recording.wav"
PY_PID_FILE="$RUNTIME_DIR/dictate_py.pid"
REC_PID_FILE="$RUNTIME_DIR/dictate_rec.pid"
STATUS_FILE="$RUNTIME_DIR/dictate_status"

SITE_PACKAGES=$("$VENV_PYTHON" -c "import sysconfig; print(sysconfig.get_path('purelib'))")
export LD_LIBRARY_PATH="${SITE_PACKAGES}/nvidia/cublas/lib:${SITE_PACKAGES}/nvidia/cudnn/lib:${LD_LIBRARY_PATH:-}"
export DICTATE_AUDIO_FILE="$AUDIO_FILE"

trap 'rm -f "$REC_PID_FILE" "$PY_PID_FILE"; pkill -P $$ 2>/dev/null || true' INT TERM

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
    RECORD_LOG="$RUNTIME_DIR/dictate_record.log"
    nohup pw-record --channels=1 --rate=16000 --format=s16 "$AUDIO_FILE" >"$RECORD_LOG" 2>&1 &
    echo $! >"$REC_PID_FILE"
    sleep 0.3
    if ! kill -0 "$(cat "$REC_PID_FILE")" 2>/dev/null; then
        echo "error" >"$STATUS_FILE"
        pkill -RTMIN+8 waybar || true
        notify-send -u critical "Dictate" "Recording failed to start. Check $RECORD_LOG"
        exit 1
    fi
fi
