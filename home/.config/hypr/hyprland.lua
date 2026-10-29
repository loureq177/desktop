-- Hyprland's config, one file a part (hyprland/); local.lua is the machine's.
-- Order matters: autostart before specials, binds after the rest, settings last.

require("hyprland.env")
require("hyprland.autostart")
require("hyprland.monitors")
require("hyprland.input")
require("hyprland.look")
require("hyprland.rules")
require("hyprland.specials")
require("hyprland.binds")
require("hyprland.settings")
