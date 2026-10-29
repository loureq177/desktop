-- Hyprland's config, one file a part (hyprland/). What belongs to one machine
-- is in local.lua (local.lua.example), and the look the shell and the apps
-- share in ui.lua (apply-ui).
--
-- The order matters where two parts act at the same moment: the lock and the
-- session start (autostart) come before the hidden web apps (specials) when
-- Hyprland starts, and the binds come last, in the order the launcher lists
-- them.

require("hyprland.env")
require("hyprland.autostart")
require("hyprland.monitors")
require("hyprland.input")
require("hyprland.look")
require("hyprland.rules")
require("hyprland.specials")
require("hyprland.binds")
