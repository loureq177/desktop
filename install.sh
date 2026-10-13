#!/usr/bin/env bash

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

_log() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}
_log_info() { _log "${BLUE}\n[INFO]" "$@"; }
_log_ok() { _log "${GREEN}[OK]" "$@"; }
_log_warn() { _log "${YELLOW}[WARN]" "$@"; }
_log_error() { _log "${RED}[ERROR]" "$@"; }

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]:-$0}")"

NO_UPGRADE=0
for arg in "$@"; do
    case "$arg" in
    --no-upgrade) NO_UPGRADE=1 ;;
    -h | --help)
        echo "Usage: $0 [--no-upgrade]"
        exit 0
        ;;
    *)
        _log_error "Unknown argument: $arg (see --help)"
        exit 2
        ;;
    esac
done

if ! command -v git &>/dev/null; then
    _log_error "'git' is not installed."
    exit 1
fi

mkdir -p ~/.config ~/.local/share ~/.local/state ~/.local/bin ~/.cache
# Real dir, or stow links all of ~/.ssh into the repo and keys end up there
[ -e ~/.ssh ] || mkdir -m 700 ~/.ssh

OS="$(uname -s)"
pkglist() { sed 's/\r$//' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -vE '^(#|$)' || true; }
pac_install() {
    local pkgs
    pkgs="$(pkglist "$1")"
    [[ -n "$pkgs" ]] || return 0
    printf '%s\n' "$pkgs" | sudo pacman -S --noconfirm --needed -
}
restow_pkg() {
    _log_info "Applying $1 Stow configs..."
    local err
    if ! err="$(stow --simulate --restow --target ~ "$2" 2>&1)"; then
        _log_error "stow pre-flight failed for '$2' (existing files in the way):"
        printf '%s\n' "$err" >&2
        _log_error "Move them aside or back them up, then re-run."
        return 1
    fi
    stow --verbose --restow --target ~ "$2"
}
_install_etc_file() {
    local src="$1" dest="$2" mode="$3" bk
    if [ -L "$dest" ]; then
        sudo rm -f "$dest"
    elif [ -e "$dest" ]; then
        sudo cmp -s "$src" "$dest" && return 0
        bk="${dest}.dotfiles-bak-$(date +%Y%m%d%H%M%S)"
        _log_warn "$dest differs — backing up to $bk"
        sudo cp -a "$dest" "$bk"
    fi
    sudo install -o root -g root -m "$mode" "$src" "$dest"
    _log_ok "Installed $dest"
}

if [ "$OS" = "Linux" ]; then
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        _log_error "Do not run this script as root/sudo directly. It will run pacman via sudo when needed."
        exit 1
    fi

    if [ ! -f /etc/arch-release ]; then
        _log_error "This script currently only supports Arch Linux distributions."
        exit 1
    fi

    _log_info "Detected Arch Linux. Updating system and installing official packages..."
    if [ "$NO_UPGRADE" -eq 1 ]; then
        _log_info "Skipping full system upgrade (--no-upgrade)."
    else
        sudo pacman -Syu --noconfirm
    fi
    pac_install archlinux/packages.txt
    _log_ok "Pacman packages installed."

    if compgen -G "/sys/class/power_supply/BAT*" >/dev/null 2>&1; then
        if [ -f archlinux/packages-laptop.txt ]; then
            _log_info "Detected laptop hardware (battery found). Installing laptop packages..."
            pac_install archlinux/packages-laptop.txt
            _log_ok "Laptop packages installed."
        fi
    fi

    if command -v flatpak &>/dev/null && [ -f archlinux/flatpak.txt ]; then
        _log_info "Configuring Flatpak and installing applications..."
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        pkglist archlinux/flatpak.txt | xargs -r -d '\n' flatpak install --user -y --or-update flathub
        _log_ok "Flatpaks installed."
    fi

    if [ -f archlinux/aur.txt ] && [ -s archlinux/aur.txt ] && pkglist archlinux/aur.txt | grep -q .; then
        if command -v paru &>/dev/null; then
            _log_info "Installing AUR packages via paru..."
            pkglist archlinux/aur.txt | xargs -r -d '\n' paru -S --noconfirm --needed
            _log_ok "AUR packages installed."
        else
            _log_warn "paru not found - skipping AUR packages"
            _log_warn "Install paru first."
        fi
    fi

    restow_pkg common common
    # Real dir so stow links the file inside; systemd ignores a symlinked drop-in dir
    mkdir -p "$HOME/.config/systemd/user/app-com.mitchellh.ghostty.service.d"
    restow_pkg "Arch Linux" archlinux

    _log_info "Configuring autologin on tty1..."
    # No display manager: getty logs $USER in, the login shell execs Hyprland (.zprofile)
    # and quickshell locks the session as soon as it starts.
    gpu_wait=""
    if [ -x /usr/local/bin/wait-for-gpus ]; then
        gpu_wait="ExecStartPre=-/usr/local/bin/wait-for-gpus"
    fi
    autologin_conf=$(mktemp)
    cat >"$autologin_conf" <<EOF
