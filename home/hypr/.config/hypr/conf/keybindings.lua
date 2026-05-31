---------------------
---- KEYBINDINGS ----
---------------------

local programs = require("conf.programs")

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(programs.terminal))

hl.bind(mainMod .. " + D", hl.dsp.workspace.toggle_special("discord"))
hl.bind(mainMod .. " + X", hl.dsp.workspace.toggle_special("spotify"))

hl.bind(mainMod .. " + B", function()
	local zenWindows = hl.get_windows({ class = "zen" })

	if #zenWindows > 0 then
		hl.dispatch(hl.dsp.focus({ window = "address:" .. zenWindows[1].address }))
	else
		hl.dispatch(hl.dsp.exec_cmd(programs.browser))
	end
end)
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd(programs.btop))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(programs.fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(
	mainMod .. " + SHIFT + V",
	hl.dsp.exec_cmd("cliphist list | rofi -dmenu -p 'Clipboard' | cliphist decode | wl-copy")
)
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd(programs.launcher))
hl.bind(mainMod .. " + SHIFT + space", hl.dsp.exec_cmd(programs.runner))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("focus"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:focus" }))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("rofi -show window"))
hl.bind(mainMod .. " + T", hl.dsp.layout("togglesplit"))

-- Move focus with mainMod + hjkl
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

-- Swap windows with mainMod + SHIFT + hjkl
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.swap({ direction = "down" }))

-- Cycle windows (Alt-Tab style)
hl.bind(mainMod .. " + Tab", function()
	hl.dispatch(hl.dsp.window.cycle_next())
	hl.dispatch(hl.dsp.window.bring_to_top())
end)

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for index_number = 1, 10 do
	local key_mapped = index_number % 10
	hl.bind(mainMod .. " + " .. key_mapped, hl.dsp.focus({ workspace = index_number }))
	hl.bind(mainMod .. " + SHIFT + " .. key_mapped, hl.dsp.window.move({ workspace = index_number }))
end

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshots
hl.bind("Print", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh region"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh full"))
hl.bind(mainMod .. " + Period", hl.dsp.exec_cmd("rofi -show emoji -modi emoji"))

-- Color picker
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a --notify"))

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
