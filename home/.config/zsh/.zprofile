# tty1 is the graphical seat: getty logs in there on its own (see install.sh)
# and the login shell turns into the Hyprland session.
if [[ -z "${WAYLAND_DISPLAY:-}" && "${XDG_VTNR:-}" == 1 ]] && (( $+commands[start-hyprland] )); then
    exec start-hyprland >"$XDG_STATE_HOME/hyprland-session.log" 2>&1
fi
