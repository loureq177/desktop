# shellcheck shell=bash
# ~/.local/share/pkgbuilds: packages built from their makers' releases instead of the AUR,
# this repo's and the machine layer's.

PKGBUILDS_DIR=${PKGBUILDS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/pkgbuilds}

pkgbuild_names() {
    local f
    for f in "$PKGBUILDS_DIR"/*/PKGBUILD; do
        f=${f%/PKGBUILD}
        printf '%s\n' "${f##*/}"
    done
}

# The newest version its maker released: the PKGBUILD's _latest.
pkgbuild_latest() {
    (cd "$PKGBUILDS_DIR/$1" && source ./PKGBUILD && _latest)
}

# "pkgver-pkgrel" that VERSION would be built as.
pkgbuild_full() {
    printf '%s-%s\n' "$2" "$(sed -n 's/^pkgrel=//p' "$PKGBUILDS_DIR/$1/PKGBUILD")"
}

# NAME [VERSION]: built in a copy and installed; another version than the PKGBUILD's
# takes its sources' sums at download.
pkgbuild_install() {
    local name=$1 version=${2:-} dir=${XDG_CACHE_HOME:-$HOME/.cache}/pkgbuilds/${1:?}
    rm -rf "$dir"
    mkdir -p "$dir"
    cp -rL "$PKGBUILDS_DIR/$name/." "$dir/" || return 1
    # Signed sources: the keys they are checked against.
    if [[ -d "$dir/keys/pgp" ]]; then
        gpg --quiet --import "$dir"/keys/pgp/*.asc 2>/dev/null || return 1
    fi
    if [[ -n "$version" ]] && ! grep -qx "pkgver=$version" "$dir/PKGBUILD"; then
        sed -i "s/^pkgver=.*/pkgver=$version/" "$dir/PKGBUILD"
        (cd "$dir" && updpkgsums) || return 1
    fi
    (cd "$dir" && makepkg -sric --noconfirm)
}
