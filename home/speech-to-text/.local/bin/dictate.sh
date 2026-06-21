#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
VENV_PYTHON="$SCRIPT_DIR/../../.venv/bin/python"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
AUDIO_FILE="$RUNTIME_DIR/dictate_recording.wav"
STATUS_FILE="$RUNTIME_DIR/dictate_status"

update_waybar() {
    echo "$1" >"$STATUS_FILE"
    pkill -RTMIN+8 waybar || true
}

if pgrep -f "pw-record.*$AUDIO_FILE" >/dev/null; then
    pkill -f "pw-record.*$AUDIO_FILE" || true
    pkill -SIGUSR1 -f "dictate_backend.py" || true
    update_waybar "idle"
    exit 0
fi

pkill -f "dictate_backend.py" || true
rm -f "$AUDIO_FILE"

export DICTATE_AUDIO_FILE="$AUDIO_FILE"
SITE_PACKAGES=$("$VENV_PYTHON" -c "import sysconfig; print(sysconfig.get_path('purelib'))")
export LD_LIBRARY_PATH="${SITE_PACKAGES}/nvidia/cublas/lib:${SITE_PACKAGES}/nvidia/cudnn/lib:${LD_LIBRARY_PATH:-}"

update_waybar "listening"

nohup pw-record --channels=1 --rate=16000 --format=s16 "$AUDIO_FILE" >/dev/null 2>&1 &
"$VENV_PYTHON" "$SCRIPT_DIR/dictate_backend.py" &
