#!/usr/bin/env bats
# battery-care

load helpers

setup() {
    sandbox_setup
    MARKER="$XDG_RUNTIME_DIR/battery_care"
    echo true >"$SANDBOX/supported"
    echo false >"$SANDBOX/enabled"
    stub upower "echo /org/freedesktop/UPower/devices/line_power_ADP1; echo /org/freedesktop/UPower/devices/battery_BAT0"
    # EnableChargeThreshold changes what ChargeThresholdEnabled reads back.
    stub busctl "
case \"\$*\" in
*' ChargeThresholdSupported') echo \"b \$(cat '$SANDBOX/supported')\" ;;
*' ChargeThresholdEnabled') echo \"b \$(cat '$SANDBOX/enabled')\" ;;
*' EnableChargeThreshold b '*) echo \"\${@: -1}\" >'$SANDBOX/enabled' ;;
esac"
}

@test "battery-care: turns the charge limit on when it is off" {
    sut "$HOME/.local/bin/battery-care"
    assert_status 0
    assert_call "busctl call --system org.freedesktop.UPower /org/freedesktop/UPower/devices/battery_BAT0 org.freedesktop.UPower.Device EnableChargeThreshold b true"
    [[ "$(<"$MARKER")" == on ]]
}

@test "battery-care: turns the charge limit off when it is on" {
    echo true >"$SANDBOX/enabled"
    sut "$HOME/.local/bin/battery-care"
    assert_status 0
    assert_call_like "EnableChargeThreshold b false"
    [[ "$(<"$MARKER")" == off ]]
}

@test "battery-care --sync: reports the state without changing it" {
    echo true >"$SANDBOX/enabled"
    sut "$HOME/.local/bin/battery-care" --sync
    assert_status 0
    refute_call_like "EnableChargeThreshold"
    [[ "$(<"$MARKER")" == on ]]
}

@test "battery-care: no marker and no change where the battery has no charge limit" {
    echo false >"$SANDBOX/supported"
    echo on >"$MARKER"
    sut "$HOME/.local/bin/battery-care" --sync
    assert_status 0
    [[ ! -e "$MARKER" ]]
    sut "$HOME/.local/bin/battery-care"
    assert_status 1
    refute_call_like "EnableChargeThreshold"
}
