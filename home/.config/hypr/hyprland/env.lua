-- Set for Hyprland and exported to the systemd user session at start, where
-- the shell and the other session services run (autostart.lua).

local ui = require("ui")
local machine = require("hyprland.machine")

local exported = { "WAYLAND_DISPLAY", "XDG_CURRENT_DESKTOP", "HYPRLAND_INSTANCE_SIGNATURE" }
local function env(name, value)
	hl.env(name, value)
	table.insert(exported, name)
end

machine.env(env)

env("GSK_RENDERER", "gl")
env("GTK_A11Y", "none")
env("XDG_SESSION_DESKTOP", "Hyprland")
env("GDK_WAYLAND_DISABLE", "ext_background_effect_manager_v1")
env("QS_ICON_THEME", ui.theme.icon)
for _, prefix in ipairs({ "XCURSOR", "HYPRCURSOR" }) do
	env(prefix .. "_THEME", ui.theme.cursor)
	env(prefix .. "_SIZE", tostring(ui.font.size_cursor))
end
env("SAL_USE_VCLPLUGIN", "gtk3")
-- NVDEC drops parts of keyframes in wf-recorder's screencasts (blocks of the
-- previous frame stay on screen until the next keyframe), so GStreamer players
-- decode H.264 with libav (gst-libav) instead.
env("GST_PLUGIN_FEATURE_RANK", "nvh264dec:NONE")

return { set = env, exported = exported }
