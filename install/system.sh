#!/usr/bin/env bash
# The system's part, as root: packages, /etc, autologin on tty1. It also runs in a chroot
# (an ISO's installer): what needs the running system waits for its next boot there.
#
#   install/system.sh --user NAME [--no-upgrade] [PACKAGE...]
#
# NAME logs in on tty1; PACKAGE... are the chosen apps' (apply-apps --packages).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

source home/.local/lib/dotfiles/common.sh

user=""
upgrade=1
extra=()
while (($#)); do
    case "$1" in
    --user)
        user=${2:?--user needs a name}
        shift
        ;;
    --no-upgrade) upgrade=0 ;;
    -*)
        _log_error "Unknown argument: $1"
        exit 2
        ;;
    *) extra+=("$1") ;;
    esac
    shift
done

if [ "$(id -u)" -ne 0 ]; then
    _log_error "install/system.sh runs as root: sudo install/system.sh --user NAME"
    exit 1
fi
if [ -z "$user" ] || ! id "$user" &>/dev/null; then
    _log_error "--user names the account that logs in on tty1."
    exit 2
fi

# Booted, not in a chroot (arch-chroot binds the host's /run): what changes the running
# system is done now too.
booted() { [ -d /run/systemd/system ] && ! systemd-detect-virt --quiet --chroot; }

pac_install() {
    (($#)) || return 0
    pacman -S --noconfirm --needed "$@"
}

install_etc_file() {
    local src="$1" dest="$2" bk
    if [ -L "$dest" ]; then
        rm -f "$dest"
    elif [ -e "$dest" ]; then
        cmp -s "$src" "$dest" && return 0
        bk="${dest}.dotfiles-bak-$(date +%Y%m%d%H%M%S)"
        _log_warn "$dest differs — backing up to $bk"
        cp -a "$dest" "$bk"
    fi
    mkdir -p "$(dirname "$dest")"
    install -o root -g root -m 644 "$src" "$dest"
    _log_ok "Installed $dest"
}

_log_info "Updating the system and installing official packages..."
if [ "$upgrade" -eq 1 ]; then
    pacman -Syu --noconfirm
else
    _log_info "Skipping full system upgrade (--no-upgrade)."
fi
mapfile -t pkgs < <(pkglist packages.txt)
pac_install "${pkgs[@]}"
_log_ok "Pacman packages installed."

pac_install "${extra[@]}"

if compgen -G "/sys/class/power_supply/BAT*" >/dev/null 2>&1; then
    _log_info "Detected laptop hardware (battery found). Installing laptop packages..."
    mapfile -t pkgs < <(pkglist packages-laptop.txt)
    pac_install "${pkgs[@]}"
    _log_ok "Laptop packages installed."
fi

_log_info "Configuring autologin on tty1..."
# No display manager: getty autologins the user, /etc/profile.d execs Hyprland, hyprlock locks.
# Nothing may write to tty1 (fbcon would take it, a ~0.7 s modeset), so login runs directly.
autologin_conf=$(mktemp)
cat >"$autologin_conf" <<EOF
[Service]
Type=simple
TTYReset=no
TTYVTDisallocate=no
ExecStart=
ExecStart=-/usr/bin/login -f $user
EOF
install_etc_file "$autologin_conf" /etc/systemd/system/getty@tty1.service.d/autologin.conf
rm -f "$autologin_conf"
systemctl unmask getty@tty1.service
systemctl enable getty@tty1.service || _log_warn "Failed to enable getty@tty1."

_log_info "Installing system configs (the session on tty1, zram, swap and hardening sysctls, zswap off, lock screen PAM, journal and coredump limits)..."
# etc/ mirrors /etc; the files are copied, not linked.
while IFS= read -r -d '' src; do
    install_etc_file "$src" "/$src"
done < <(find etc -type f -print0 | sort -z)
# Its old name: it would still start the session before locale.sh.
rm -f /etc/profile.d/hyprland-tty1.sh
# dbus-broker-launch reloads itself on config changes (inotify); the stock
# pacman hook's extra SIGHUP races that reload and times out after 90s.
mkdir -p /etc/pacman.d/hooks
ln -sfn /dev/null /etc/pacman.d/hooks/dbus-reload.hook
if booted; then
    systemd-tmpfiles --create /etc/tmpfiles.d/memory.conf || _log_warn "Failed to turn zswap off."
    sysctl --quiet --load /etc/sysctl.d/99-zram.conf || _log_warn "Failed to apply zram sysctls."
    # journald reads its limits only at start.
    systemctl restart systemd-journald || _log_warn "Failed to restart journald."
    systemctl daemon-reload 2>/dev/null || true
fi
systemctl enable suspend-settle.service || _log_warn "Failed to enable suspend-settle."
systemctl enable reflector.timer || _log_warn "Failed to enable reflector.timer."
# Certificates of the networks that sign in with a username (wifi-join): iwd reads no home.
install -d -m 755 /var/lib/wifi-certs
install -d -o "$user" -g "$(id -gn "$user")" -m 755 "/var/lib/wifi-certs/$user"
if booted; then
    udevadm control --reload-rules 2>/dev/null || true
    systemctl start systemd-zram-setup@zram0.service 2>/dev/null || _log_warn "zram starts on the next boot."
fi
