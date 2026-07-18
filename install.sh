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
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        _log_error "Do not run this script as root/sudo directly. It will run pacman via sudo when needed, but AUR helpers (paru) must run as a normal user."
        exit 1
    fi

    if [ ! -f /etc/arch-release ]; then
        _log_error "This script currently only supports Arch Linux distributions."
        exit 1
    fi

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

    install_packages
    install_flatpaks
    install_aur_packages

    STOW_ARCH_PKGS=(bin electron git hypr paru swaync rofi systemd waybar wireplumber)
    STOW_IGNORE="$STOW_IGNORE_BASE --ignore=\.venv"
    (cd archlinux && stow --verbose --restow --target ~ $STOW_IGNORE "${STOW_ARCH_PKGS[@]}")

    if [ -f "archlinux/ly/.config/ly/config.ini" ]; then
        _log_info "Configuring Ly display manager..."
        sudo mkdir -p /etc/ly
        sudo ln -sfv "$(pwd)/archlinux/ly/.config/ly/config.ini" /etc/ly/config.ini
    fi

    if command -v systemctl &>/dev/null; then
        echo "Enabling user services..."
        systemctl --user daemon-reload 2>/dev/null || true
    fi

fi

if [ "$OS" = "Darwin" ]; then
    _log_info "Detected macOS. Applying macOS configs..."
    source macos/deps_brew.sh
    source macos/deps_brew_casks.sh
    brew install "${PACKAGES[@]}"
    brew install --cask "${CASKS[@]}"
    # if [ -d "macos" ]; then
    #     (cd macos && stow --verbose --restow --target ~ */)
    # fi
fi

echo "Applying common configs..."
STOW_COMMON_PKGS=(btop ghostty mimeapps nvim opencode prettier stylua xdg yazi zsh)
STOW_IGNORE="$STOW_IGNORE_BASE"
(cd common && stow --verbose --restow --target ~ $STOW_IGNORE "${STOW_COMMON_PKGS[@]}")

echo "Done."
