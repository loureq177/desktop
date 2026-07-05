#!/usr/bin/env bash

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

_log_info() { echo -e "${BLUE}\n[INFO]${NC} $*"; }
_log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
_log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
_log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

set -euo pipefail
cd "$(dirname "$0")"

mkdir -p ~/.config ~/.local/share ~/.local/state ~/.local/bin ~/.cache

OS="$(uname -s)"
STOW_IGNORE_BASE='--ignore=node_modules --ignore=__pycache__ --ignore=\.pyc$ --ignore=\.zwc$'

if [ "$OS" = "Linux" ]; then
    _log_info "Detected Linux. Applying Archlinux configs..."
    source archlinux/deps_paru.sh

    check_sudo() {
        if ! command -v sudo &>/dev/null; then
            _log_error "sudo is not installed."
            exit 1
        fi
        sudo -n &>/dev/null || sudo -v
    }
    check_sudo

    install_packages() {
        _log_info "Updating pacman databases..."
        sudo pacman -Sy
        _log_info "Installing packages via pacman..."
        for label in "${PKG_GROUPS[@]}"; do
            [ "$label" = "AUR" ] && continue
            declare -n arr="${label}_PKGS"
            _log_info "Installing [$label]_PKGS..."
            sudo pacman -S --noconfirm --needed "${arr[@]}"
            _log_ok "[$label] done."
        done
    }

    install_flatpaks() {
        source archlinux/deps_flatpak.sh
        if ! command -v flatpak &>/dev/null; then
            _log_warn "flatpak not found, skipping Flatpak apps"
            return
        fi
        _log_info "Configuring Flatpak and installing applications for user..."
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        flatpak install --user -y --or-update flathub "${FLATPAK_APPS[@]}"
        _log_ok "Flatpaks installed for $USER."
    }

    install_aur_packages() {
        if ! command -v paru &>/dev/null; then
            _log_warn "paru not found, skipping AUR packages"
            return
        fi
        declare -n arr="AUR_PKGS"
        _log_info "Installing [AUR]_PKGS..."
        paru -S --noconfirm --needed "${arr[@]}"
        _log_ok "AUR packages done."
    }

    if [ -d "archlinux/bin/.local/bin" ]; then
        chmod +x archlinux/bin/.local/bin/* 2>/dev/null || true
    fi
    if [ -d "archlinux/waybar/.config/waybar/scripts" ]; then
        chmod +x archlinux/waybar/.config/waybar/scripts/* 2>/dev/null || true
    fi
    if [ -d "archlinux/hypr/.config/hypr/scripts" ]; then
        chmod +x archlinux/hypr/.config/hypr/scripts/* 2>/dev/null || true
    fi
    if [ -d "archlinux/webapps/.local/bin" ]; then
        chmod +x archlinux/webapps/.local/bin/* 2>/dev/null || true
    fi

    install_packages
    install_flatpaks
    install_aur_packages

    STOW_ARCH_PKGS=(bin electron hypr ly paru swaync webapps rofi systemd waybar wireplumber)
    STOW_IGNORE="$STOW_IGNORE_BASE --ignore=\.venv"
    (cd archlinux && stow --verbose --restow --target ~ $STOW_IGNORE "${STOW_ARCH_PKGS[@]}")

fi

if [ "$OS" = "Darwin" ]; then
    _log_info "Detected macOS. Applying macOS configs..."
    if [ -d "macos/bin/.local/bin" ]; then
        chmod +x macos/bin/.local/bin/* 2>/dev/null || true
    fi
    if [ -d "macos" ]; then
        (cd macos && stow --verbose --restow --target ~ */)
    fi
fi

echo "Applying common configs..."
STOW_COMMON_PKGS=(bat btop ghostty git mimeapps nvim opencode xdg yazi zsh)
STOW_IGNORE="$STOW_IGNORE_BASE"
(cd common && stow --verbose --restow --target ~ $STOW_IGNORE "${STOW_COMMON_PKGS[@]}")

if command -v bat &>/dev/null; then
    echo "Building bat cache for custom themes..."
    bat cache --build 2>&1 || echo "Warning: bat cache rebuild failed"
fi

if command -v systemctl &>/dev/null; then
    echo "Enabling user services..."
    systemctl --user daemon-reload 2>/dev/null || true
fi

echo "Done."
