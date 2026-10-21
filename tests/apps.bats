#!/usr/bin/env bats
# firefox-apply, firefox-webapp

load helpers

setup() {
    sandbox_setup
    FF="$HOME/.config/mozilla/firefox"
    WEBAPPS="$HOME/.local/share/firefox-webapps"
    cp -r "$REPO/archlinux/.config/firefox-defaults" "$HOME/.config/firefox-defaults"
    stub firefox "echo \"firefox-env MOZ_APP_REMOTINGNAME=\$MOZ_APP_REMOTINGNAME\" >>'$CALLS'"
    stub notify-send
}

# --- firefox-apply -----------------------------------------------------------

# profiles_ini: reads the ini from stdin and creates the given profile dirs.
profiles_ini() {
    mkdir -p "$FF"
    cat >"$FF/profiles.ini"
    local dir
    for dir in "$@"; do mkdir -p "$dir"; done
}

assert_user_js_in() {
    assert_status 0
    cmp "$1/user.js" "$REPO/archlinux/.config/firefox-defaults/user.js"
    [[ "$(stat -c %a "$1/user.js")" == 600 ]]
}

@test "firefox-apply: fails clearly when Firefox has never been started" {
    sut "$BIN/firefox-apply"
    assert_status 1
    assert_output_like "profiles.ini not found"
}

@test "firefox-apply: installs user.js into the profile the installation uses" {
    profiles_ini "$FF/old.default" "$FF/abc.default-release" <<'EOF'
[Install4F96D1932A9F858E]
Default=abc.default-release
Locked=1

[Profile1]
Name=default
IsRelative=1
Path=old.default
Default=1

[Profile0]
Name=default-release
IsRelative=1
Path=abc.default-release

[General]
StartWithLastProfile=1
Version=2
EOF
    sut "$BIN/firefox-apply"
    assert_user_js_in "$FF/abc.default-release"
    [[ ! -e "$FF/old.default/user.js" ]]
}

@test "firefox-apply: without an install section uses the profile flagged Default=1" {
    profiles_ini "$FF/first" "$FF/second" <<'EOF'
[General]
StartWithLastProfile=1

[Profile0]
Name=first
IsRelative=1
Path=first

[Profile1]
Name=second
IsRelative=1
Path=second
Default=1
EOF
    sut "$BIN/firefox-apply"
    assert_user_js_in "$FF/second"
    [[ ! -e "$FF/first/user.js" ]]
}

@test "firefox-apply: with no default at all uses the first profile" {
    profiles_ini "$FF/first" "$FF/second" <<'EOF'
[Profile0]
Name=first
IsRelative=1
Path=first

[Profile1]
Name=second
IsRelative=1
Path=second
EOF
    sut "$BIN/firefox-apply"
    assert_user_js_in "$FF/first"
}

@test "firefox-apply: honours an absolute profile path" {
    profiles_ini "$SANDBOX/elsewhere/profile" <<EOF
[Profile0]
Name=custom
IsRelative=0
Path=$SANDBOX/elsewhere/profile
Default=1
EOF
    sut "$BIN/firefox-apply"
    assert_user_js_in "$SANDBOX/elsewhere/profile"
}

@test "firefox-apply: fails when the profile dir or any profile is missing" {
    profiles_ini <<'EOF'
[Profile0]
Name=gone
IsRelative=1
Path=gone.default
EOF
    sut "$BIN/firefox-apply"
    assert_status 1
    assert_output_like "profile dir not found"

    profiles_ini <<'EOF'
[General]
Version=2
EOF
    sut "$BIN/firefox-apply"
    assert_status 1
    assert_output_like "no profile found"
}

# --- firefox-webapp ----------------------------------------------------------

zoom_rows() {
    sqlite3 "$WEBAPPS/content-prefs.sqlite" \
        "SELECT COALESCE(g.name, '*'), p.value FROM prefs p LEFT JOIN groups g ON g.id = p.groupID
         JOIN settings s ON s.id = p.settingID WHERE s.name = 'browser.content.full-zoom' ORDER BY 1"
}

@test "firefox-webapp: needs a name and a url" {
    sut "$BIN/firefox-webapp"
    assert_status 1
    assert_output_like "Usage: firefox-webapp"
    sut "$BIN/firefox-webapp" gemini
    assert_status 1
    refute_call_like "firefox"
}

@test "firefox-webapp: opens the url in the chromeless webapps profile" {
    sut "$BIN/firefox-webapp" gemini https://gemini.google.com
    assert_status 0
    assert_call "firefox --profile $WEBAPPS --class=webapps --name=gemini --new-window https://gemini.google.com"
    assert_call "firefox-env MOZ_APP_REMOTINGNAME=webapps"
    grep -q '#TabsToolbar' "$WEBAPPS/chrome/userChrome.css"
    grep -qF 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' "$WEBAPPS/user.js"
}

@test "firefox-webapp: passes extra arguments on to firefox" {
    sut "$BIN/firefox-webapp" mail https://mail.google.com --private-window "two words"
    assert_status 0
    assert_call "firefox --profile $WEBAPPS --class=webapps --name=mail --new-window https://mail.google.com --private-window two words"
}

@test "firefox-webapp: sets 110% zoom globally and per site, once" {
    need sqlite3
    sut "$BIN/firefox-webapp" gemini https://gemini.google.com
    sut "$BIN/firefox-webapp" gemini https://gemini.google.com/app?x=1
    sut "$BIN/firefox-webapp" dev http://localhost:8080/path
    assert_status 0
    [[ "$(zoom_rows)" == $'*|1.1\ngemini.google.com|1.1\nlocalhost|1.1' ]] || fail "$(zoom_rows)"
}

@test "firefox-webapp: launches even without sqlite3" {
    rm -f "$SAFE/sqlite3"
    sut "$BIN/firefox-webapp" gemini https://gemini.google.com
    assert_status 0
    assert_call_like "firefox --profile"
}
