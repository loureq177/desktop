#!/usr/bin/env bash
# The questions, then install/system.sh as root and install/user.sh as you.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]:-$0}")"

# The status lines the installed scripts print too.
source home/.local/lib/dotfiles/common.sh

NO_UPGRADE=0
PICK=0
DEFAULTS=0
DOTFILES=1
for arg in "$@"; do
    case "$arg" in
    --no-upgrade) NO_UPGRADE=1 ;;
    --pick) PICK=1 ;;
    --defaults) DEFAULTS=1 ;;
    --no-dotfiles) DOTFILES=0 ;;
    -h | --help)
        echo "Usage: $0 [--no-upgrade] [--pick | --defaults] [--no-dotfiles]"
        echo "  --pick         ask for the browser and the apps again"
        echo "  --defaults     the standard ones, without asking"
        echo "  --no-dotfiles  leave out .files (zsh, Ghostty, nvim and the terminal tools)"
        exit 0
        ;;
    *)
        _log_error "Unknown argument: $arg (see --help)"
        exit 2
        ;;
    esac
done

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    _log_error "Do not run this script as root/sudo directly. It will run pacman via sudo when needed."
    exit 1
fi
if [ ! -f /etc/arch-release ]; then
    _log_error "This desktop is for Arch Linux only."
    exit 1
fi

# What is about to happen, and the only moment to say no; with nobody to ask, it just runs.
show_plan() {
    local dim="$_C_DIM" nc="$_C_NC"
    _log_info "This installs the desktop on this machine"
    printf '\n  Needed for it to work:\n'
    printf '    · a system upgrade, then Hyprland, Quickshell and their packages\n'
    printf '    · home/ linked into ~, its services enabled\n'
    printf '    · /etc: the session and autologin on tty1, zram, sysctl hardening, lock screen PAM\n'
    printf '\n%s  Up to you:\n' "$dim"
    printf '    · browser and special workspaces: asked next, unless already answered\n'
    printf '    · .files: zsh, Ghostty, nvim and the terminal tools (--no-dotfiles leaves it out)\n'
    printf '    · the speech model for dictation, about 150 MB, if the download works\n%s' "$nc"
    printf '\n  Enter starts, Ctrl+C stops.'
    read -r _
}
needs_pick() { [ "$PICK" -eq 1 ] || [ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/apps/apps.toml" ]; }

if [ -t 0 ] && [ "$DEFAULTS" -eq 0 ]; then
    show_plan
fi

# The password once, first, as sysupdate and sysclean ask it; kept alive through the
# questions and the long builds, which would otherwise stop and ask again.
if [ -t 0 ]; then
    sudo -v
fi
(while kill -0 "$$" 2>/dev/null; do
    sudo -n true 2>/dev/null
    sleep 60
done) &
sudo_keepalive=$!
trap 'kill "$sudo_keepalive" 2>/dev/null' EXIT

# Asked once, the answers kept in ~/.config/apps/apps.toml; with no terminal to
# ask in, the standard set. apply-apps is Python, which a bare Arch may not have yet.
if needs_pick; then
    command -v python3 &>/dev/null || sudo pacman -S --noconfirm --needed python
    if [ "$DEFAULTS" -eq 0 ] && [ -t 0 ]; then
        home/.local/bin/apply-apps --pick --no-reload
    else
        home/.local/bin/apply-apps --defaults --no-reload
    fi
fi

system=(--user "$USER")
[ "$NO_UPGRADE" -eq 0 ] || system+=(--no-upgrade)
mapfile -t picked < <(home/.local/bin/apply-apps --packages | awk '$1 == "pacman" { print $2 }')
# Root's own config has no theme: the status lines keep yours.
sudo env XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" install/system.sh "${system[@]}" "${picked[@]}"

user=()
[ "$DOTFILES" -eq 1 ] || user+=(--no-dotfiles)
install/user.sh "${user[@]}"

_log_ok "Desktop installed. Reboot, or log in on tty1."
