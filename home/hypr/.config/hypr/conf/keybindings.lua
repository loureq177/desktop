local programs = require("conf.programs")

local mod = "SUPER"

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd(programs.terminal))
hl.bind(mod .. " + space", hl.dsp.exec_cmd(programs.launcher))
hl.bind(mod .. " + SHIFT + space", hl.dsp.exec_cmd(programs.runner))

hl.bind(mod .. " + SHIFT + S", hl.dsp.workspace.toggle_special("scratchpad"))

hl.bind(mod .. " + C", hl.dsp.workspace.toggle_special(programs.special.calendar.ws))
hl.bind(mod .. " + T", hl.dsp.workspace.toggle_special(programs.special.tasks.ws))
hl.bind(mod .. " + W", hl.dsp.workspace.toggle_special(programs.special.whatsapp.ws))
hl.bind(mod .. " + M", hl.dsp.workspace.toggle_special(programs.special.mail.ws))
hl.bind(mod .. " + D", hl.dsp.workspace.toggle_special(programs.special.discord.ws))
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special(programs.special.spotify.ws))
hl.bind(mod .. " + E", hl.dsp.workspace.toggle_special(programs.special.yazi.ws))

hl.bind(mod .. " + Escape", function()
	local special_ws = hl.get_active_special_workspace()
	if special_ws then
		hl.dispatch(hl.dsp.workspace.toggle_special(special_ws.name:match("^special:(.+)$") or special_ws.name))
	end
end)

hl.bind(mod .. " + B", function()
	local zenWindows = hl.get_windows({ class = programs.browser.class })

	if #zenWindows > 0 then
		hl.dispatch(hl.dsp.focus({ window = "address:" .. zenWindows[1].address }))
	else
		hl.dispatch(hl.dsp.exec_cmd(programs.browser.exe))
	end
end)

hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + Escape", hl.dsp.exec_cmd("~/.config/hypr/scripts/powermenu.sh"))
hl.bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd("hyprlock --immediate-render --no-fade-in"))
hl.bind(mod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("~/.config/hypr/scripts/cliphist-paste.sh"))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + SHIFT + T", hl.dsp.layout("togglesplit"))

-- Move focus with mainMod + hjkl
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "down" }))

-- Swap windows with mainMod + SHIFT + hjkl
hl.bind(mod .. " + SHIFT + H", hl.dsp.window.swap({ direction = "left" }))
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mod .. " + SHIFT + K", hl.dsp.window.swap({ direction = "up" }))
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.swap({ direction = "down" }))

-- Cycle windows
hl.bind(mod .. " + Tab", function()
	hl.dispatch(hl.dsp.window.cycle_next())
	hl.dispatch(hl.dsp.window.bring_to_top())
end)

-- Switch workspaces with mainMod + [1-6]
-- Move active window to a workspace with mainMod + SHIFT + [1-6]
for index_number = 1, 6 do
	local key_mapped = index_number % 10
	hl.bind(mod .. " + " .. key_mapped, hl.dsp.focus({ workspace = index_number }))
	hl.bind(mod .. " + SHIFT + " .. key_mapped, hl.dsp.window.move({ workspace = index_number }))
end

-- Move windows with mainMod + LMB/RMB and dragging
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })

-- Screenshots
hl.bind("Print", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh region"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh full"))
hl.bind(mod .. " + Period", hl.dsp.exec_cmd("rofi -show emoji -modi emoji"))
hl.bind(mod .. " + SHIFT + slash", hl.dsp.exec_cmd("~/.config/hypr/scripts/keybinds.sh"))

-- Color picker
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a --notify"))

-- System controls (SUPER + CTRL)
hl.bind(mod .. " + CTRL + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/dnd-toggle.sh"))
hl.bind(mod .. " + CTRL + C", hl.dsp.exec_cmd("~/.config/hypr/scripts/caffeine-toggle.sh"))
hl.bind(mod .. " + CTRL + T", hl.dsp.exec_cmd("~/.config/hypr/scripts/theme-toggle.sh"))
hl.bind(mod .. " + CTRL + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/record.sh"))
hl.bind(mod .. " + CTRL + B", hl.dsp.workspace.toggle_special("bluetui"))
hl.bind(mod .. " + CTRL + N", hl.dsp.workspace.toggle_special("impala"))
hl.bind(mod .. " + CTRL + S", hl.dsp.exec_cmd("~/.local/bin/dictate.sh"))
hl.bind(mod .. " + CTRL + Escape", hl.dsp.workspace.toggle_special("btop"))

-- Volume and brightness
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd(
		"wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+ && pw-play /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga"
	),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd(
		"wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && pw-play /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga"
	),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- For multi-monitor management
hl.bind(
	"switch:on:Lid Switch",
	hl.dsp.exec_cmd([=[hyprctl eval 'hl.monitor({output = "desc:BOE 0x0998", disabled = true})']=]),
	{ locked = true }
)
hl.bind(
	"switch:off:Lid Switch",
	hl.dsp.exec_cmd([=[hyprctl eval 'hl.monitor({output = "desc:BOE 0x0998", disabled = false})']=]),
	{ locked = true }
)
