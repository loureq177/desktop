#!/usr/bin/env bats
# install.sh, run end to end against a copy of the repo and an empty $HOME.
# sudo, pacman, flatpak, paru, brew and systemctl are stubs; stow is real.

load helpers

setup() {
    sandbox_setup
    [[ "$(id -u)" -ne 0 ]] || skip "install.sh refuses to run as root"
    need stow

    export HOME="$SANDBOX/fresh-home"
    mkdir -p "$HOME"
    COPY="$SANDBOX/repo"
    copy_repo "$COPY"
    ROOT="$SANDBOX/root" # where the sudo stub "installs" files

    # sudo: never runs anything. `cmp` reports a difference so /etc installs
    # are always attempted, `install` copies into $ROOT, and a trailing "-"
    # (pacman reading package names) saves stdin.
    stub sudo "
case \"\$1\" in
cmp) exit 1 ;;
install) mkdir -p '$ROOT'\"\$(dirname \"\${@: -1}\")\" && cp \"\${@: -2:1}\" '$ROOT'\"\${@: -1}\" ;;
esac
[[ \"\${@: -1}\" != - ]] || cat >>'$SANDBOX/pacman.stdin'
true"
    stub flatpak
    stub paru
    stub systemctl
    stub bat
    stub brew
    # The dictation model: "download" whatever -o names.
    stub curl 'while (($#)); do [[ "$1" == -o ]] && echo model >"$2"; shift; done'
    os Linux
}

os() { stub_quiet uname "echo $1"; }

install() { sut env USER=tester "$COPY/install.sh" "$@"; }

arch_only() { [[ -f /etc/arch-release ]] || skip "install.sh only installs on Arch Linux"; }

has_battery() { compgen -G "/sys/class/power_supply/BAT*" >/dev/null; }

# Package names of a list file, read the way a human would.
pkgs() {
    python3 - "$@" <<'EOF'
import sys
for path in sys.argv[1:]:
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#"):
            print(line)
EOF
}

@test "install --help: prints usage and does nothing" {
    install --help
    assert_status 0
    assert_output_like "[--no-upgrade]"
    [[ ! -s "$CALLS" && -z "$(ls -A "$HOME")" ]]
}

@test "install: rejects unknown arguments" {
    install --frobnicate
    assert_status 2
    assert_output_like "Unknown argument: --frobnicate"
    [[ ! -s "$CALLS" ]]
}

@test "install: refuses unsupported systems" {
    os FreeBSD
    install
    assert_status 1
    assert_output_like "Unsupported OS: FreeBSD"
    refute_call_like "sudo"
}

@test "install (Arch): completes on an empty home" {
    arch_only
    install --no-upgrade
    assert_status 0
    assert_output_like "Installation completed successfully."
    # The sudo stub makes every /etc file look changed; any other warning is real.
    run grep -F '⚠' <<<"$(grep -vF 'differs — backing up' <<<"$output")"
    [[ -z "$output" ]] || fail "$output"
    assert_call "bat cache --build"
}

@test "install (Arch): upgrades the system unless told not to" {
    arch_only
    install --no-upgrade
    refute_call_like "pacman -Syu"
    : >"$CALLS"
    install
    assert_status 0
    assert_call "sudo pacman -Syu --noconfirm"
}

@test "install (Arch): installs exactly the listed packages" {
    arch_only
    install --no-upgrade
    assert_status 0
    assert_call "sudo pacman -S --noconfirm --needed -"
    local lists=("$COPY/archlinux/packages.txt")
    if has_battery; then lists+=("$COPY/archlinux/packages-laptop.txt"); fi
    diff <(pkgs "${lists[@]}") "$SANDBOX/pacman.stdin" >&2
    # shellcheck disable=SC2046
    assert_call "flatpak install --user -y --or-update flathub $(pkgs "$COPY/archlinux/flatpak.txt" | tr '\n' ' ' | sed 's/ $//')"
    assert_call "paru -S --noconfirm --needed $(pkgs "$COPY/archlinux/aur.txt" | tr '\n' ' ' | sed 's/ $//')"
}

@test "install (Arch): package lists may have comments, blank lines and CRLF endings" {
    arch_only
    printf '# a comment\r\n\r\n   indented-pkg   \r\n\t# another\r\nlast-pkg' >"$COPY/archlinux/packages.txt"
    rm -f "$COPY/archlinux/packages-laptop.txt"
    install --no-upgrade
    assert_status 0
    [[ "$(<"$SANDBOX/pacman.stdin")" == $'indented-pkg\nlast-pkg' ]] || fail "$(cat -A "$SANDBOX/pacman.stdin")"
}

@test "install (Arch): builds paru from the AUR when it is missing" {
    arch_only
    rm "$STUBS/paru"
    # git is real elsewhere in this suite; here it must not reach the network.
    stub git 'mkdir -p "${@: -1}"'
    stub makepkg "printf '#!/bin/bash\nprintf \"%%s\\\\n\" \"paru \$*\" >>\"%s\"\n' '$CALLS' >'$STUBS/paru'; chmod +x '$STUBS/paru'"
    install --no-upgrade
    assert_status 0
    assert_call "sudo pacman -S --noconfirm --needed base-devel git"
    assert_call_like "git clone --depth 1 https://aur.archlinux.org/paru.git"
    assert_call "makepkg -si --noconfirm"
    assert_call_like "paru -S --noconfirm --needed"
}

@test "install (Arch): skips AUR packages with a warning when paru cannot be built" {
    arch_only
    rm "$STUBS/paru"
    stub git 'exit 1'
    install --no-upgrade
    assert_status 0
    assert_output_like "Could not build paru - skipping AUR packages."
    refute_call_like "paru -S"
}

@test "install (Arch): links the common and Arch configs into the home dir" {
    arch_only
    install --no-upgrade
    assert_status 0
    local f
    for f in .config/zsh/.zshrc .config/nvim/init.lua .config/hypr/hyprland.lua .config/quickshell/shell.qml \
        .config/systemd/user/sysclean.timer .local/lib/dotfiles/capture.sh; do
        [[ -f "$HOME/$f" ]] || fail "missing after install: ~/$f"
        [[ "$(realpath "$HOME/$f")" == "$COPY/"* ]] || fail "~/$f is not a link into the repo"
    done
    for f in "$COPY"/archlinux/.local/bin/*; do
        [[ -x "$HOME/.local/bin/${f##*/}" ]] || fail "not runnable after install: ~/.local/bin/${f##*/}"
    done
    # Not for the home dir: package lists, the macOS scripts.
    [[ ! -e "$HOME/packages.txt" && ! -e "$HOME/aur.txt" && ! -e "$HOME/README.md" ]]
    [[ "$(realpath "$HOME/.local/bin/sysupdate")" == "$COPY/archlinux/.local/bin/sysupdate" ]]
}

@test "install (Arch): zsh can find its config afterwards" {
    arch_only
    # ~/.zshenv sets ZDOTDIR and PATH; without it zsh never reads
    # ~/.config/zsh/.zshrc or .zprofile (which starts Hyprland on tty1).
    install --no-upgrade
    assert_status 0
    [[ -f "$HOME/.zshenv" ]] || fail "~/.zshenv was not linked"
    [[ "$(realpath "$HOME/.zshenv")" == "$COPY/common/.zshenv" ]]
    need zsh
    run env -i HOME="$HOME" PATH=/usr/bin:/bin zsh -c 'print -r -- "$ZDOTDIR"'
    [[ "$output" == "$HOME/.config/zsh" ]] || fail "ZDOTDIR is '$output'"
}

@test "install (Arch): the user-unit drop-in dirs are real directories" {
    arch_only
    # systemd ignores a drop-in directory that is itself a symlink.
    install --no-upgrade
    local unit dir
    for unit in app-com.mitchellh.ghostty xdg-desktop-portal-hyprland; do
        dir="$HOME/.config/systemd/user/$unit.service.d"
        [[ -d "$dir" && ! -L "$dir" ]] || fail "$dir is not a real directory"
        [[ -f "$dir/override.conf" ]] || fail "$dir/override.conf was not linked"
    done
}

@test "install (Arch): does not hand ~/.ssh over to the repo" {
    arch_only
    # If ~/.ssh became a link to common/.ssh, new keys, known_hosts and the
    # real ssh config would be created inside the dotfiles repo.
    install --no-upgrade
    assert_status 0
    [[ ! -L "$HOME/.ssh" ]] || fail "~/.ssh -> $(readlink "$HOME/.ssh")"
}

@test "install (Arch): generates the themed configs" {
    arch_only
    install --no-upgrade
    assert_status 0
    assert_output_like "Applying UI styles"
    assert_output_like "Generated: $HOME/.config/quickshell/ui.js"
    [[ -s "$HOME/.config/ui/ui.sh" && -s "$HOME/.config/hypr/ui.lua" ]]
}

@test "install (Arch): sets up tty1 autologin for the installing user" {
    arch_only
    install --no-upgrade
    local conf="$ROOT/etc/systemd/system/getty@tty1.service.d/autologin.conf"
    [[ -f "$conf" ]] || fail "$(calls)"
    grep -qx 'ExecStart=' "$conf"
    grep -qxF 'ExecStart=-/usr/bin/agetty --noreset --noclear --noissue --autologin tester - ${TERM}' "$conf"
    assert_call "sudo systemctl enable getty@tty1.service"
}

@test "install (Arch): installs keyd and memory tuning into /etc" {
    arch_only
    install --no-upgrade
    [[ -f "$ROOT/etc/keyd/default.conf" && -f "$ROOT/etc/sysctl.d/99-zram.conf" ]] || fail "$(calls)"
    [[ -f "$ROOT/etc/systemd/logind.conf.d/lid-inhibit.conf" ]] || fail "$(calls)"
    local f
    while IFS= read -r f; do
        cmp "$ROOT/${f#archlinux/}" "$COPY/$f" || fail "not installed: /${f#archlinux/}"
    done < <(cd "$COPY" && find archlinux/etc -type f)
    # /etc files are copied by root, never linked into the home dir.
    [[ ! -e "$HOME/etc" ]] || fail "stow linked ~/etc"
    assert_call "sudo systemctl enable --now keyd"
    assert_call "sudo sysctl --quiet --load /etc/sysctl.d/99-zram.conf"
}

@test "install (Arch): enables the units of this repo that can be enabled" {
    arch_only
    install --no-upgrade
    local unit
    for unit in "$COPY"/archlinux/.config/systemd/user/*.{timer,service}; do
        if grep -q '^\[Install\]' "$unit"; then
            assert_call "systemctl --user enable --now ${unit##*/}"
        else
            refute_call_like "enable --now ${unit##*/}"
        fi
    done
    assert_call "systemctl --user enable hypridle.service"
}

