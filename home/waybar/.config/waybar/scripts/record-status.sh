#!/usr/bin/env bash
set -euo pipefail

STATUS_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/recording_status"

if [ -f "$STATUS_FILE" ]; then
    echo '{"text": "●", "class": "recording", "tooltip": "Recording screen"}'
    exit 0
fi

echo '{"text": "", "class": "idle", "tooltip": "Not recording"}'
