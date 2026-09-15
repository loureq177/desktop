#!/usr/bin/env bash
# Volume control via wpctl with the quickshell OSD. GNOME-like sound feedback.
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

sound() {
    # --replace is accepted for backward compat but ignored: libcanberra mixes natively.
    [[ "${1:-}" == "--replace" ]] && shift
    canberra-gtk-play -i "$1" >/dev/null 2>&1 || true
}

_report() { # $1: SINK|SOURCE — push the current state to the OSD
    local line frac pct
    line="$(wpctl get-volume "@DEFAULT_${1}@" 2>/dev/null || true)"
    # wpctl prints a fraction ("Volume: 0.65"); the OSD wants percent.
    frac="${line#*: }"
    frac="${frac%% *}"
    # Round, do not truncate: printf "%d" on a binary float drops a percent
    # (0.29 * 100 is 28.999...), so the OSD lagged one step behind wpctl.
    pct="$(awk -v f="$frac" 'BEGIN { printf "%d", int(f * 100 + 0.5) }' || true)"
    [[ -z "$pct" ]] && pct=0
    if grep -q 'MUTED' <<<"$line"; then
        qs ipc call osd volume "$pct" true
    else
        qs ipc call osd volume "$pct" false
    fi
}

case "$TARGET" in
output)
    case "$ACTION" in
    raise) wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+ ;;
    lower) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
    mute-toggle) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 ;;
    unmute) wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 ;;
    *) echo "volume.sh: unknown action '$ACTION'" >&2; exit 2 ;;
    esac
    _report SINK
    # Muted speakers cannot play feedback; silence is the confirmation.
    if [[ "$ACTION" == mute* ]] && wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q '\[MUTED\]'; then
        exit 0
    fi
    sound --replace audio-volume-change
    ;;
input)
    case "$ACTION" in
    mute-toggle) wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
    mute) wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1 ;;
    unmute) wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0 ;;
    *) echo "volume.sh: unknown action '$ACTION'" >&2; exit 2 ;;
    esac
    if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q '\[MUTED\]'; then
        qs ipc call osd mic true
    else
        qs ipc call osd mic false
    fi
    sound --replace audio-volume-change
    ;;
*)
    echo "volume.sh: unknown target '$TARGET' (want output|input)" >&2
    exit 2
    ;;
esac