@test "install (Arch): leaves units that are not from this repo alone" {
    arch_only
    mkdir -p "$HOME/.config/systemd/user"
    printf '[Timer]\nOnCalendar=daily\n[Install]\nWantedBy=timers.target\n' >"$HOME/.config/systemd/user/somebody-elses.timer"
    install --no-upgrade
    assert_status 0
    refute_call_like "somebody-elses"
}

@test "install (Arch): makes zsh the login shell" {
    arch_only
    [[ -x /usr/bin/zsh ]] || skip "needs /usr/bin/zsh"
    stub_quiet getent "echo 'tester:x:1000:1000::/home/tester:/usr/bin/bash'"
    install --no-upgrade
    assert_call "sudo chsh -s /usr/bin/zsh tester"

    : >"$CALLS"
    stub_quiet getent "echo 'tester:x:1000:1000::/home/tester:/usr/bin/zsh'"
    install --no-upgrade
    refute_call_like "chsh"
}

@test "install (Arch): fetches the dictation model once" {
    arch_only
    install --no-upgrade
    assert_status 0
    assert_call_like "curl -fL --retry 2 -o $HOME/.local/share/whisper/ggml-base.bin.part https://"
    [[ -s "$HOME/.local/share/whisper/ggml-base.bin" ]] || fail "$(calls)"

    : >"$CALLS"
    install --no-upgrade
    refute_call_like "curl"
}

