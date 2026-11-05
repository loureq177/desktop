#!/usr/bin/env bash
# The user's part, after install/system.sh: flatpaks, the packages built here, .files,
# home/ linked into ~, the theme, the speech model and the session's units.
#
#   install/user.sh [--no-dotfiles]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

source home/.local/lib/dotfiles/common.sh
PKGBUILDS_DIR=$PWD/home/.local/share/pkgbuilds
source home/.local/lib/dotfiles/pkgbuilds.sh

DOTFILES=1
case "${1:-}" in
"") ;;
--no-dotfiles) DOTFILES=0 ;;
*)
    _log_error "Unknown argument: $1"
    exit 2
    ;;
esac

if [ "$(id -u)" -eq 0 ]; then
    _log_error "install/user.sh runs as the user who logs in, not as root."
    exit 1
fi

# What the chosen browser and specials need from one source (pacman or flatpak).
picked() { home/.local/bin/apply-apps --packages | awk -v source="$1" '$1 == source { print $2 }'; }
enable_user_unit() {
    systemctl --user enable --now "$1" 2>/dev/null || _log_warn "Failed to enable $1."
}

if command -v flatpak &>/dev/null; then
    _log_info "Configuring Flatpak and installing applications..."
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    { pkglist flatpak.txt; picked flatpak; } | xargs -r -d '\n' flatpak install --user -y --or-update flathub
    _log_ok "Flatpaks installed."
fi

# home/.local/share/pkgbuilds: from their makers' releases, the newest one when it can be found.
_log_info "Building packages from their makers' releases..."
while IFS= read -r name; do
    pacman -Q "$name" &>/dev/null && continue
    pkgbuild_install "$name" "$(pkgbuild_latest "$name" 2>/dev/null || true)" || _log_warn "Could not build $name."
done < <(pkgbuild_names)

# Anthropic's installer: Claude Code in ~/.local/bin, updating itself.
if ! command -v claude &>/dev/null; then
    _log_info "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash || _log_warn "Could not install Claude Code."
fi

# The terminal side (zsh as the login shell, Ghostty, nvim and their packages) is
# .files'. The session starts without it (/etc/profile.d), so a failure only warns.
if [ "$DOTFILES" -eq 1 ]; then
    if [ ! -d ~/.files ]; then
        _log_info "Cloning .files (the terminal configs)..."
        git clone https://github.com/loureq177/.files.git ~/.files || _log_warn "Could not clone .files."
    fi
    if [ -f ~/.files/install.sh ]; then
        _log_info "Installing .files..."
        bash ~/.files/install.sh || _log_warn ".files did not install: the terminal keeps its defaults."
    fi
fi

_log_info "Linking home/ into ~..."
mkdir -p ~/.config ~/.local/share ~/.local/state ~/.local/bin ~/.cache
# The night light's slider writes its temperature here: a file of this machine, not a link
# into the repo (an older install's link keeps its value).
sunset=~/.config/hypr/hyprsunset.conf
if [ -L "$sunset" ] || [ ! -e "$sunset" ]; then
    mkdir -p ~/.config/hypr
    if [ -e "$sunset" ]; then
        cp --remove-destination "$(readlink -f "$sunset")" "$sunset"
    else
        cp -f home/.config/hypr/hyprsunset.conf.example "$sunset"
    fi
fi
if ! err="$(stow --simulate --restow --target ~ home 2>&1)"; then
    _log_error "stow pre-flight failed (existing files in the way):"
    printf '%s\n' "$err" >&2
    _log_error "Move them aside or back them up, then re-run."
    exit 1
fi
stow --verbose --restow --target ~ home

_log_info "Rendering the browser and the apps..."
"$HOME/.local/bin/apply-apps" --no-reload || _log_warn "Failed to render ~/.config/apps/apps.toml."

_log_info "Applying UI styles..."
"$HOME/.local/bin/apply-ui" --no-reload || _log_warn "Failed to apply UI styles."

speech_model="${XDG_DATA_HOME:-$HOME/.local/share}/parakeet/ggml-parakeet-tdt-0.6b-v3-q8_0.bin"
if [ ! -s "$speech_model" ]; then
    _log_info "Downloading the speech model for dictation..."
    mkdir -p "$(dirname "$speech_model")"
    if curl -fL --retry 2 -o "$speech_model.part" https://huggingface.co/ggml-org/parakeet-GGUF/resolve/main/ggml-parakeet-tdt-0.6b-v3-q8_0.bin; then
        mv "$speech_model.part" "$speech_model"
        _log_ok "Speech model installed."
    else
        rm -f "$speech_model.part"
        _log_warn "Could not download $speech_model - dictation stays off until it is there."
    fi
fi

systemctl --user daemon-reload 2>/dev/null || true
# Every unit of this repo that can be enabled, and only those: other
# units in ~/.config/systemd/user are somebody else's business.
while IFS= read -r unit; do
    enable_user_unit "$(basename "$unit")"
done < <(grep -l '^\[Install\]' home/.config/systemd/user/*.{timer,service,socket} 2>/dev/null | sort)
# Shipped by their packages, configured here; the session starts them.
systemctl --user enable hypridle.service 2>/dev/null || _log_warn "Failed to enable hypridle.service."
systemctl --user enable app-com.mitchellh.ghostty.service 2>/dev/null || _log_warn "Failed to enable Ghostty's service."
# Balanced stays balanced on battery: quicker starts, for some 0.6 W.
powerprofilesctl configure-battery-aware --disable 2>/dev/null || true
systemctl --user enable hyprsunset.service 2>/dev/null || _log_warn "Failed to enable hyprsunset.service."
systemctl --user enable wayland-pipewire-idle-inhibit.service 2>/dev/null ||
    _log_warn "Failed to enable wayland-pipewire-idle-inhibit.service."
