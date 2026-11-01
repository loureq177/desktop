# tty1 is the graphical seat: getty logs in there on its own (see install.sh) and
# the login turns into the Hyprland session, whichever the login shell is.
# zz-: exec ends the login here, so it goes after the rest of profile.d (locale.sh sets LANG).
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "${XDG_VTNR:-}" = 1 ] && command -v start-hyprland >/dev/null 2>&1; then
    # Hyprland leaving shows this VT again: empty, with no cursor.
    printf '\033[?25l\033[2J\033[H'
    exec start-hyprland >"${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-session.log" 2>&1
fi