@test "install (Arch): can be run again" {
    arch_only
    install --no-upgrade
    assert_status 0
    install --no-upgrade
    assert_status 0
    assert_output_like "Installation completed successfully."
    [[ -f "$HOME/.config/zsh/.zshrc" ]]
}

@test "install (Arch): stops before linking when a real file is in the way" {
    arch_only
    echo "my own file" >"$HOME/.prettierrc.json"
    install --no-upgrade
    [[ "$status" -ne 0 ]] || fail "install succeeded over an existing file"
    assert_output_like "stow pre-flight failed for 'common'"
    [[ "$(<"$HOME/.prettierrc.json")" == "my own file" ]]
    [[ ! -e "$HOME/.config/zsh" && ! -e "$HOME/.config/hypr" ]]
    [[ "$output" != *"Installation completed successfully."* ]]
}

@test "install (macOS): installs the Brewfile and links the common and macOS configs" {
    os Darwin
    install
    assert_status 0
    assert_call "brew bundle --file=macos/Brewfile"
    refute_call_like "pacman"
    refute_call_like "sudo"
    [[ -f "$HOME/.config/zsh/.zshrc" ]]
    [[ "$(realpath "$HOME/.local/bin/sysupdate")" == "$COPY/macos/.local/bin/sysupdate" ]]
    [[ ! -e "$HOME/.config/hypr" && ! -e "$HOME/Brewfile" ]]
    assert_output_like "Installation completed successfully."
}

@test "install (macOS): fails when Homebrew cannot be installed" {
    os Darwin
    rm "$STUBS/brew"
    stub curl
    install
    assert_status 1
    assert_output_like "Homebrew installation failed"
    [[ ! -e "$HOME/.config/zsh" ]]
}
