#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")"

if ! command -v stow &>/dev/null; then
    echo "Error: GNU Stow is not installed."
    exit 1
fi

mkdir -p ~/.config ~/.local/share ~/.local/state ~/.local/bin ~/.cache

OS="$(uname -s)"

if [ "$OS" = "Linux" ]; then
    echo "Detected Linux. Applying Archlinux configs..."
    if [ -d "archlinux/bin/.local/bin" ]; then
        chmod +x archlinux/bin/.local/bin/* 2>/dev/null || true
    fi
    if [ -d "archlinux/waybar/.config/waybar/scripts" ]; then
        chmod +x archlinux/waybar/.config/waybar/scripts/* 2>/dev/null || true
    fi
    if [ -d "archlinux/hypr/.config/hypr/scripts" ]; then
        chmod +x archlinux/hypr/.config/hypr/scripts/* 2>/dev/null || true
    fi
    if [ -d "archlinux/speech-to-text/.local/bin" ]; then
        chmod +x archlinux/speech-to-text/.local/bin/*.sh 2>/dev/null || true
    fi
    if [ -d "archlinux/webapps/.local/bin" ]; then
        chmod +x archlinux/webapps/.local/bin/* 2>/dev/null || true
    fi

    SPEECH_DIR="archlinux/speech-to-text"
    if [ -d "$SPEECH_DIR" ]; then
        echo "Setting up Python venv for speech-to-text..."
        if [ ! -d "$SPEECH_DIR/.venv" ]; then
            python3 -m venv "$SPEECH_DIR/.venv"
        fi
        "$SPEECH_DIR/.venv/bin/pip" install --quiet --upgrade \
            faster-whisper \
            nvidia-cublas-cu12 \
            nvidia-cudnn-cu12
    fi

    ARCH_PKGS=(bin electron hypr ly paru swaync webapps rofi speech-to-text systemd waybar wireplumber)
    STOW_IGNORE='--ignore=\.venv --ignore=node_modules --ignore=__pycache__ --ignore=\.pyc$ --ignore=\.zwc$'
    (cd archlinux && stow --verbose --restow --target ~ $STOW_IGNORE "${ARCH_PKGS[@]}")
fi

if [ "$OS" = "Darwin" ]; then
    echo "Detected macOS. Applying macOS configs..."
    if [ -d "macos/bin/.local/bin" ]; then
        chmod +x macos/bin/.local/bin/* 2>/dev/null || true
    fi
    if [ -d "macos" ]; then
        (cd macos && stow --verbose --restow --target ~ */)
    fi
fi

echo "Applying common configs..."
COMMON_PKGS=(bat btop ghostty git mimeapps nvim opencode ssh xdg yazi zsh)
STOW_IGNORE='--ignore=node_modules --ignore=__pycache__ --ignore=\.pyc$ --ignore=\.zwc$'
(cd common && stow --verbose --restow --target ~ $STOW_IGNORE "${COMMON_PKGS[@]}")

if command -v bat &>/dev/null; then
    echo "Building bat cache for custom themes..."
    bat cache --build 2>&1 || echo "Warning: bat cache rebuild failed"
fi

if command -v systemctl &>/dev/null; then
    echo "Enabling user services..."
    systemctl --user daemon-reload 2>/dev/null || true
fi

echo "Done."
