# Sourced, not exported: arrays cannot be exported.
# shellcheck disable=SC2034
SLURP_ARGS=(-d -b "@bg_main@b0" -c "@accent_blue@" -s "@accent_blue@20" -w @border_size@ -B "#00000000")

# The colours the scripts draw with in a terminal (tasks.sh), as rrggbb.
UI_ACCENT_BLUE="@accent_blue:bare@"
UI_ACCENT_PURPLE="@accent_purple:bare@"
UI_ACCENT_GREEN="@accent_green:bare@"
UI_WARNING="@warning:bare@"
UI_CRITICAL="@critical:bare@"
UI_TEXT_DIM="@text_dim:bare@"
UI_TEXT_MUTED="@text_muted:bare@"
