#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]:-$0}")"

# The status lines the installed scripts print too.
source common/.local/lib/dotfiles/common.sh

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
# paru is not in the official repositories: build it once from the AUR.
bootstrap_paru() {
    command -v paru &>/dev/null && return 0
    _log_info "paru not found. Building it from the AUR..."
    local build
    sudo pacman -S --noconfirm --needed base-devel git || return 1
    build="$(mktemp -d)" || return 1
    if git clone --depth 1 https://aur.archlinux.org/paru.git "$build/paru" &&
        (cd "$build/paru" && makepkg -si --noconfirm); then
        rm -rf "$build"
        return 0
    fi
    rm -rf "$build"
    return 1
}
enable_user_unit() {
    systemctl --user enable --now "$1" 2>/dev/null || _log_warn "Failed to enable $1."
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
        if bootstrap_paru; then
            _log_info "Installing AUR packages via paru..."
            pkglist archlinux/aur.txt | xargs -r -d '\n' paru -S --noconfirm --needed
            _log_ok "AUR packages installed."
        else
            _log_warn "Could not build paru - skipping AUR packages."
            _log_warn "Install paru by hand and run this script again."
        fi
    fi

    restow_pkg common common
    # Real dir so stow links the file inside; systemd ignores a symlinked drop-in dir
    for dropin in archlinux/.config/systemd/user/*.service.d; do
        mkdir -p "$HOME/.config/systemd/user/${dropin##*/}"
    done
    restow_pkg "Arch Linux" archlinux

    _log_info "Configuring autologin on tty1..."
    # No display manager: getty@tty1 runs login for $USER, the login shell execs Hyprland
    # (.zprofile) and quickshell locks the session as soon as it starts.
    # Nothing may write to tty1 on the way: the first byte makes fbcon take the console
    # over, a ~0.7 s modeset of the laptop panel that login waits for (even with the lid
    # closed and Hyprland leaving the panel off). agetty always prints a newline, and
    # TTYReset/TTYVTDisallocate send escape sequences, so login runs directly and both
    # are off. With ~/.hushlogin, login and PAM print nothing either.
    autologin_conf=$(mktemp)
    cat >"$autologin_conf" <<EOF
[Service]
Type=simple
TTYReset=no
TTYVTDisallocate=no
ExecStart=
ExecStart=-/usr/bin/login -f $USER
EOF
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
    _install_etc_file "$autologin_conf" /etc/systemd/system/getty@tty1.service.d/autologin.conf 644
    rm -f "$autologin_conf"
    sudo systemctl unmask getty@tty1.service
    sudo systemctl enable getty@tty1.service || _log_warn "Failed to enable getty@tty1."

    # .zprofile is what turns the tty1 login into the Hyprland session.
    if [ -x /usr/bin/zsh ] && [ "$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)" != /usr/bin/zsh ]; then
        _log_info "Making zsh the login shell..."
        sudo chsh -s /usr/bin/zsh "$USER" || _log_warn "Failed to change the login shell to zsh."
    fi

    _log_info "Installing system configs (THP, zram, swap sysctls, lid inhibitor)..."
    # archlinux/etc mirrors /etc; stow skips it (.stowrc) and the files are copied.
    while IFS= read -r -d '' src; do
        dest="/${src#archlinux/}"
        sudo mkdir -p "$(dirname "$dest")"
        _install_etc_file "$src" "$dest" 644
    done < <(find archlinux/etc -type f -print0 | sort -z)
    # dbus-broker-launch reloads itself on config changes (inotify); the stock
    # pacman hook's extra SIGHUP races that reload and times out after 90s.
    sudo mkdir -p /etc/pacman.d/hooks
    sudo ln -sfn /dev/null /etc/pacman.d/hooks/dbus-reload.hook
    sudo systemd-tmpfiles --create /etc/tmpfiles.d/memory.conf || _log_warn "Failed to apply tmpfiles memory settings."
    sudo sysctl --quiet --load /etc/sysctl.d/99-zram.conf || _log_warn "Failed to apply zram sysctls."
    sudo systemctl daemon-reload 2>/dev/null || true
    sudo systemctl start systemd-zram-setup@zram0.service 2>/dev/null || _log_warn "zram starts on the next boot."
    sudo systemctl kill -s HUP systemd-logind 2>/dev/null || true

    if [ -x "$HOME/.local/bin/apply-ui" ]; then
        _log_info "Applying UI styles..."
        "$HOME/.local/bin/apply-ui" --no-reload || _log_warn "Failed to apply UI styles."
    fi

    if command -v firefox &>/dev/null && [ -x "$HOME/.local/bin/firefox-apply" ]; then
        _log_info "Applying Firefox defaults..."
        # A Firefox that has never run has no profile yet; the session applies
        # the defaults again on every login (hyprland.lua).
        "$HOME/.local/bin/firefox-apply" || _log_warn "No Firefox profile yet: the defaults go in at the first login after Firefox has run once."
    fi

    whisper_model="${XDG_DATA_HOME:-$HOME/.local/share}/whisper/ggml-base.bin"
    if [ ! -s "$whisper_model" ]; then
        _log_info "Downloading the speech model for dictation..."
        mkdir -p "$(dirname "$whisper_model")"
        if command -v curl &>/dev/null &&
            curl -fL --retry 2 -o "$whisper_model.part" https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin; then
            mv "$whisper_model.part" "$whisper_model"
            _log_ok "Speech model installed."
        else
            rm -f "$whisper_model.part"
            _log_warn "Could not download $whisper_model - dictation stays off until it is there."
        fi
    fi

    if command -v systemctl &>/dev/null; then
        systemctl --user daemon-reload 2>/dev/null || true
        # Every unit of this repo that can be enabled, and only those: other
        # units in ~/.config/systemd/user are somebody else's business.
        while IFS= read -r unit; do
            enable_user_unit "$(basename "$unit")"
        done < <(grep -l '^\[Install\]' archlinux/.config/systemd/user/*.{timer,service,socket} 2>/dev/null | sort)
        # Shipped by their packages, configured here; the session starts them.
        systemctl --user enable hypridle.service 2>/dev/null || _log_warn "Failed to enable hypridle.service."
        if command -v wayland-pipewire-idle-inhibit &>/dev/null; then
            systemctl --user enable wayland-pipewire-idle-inhibit.service 2>/dev/null ||
                _log_warn "Failed to enable wayland-pipewire-idle-inhibit.service."
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
