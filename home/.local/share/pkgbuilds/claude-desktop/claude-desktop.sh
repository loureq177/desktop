#!/bin/bash
# Electron stays on X11 unless told: Wayland in a Wayland session.
[[ -n ${WAYLAND_DISPLAY:-} ]] && set -- --ozone-platform=wayland "$@"
exec /usr/lib/claude-desktop/claude-desktop "$@"
