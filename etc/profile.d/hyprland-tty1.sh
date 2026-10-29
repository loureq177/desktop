# tty1 is the graphical seat: getty logs in there on its own (see install.sh) and
# the login turns into the Hyprland session, whichever the login shell is.
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "${XDG_VTNR:-}" = 1 ] && command -v start-hyprland >/dev/null 2>&1; then
    exec start-hyprland >"${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-session.log" 2>&1
fi
