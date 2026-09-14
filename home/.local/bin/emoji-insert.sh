#!/bin/sh
# Insert an emoji into the focused app via clipboard + Shift+Insert.
# Mirrors omarchy-menu-emoji-insert: wl-copy runs in the background so the
# paste source survives until wtype pastes, then it is killed.
set -eu
emoji="${1:-}"
[ -n "$emoji" ] || exit 0
printf '%s' "$emoji" | wl-copy --type text/plain --sensitive --foreground &
copy_pid=$!
sleep 0.15
wtype -M shift -k Insert -m shift 2>/dev/null || true
sleep 0.2
kill "$copy_pid" 2>/dev/null || true
