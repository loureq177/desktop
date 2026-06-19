#!/bin/bash

set -euo pipefail

DIR="$(dirname "$(realpath "$0")")"
VENV_PYTHON="$HOME/.files/.venv/bin/python"

if [ ! -f "$VENV_PYTHON" ]; then
    notify-send -a "Dictate" -u critical "Error" "Virtual environment not found"
    exit 1
fi
DAEMON_PID_FILE="/tmp/dictate_daemon.pid"

SITE_PACKAGES=$("$VENV_PYTHON" -c "import sysconfig; print(sysconfig.get_path('purelib'))")
export LD_LIBRARY_PATH="${SITE_PACKAGES}/nvidia/cublas/lib:${SITE_PACKAGES}/nvidia/cudnn/lib:${LD_LIBRARY_PATH:-}"

if [ -f "$DAEMON_PID_FILE" ]; then
    DAEMON_PID=$(cat "$DAEMON_PID_FILE")
    if kill -0 "$DAEMON_PID" 2>/dev/null; then
        kill -SIGUSR1 "$DAEMON_PID"
        exit 0
    fi
    rm -f "$DAEMON_PID_FILE"
fi

echo "[dictate] Starting daemon..." >&2
"$VENV_PYTHON" "$DIR/dictate_daemon.py" &

for i in $(seq 1 30); do
    if [ -f "$DAEMON_PID_FILE" ]; then
        DAEMON_PID=$(cat "$DAEMON_PID_FILE")
        if kill -0 "$DAEMON_PID" 2>/dev/null; then
            kill -SIGUSR1 "$DAEMON_PID"
            exit 0
        fi
    fi
    sleep 0.3
done

echo "[dictate] Daemon failed to start" >&2
exit 1
