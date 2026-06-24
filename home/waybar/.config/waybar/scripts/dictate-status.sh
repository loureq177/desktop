#!/usr/bin/env bash
set -euo pipefail

ACTIVE=false
APPS=""

if command -v pactl &>/dev/null; then
    APPS=$(pactl list source-outputs 2>/dev/null | awk -F'"' '/application\.name/ {print $2}' | sort -u | paste -s -d, - || true)
    if [ -n "$APPS" ]; then
        ACTIVE=true
    fi
fi

MUTED=false
if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; then
    MUTED=true
fi

if [ "$MUTED" = true ]; then
    ICON="󰍭"
else
    ICON="󰍬"
fi

if [ "$ACTIVE" = true ]; then
    CLASS="active"
    TOOLTIP="Microphone in use by: $APPS"
else
    CLASS="idle"
    TOOLTIP="Microphone: $([ "$MUTED" = true ] && echo 'muted' || echo 'unmuted')"
fi

echo "{\"text\": \"$ICON\", \"class\": \"$CLASS\", \"tooltip\": \"$TOOLTIP\"}"
