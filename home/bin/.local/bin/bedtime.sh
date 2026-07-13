#!/usr/bin/env bash
set -euo pipefail

day_end=$((21 * 60 + 45))
night_start=$((22 * 60))
night_end=$((2 * 60))

notify_bed() {
    notify-send \
        --app-name "Bedtime" \
        -t 0 "Bedtime" \
        -i "weather-clear-night" \
        "$1"
}

# Initial check: if we are in the daytime window, ensure wifi is on and exit
current_time=$((10#$(date +%H) * 60 + 10#$(date +%M)))
if [ "$current_time" -lt "$day_end" ] && [ "$current_time" -ge "$night_end" ]; then
    nmcli radio wifi on
    exit 0
fi

# Initial check: if we are already past night start or before night end, turn wifi off immediately
if [ "$current_time" -ge "$night_start" ] || [ "$current_time" -lt "$night_end" ]; then
    notify_bed "WiFi has been turned off."
    nmcli radio wifi off
    exit 0
fi

# Countdown loop for the 15-minute transition period (21:45 to 22:00)
notify_15_sent=false
notify_5_sent=false

while true; do
    current_time=$((10#$(date +%H) * 60 + 10#$(date +%M)))
    
    # Check if we transitioned out of the countdown period
    if [ "$current_time" -ge "$night_start" ] || [ "$current_time" -lt "$night_end" ]; then
        notify_bed "WiFi has been turned off."
        nmcli radio wifi off
        exit 0
    fi
    
    remaining_min=$(( night_start - current_time ))
    
    if [ "$remaining_min" -le 15 ] && [ "$remaining_min" -gt 5 ] && [ "$notify_15_sent" = false ]; then
        notify_bed "WiFi will turn off in $remaining_min minutes."
        notify_15_sent=true
    fi
    
    if [ "$remaining_min" -le 5 ] && [ "$remaining_min" -gt 0 ] && [ "$notify_5_sent" = false ]; then
        notify_bed "WiFi will turn off in $remaining_min minutes."
        notify_5_sent=true
    fi
    
    sleep 30
done