[Service]
Type=simple
$gpu_wait
ExecStart=
ExecStart=-/usr/bin/agetty --noreset --noclear --noissue --autologin $USER - \${TERM}
EOF
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
    _install_etc_file "$autologin_conf" /etc/systemd/system/getty@tty1.service.d/autologin.conf 644
    rm -f "$autologin_conf"
    sudo systemctl unmask getty@tty1.service
    sudo systemctl enable getty@tty1.service || _log_warn "Failed to enable getty@tty1."

    _log_info "Installing system configs (keyd, THP, zram, swap sysctls)..."
    # archlinux/etc mirrors /etc; stow skips it (.stowrc) and the files are copied.
    while IFS= read -r -d '' src; do
        dest="/${src#archlinux/}"
        sudo mkdir -p "$(dirname "$dest")"
        _install_etc_file "$src" "$dest" 644
    done < <(find archlinux/etc -type f -print0 | sort -z)
    sudo systemctl enable --now keyd 2>/dev/null || _log_warn "Failed to enable keyd."
    sudo keyd reload 2>/dev/null || true
    sudo systemd-tmpfiles --create /etc/tmpfiles.d/memory.conf || _log_warn "Failed to apply tmpfiles memory settings."
    sudo sysctl --quiet --load /etc/sysctl.d/99-zram.conf || _log_warn "Failed to apply zram sysctls."

    if [ -x "$HOME/.local/bin/apply-ui" ]; then
        _log_info "Applying UI styles..."
        "$HOME/.local/bin/apply-ui" --no-reload || _log_warn "Failed to apply UI styles."
    fi

    if command -v firefox &>/dev/null && [ -x "$HOME/.local/bin/firefox-apply" ]; then
        _log_info "Applying Firefox defaults..."
        "$HOME/.local/bin/firefox-apply" || _log_warn "Failed to apply Firefox defaults."
    fi

    if command -v systemctl &>/dev/null; then
        systemctl --user daemon-reload 2>/dev/null || true
        for timer in "$HOME"/.config/systemd/user/*.timer; do
            [ -e "$timer" ] || continue
            name="$(basename "$timer")"
            systemctl --user enable --now "$name" 2>/dev/null || _log_warn "Failed to enable $name."
        done
        systemctl --user enable --now "volume-listener.service" 2>/dev/null || _log_warn "Failed to enable volume-listener.service."
        # Wayland clears the clipboard when the source app exits; keep it alive.
        # Service has WantedBy=hyprland-session.target so it also starts on next login.
        systemctl --user enable --now "wl-clip-persist.service" 2>/dev/null || _log_warn "Failed to enable wl-clip-persist.service."
        if compgen -G "/sys/class/power_supply/BAT*" >/dev/null 2>&1; then
            systemctl --user enable --now "power-save-watcher.service" 2>/dev/null || _log_warn "Failed to enable power-save-watcher.service."
        fi
    fi
elif [ "$OS" = "Darwin" ]; then
    _log_info "Detected macOS."
    if ! command -v brew &>/dev/null; then
        _log_info "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [ -x /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi

    if command -v brew &>/dev/null; then
        _log_info "Installing dependencies from Brewfile..."
        brew bundle --file=macos/Brewfile
    else
        _log_error "Homebrew installation failed or 'brew' is not in PATH."
        exit 1
    fi

    if ! command -v stow &>/dev/null; then
        _log_info "Installing stow via Homebrew..."
        brew install stow
    fi

    restow_pkg common common
    restow_pkg macOS macos
else
    _log_error "Unsupported OS: $OS (only Linux/Arch and Darwin/macOS are supported)."
    exit 1
fi

if command -v bat &>/dev/null; then
    _log_info "Building bat cache..."
    bat cache --build || _log_warn "bat cache build failed."
fi

_log_ok "Installation completed successfully."
