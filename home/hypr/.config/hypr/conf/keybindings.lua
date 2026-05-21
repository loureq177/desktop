---------------------
---- KEYBINDINGS ----
---------------------

local programs = require("conf.programs")

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(programs.terminal))
hl.bind(
	mainMod .. " + B",
	hl.dsp.exec_cmd(
		"hyprctl clients | grep -iq 'class:.*zen' && hyprctl dispatch focuswindow 'class:.*zen.*' || "
			.. programs.browser
	)
)
hl.bind(
	mainMod .. " + C",
	hl.dsp.exec_cmd(
		"hyprctl clients | grep -iq 'class:.*discord' && hyprctl dispatch focuswindow 'class:.*discord.*' || "
			.. programs.discord
	)
)
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd(programs.btop))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(programs.fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu -p 'Clipboard' | cliphist decode | wl-copy"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd(programs.launcher))
hl.bind(mainMod .. " + SHIFT + space", hl.dsp.exec_cmd(programs.runner))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(
	mainMod .. " + S",
	hl.dsp.exec_cmd("hyprctl clients | grep -q 'class: scratchpad' || ghostty --class=scratchpad &")
)
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("hyprctl dispatch togglespecialworkspace"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.layout("togglesplit")) -- dwindle only

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
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("hyprctl dispatch cyclenext"))
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("hyprctl dispatch bringactivetotop"))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshots
hl.bind(
	"Print",
	hl.dsp.exec_cmd("grimblast --freeze copysave area ~/Pictures/Screenshots/$(date +'%Y-%m-%d_%H-%M-%S').png")
)
hl.bind(
	"SHIFT + Print",
	hl.dsp.exec_cmd("grimblast copysave output ~/Pictures/Screenshots/$(date +'%Y-%m-%d_%H-%M-%S').png")
)
hl.bind(mainMod .. " + Period", hl.dsp.exec_cmd("rofi -show emoji -modi emoji"))

-- Volume and brightness (swayosd)
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("swayosd-client --output-volume raise"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("swayosd-client --output-volume lower"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd("swayosd-client --brightness raise"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd("swayosd-client --brightness lower"),
	{ locked = true, repeating = true }
)

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Clamshell mode (wyłączanie ekranu laptopa przy zamknięciu klapy)
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("hyprctl keyword monitor 'eDP-2, disable'"), { locked = true })
hl.bind(
	"switch:off:Lid Switch",
	hl.dsp.exec_cmd("hyprctl keyword monitor 'eDP-2, 1920x1080@165, 0x0, 1'"),
	{ locked = true }
)
