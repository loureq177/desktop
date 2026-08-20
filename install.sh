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
STOW_IGNORE=(--ignore=node_modules --ignore=__pycache__ '--ignore=\.pyc$' '--ignore=\.zwc$')

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
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm --needed - <archlinux/packages.txt
    _log_ok "Pacman packages installed."

    if command -v flatpak &>/dev/null && [ -f archlinux/flatpak.txt ]; then
        _log_info "Configuring Flatpak and installing applications..."
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        xargs -r flatpak install --user -y --or-update flathub <archlinux/flatpak.txt
        _log_ok "Flatpaks installed."
    fi

    if command -v paru &>/dev/null && [ -f archlinux/aur.txt ]; then
        _log_info "Installing AUR packages via paru..."
        xargs -r paru -S --noconfirm --needed <archlinux/aur.txt
        _log_ok "AUR packages installed."
    fi

    _log_info "Applying Arch Linux Stow configs..."
    stow --verbose --restow --target ~ "${STOW_IGNORE[@]}" archlinux

    if [ -f "archlinux/.config/ly/config.ini" ]; then
        _log_info "Configuring Ly display manager..."
        sudo mkdir -p /etc/ly
        sudo ln -sfv "$(pwd)/archlinux/.config/ly/config.ini" /etc/ly/config.ini
    fi

    if command -v systemctl &>/dev/null; then
        systemctl --user daemon-reload 2>/dev/null || true
    fi
elif [ "$OS" = "Darwin" ]; then
    _log_info "Detected macOS. Installing dependencies from Brewfile..."
    if command -v brew &>/dev/null; then
        brew bundle --file=macos/Brewfile
    else
        _log_warn "Homebrew is not installed. Please install Homebrew first."
    fi

    _log_info "Applying macOS Stow configs..."
    stow --verbose --restow --target ~ "${STOW_IGNORE[@]}" macos
fi

_log_info "Applying common Stow configs..."
stow --verbose --restow --target ~ "${STOW_IGNORE[@]}" common

_log_info "Installing opencode plugin dependencies..."
if [ -f "$HOME/.config/opencode/package.json" ] && command -v npm &>/dev/null; then
    (cd "$HOME/.config/opencode" && npm install --no-audit --no-fund) || _log_warn "opencode dependencies install failed."
fi

_log_info "Ensuring script files have executable permissions..."
find archlinux/.local/bin macos/.local/bin -type f -exec chmod +x {} + 2>/dev/null || true
find archlinux/.config -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true

_log_ok "Installation completed successfully."
