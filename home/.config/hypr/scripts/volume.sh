#!/usr/bin/env bash
# Volume control via swayosd with GNOME-like sound feedback.
# Usage: volume.sh output raise|lower|mute-toggle|mute|unmute
#        volume.sh input mute-toggle|mute|unmute
set -euo pipefail

TARGET="${1:-output}"
ACTION="${2:-}"
if [[ -z "$ACTION" ]]; then
    echo "Usage: volume.sh output raise|lower|mute-toggle|mute|unmute" >&2
    echo "       volume.sh input mute-toggle|mute|unmute" >&2
    exit 2
fi

PLAY_SOUND_BIN="${PLAY_SOUND:-$HOME/.local/bin/play-sound}"
sound() {
    if [[ -x "$PLAY_SOUND_BIN" ]]; then
        "$PLAY_SOUND_BIN" "$@" 2>/dev/null || true
    elif command -v play-sound >/dev/null 2>&1; then
        play-sound "$@" 2>/dev/null || true
    fi
}

VOLUME_EVENT="audio-volume-change"

case "$TARGET" in
output)
    swayosd-client --output-volume "$ACTION" || exit 0
    # Muted speakers cannot play feedback; silence is the confirmation.
    if [[ "$ACTION" == mute* ]] && wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q '\[MUTED\]'; then
        exit 0
    fi
    sound --replace "$VOLUME_EVENT"
    ;;
input)
    swayosd-client --input-volume "$ACTION" || exit 0
    sound --replace "$VOLUME_EVENT"
    ;;
*)
    echo "volume.sh: unknown target '$TARGET' (want output|input)" >&2
    exit 2
    ;;
esac
