#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/battery-low-notify"
STATE_FILE="$STATE_DIR/notified"
THRESHOLDS=(20 10 5)

mkdir -p "$STATE_DIR"
printf '%s\n' "${THRESHOLDS[@]}" >"$STATE_FILE"

notify_if_needed() {
    local capacity=$1 status=$2
    if [[ "$status" != "discharging" ]]; then
        printf '%s\n' "${THRESHOLDS[@]}" >"$STATE_FILE"
        return
    fi
    mapfile -t remaining <"$STATE_FILE"
    local new=()
    for t in "${remaining[@]}"; do
        if ((capacity <= t)); then
            case "$t" in
            20) urgency="normal" icon="battery-low" ;;
            *) urgency="critical" icon="battery-caution" ;;
            esac
            notify-send --app-name "Battery" -u "$urgency" -i "$icon" -t 10000 "Battery Low" \
                "Battery at ${capacity}% — plug in the charger."
        else
            new+=("$t")
        fi
    done
    if ((${#new[@]})); then
        printf '%s\n' "${new[@]}" >"$STATE_FILE"
    else
        : >"$STATE_FILE"
    fi
}

state=""
pct=""
upower --monitor-detail | while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*state:[[:space:]]*(.+) ]]; then
        state="${BASH_REMATCH[1]}"
        if [[ "$state" == "charging" || "$state" == "fully-charged" ]]; then
            printf '%s\n' "${THRESHOLDS[@]}" >"$STATE_FILE"
        fi
    elif [[ "$line" =~ ^[[:space:]]*percentage:[[:space:]]*([0-9]+)% ]]; then
        pct="${BASH_REMATCH[1]}"
        [[ -n "$state" ]] && notify_if_needed "$pct" "$state"
    fi
done
