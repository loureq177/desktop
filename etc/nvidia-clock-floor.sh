#!/bin/sh
# Keeps NVIDIA above its lowest state while it drives an external screen: from there
# it takes longer to speed up than a short animation lasts, which drops its frames.
command -v nvidia-smi >/dev/null 2>&1 || exit 0
state=/run/nvidia-clock-floor
floor_gr=600

# The connectors settle after the event.
sleep 1

card=""
for connector in /sys/class/drm/card*-*; do
    name=${connector##*/}
    [ "$(cat "/sys/class/drm/${name%%-*}/device/vendor" 2>/dev/null)" = 0x10de ] || continue
    case ${name#*-} in eDP* | LVDS* | DSI*) continue ;; esac
    [ "$(cat "$connector/status" 2>/dev/null)" = connected ] && card=${name%%-*}
done

if [ -n "$card" ]; then
    # With nothing holding the GPU the driver forgets the floor: wait for the compositor.
    tries=0
    until fuser -s "/dev/dri/$card" 2>/dev/null || [ "$tries" -ge 300 ]; do
        tries=$((tries + 1))
        sleep 1
    done
    max_gr=$(nvidia-smi --query-gpu=clocks.max.gr --format=csv,noheader,nounits)
    nvidia-smi -lgc "$floor_gr,$max_gr" >/dev/null
    touch "$state"
elif [ -e "$state" ]; then
    # Only after a floor of ours: nvidia-smi wakes a GPU that sleeps.
    nvidia-smi -rgc >/dev/null
    rm -f "$state"
fi
