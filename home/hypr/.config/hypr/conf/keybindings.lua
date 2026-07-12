local programs = require("conf.programs")

-- --- Apps -------------------------------------------------------------------
local cmds = {
	["SUPER + RETURN"] = programs.terminal,
	["SUPER + B"] = programs.browser,
	["SUPER + space"] = programs.launcher,
	["SUPER + Escape"] = "~/.config/hypr/scripts/powermenu.sh",
	["SUPER + Period"] = "rofi -show emoji -modi emoji -emoji-mode copy",

	["SUPER + CTRL + Q"] = "hyprlock --immediate-render --no-fade-in",
	["SUPER + CTRL + A"] = "swaync-client -t",
	["SUPER + CTRL + R"] = "~/.config/hypr/scripts/record-screen.sh",
	["SUPER + CTRL + M"] = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && pkill -RTMIN+8 waybar",
	["SUPER + CTRL + P"] = "hyprpicker -a --notify",
	["SUPER + CTRL + space"] = "rofi -show run -replace",

	["Print"] = "~/.config/hypr/scripts/screenshot.sh region",
	["SHIFT + Print"] = "~/.config/hypr/scripts/screenshot.sh fullscreen",
}

for bind, cmd in pairs(cmds) do
	hl.bind(bind, hl.dsp.exec_cmd(cmd))
end

-- --- Special workspace apps -------------------------------------------------
local special_apps = {
	["SUPER + C"] = "calendar",
	["SUPER + T"] = "tasks",
	["SUPER + W"] = "whatsapp",
	["SUPER + M"] = "mail",
	["SUPER + D"] = "discord",
	["SUPER + S"] = "spotify",
	["SUPER + A"] = "gemini",
	["SUPER + E"] = "yazi",
	["SUPER + CTRL + C"] = "clipboard",
	["SUPER + CTRL + B"] = "bluetui",
	["SUPER + CTRL + I"] = "impala",
	["SUPER + CTRL + Escape"] = "btop",
}

for bind, app in pairs(special_apps) do
	hl.bind(bind, hl.dsp.workspace.toggle_special(programs.special[app].ws))
end

hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + P", hl.dsp.window.pseudo())
hl.bind("SUPER + SHIFT + T", hl.dsp.layout("togglesplit"))

-- Move focus and swap windows ------------------------------------------------
local directions = { H = "left", L = "right", K = "up", J = "down" }

for key, dir in pairs(directions) do
	hl.bind("SUPER + " .. key, hl.dsp.focus({ direction = dir }))
	hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }))
end

-- Switch workspaces / Move active window to a workspace ----------------------
for i = 1, 9 do
	hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }))
	hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Move windows with mouse ----------------------------------------------------
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("mouse:274", hl.dsp.window.drag(), { mouse = true })

-- System controls ------------------------------------------------------------
hl.bind("SUPER + CTRL + S", hl.dsp.exec_cmd("~/.local/bin/dictate.sh start"))
hl.bind("SUPER + CTRL + S", hl.dsp.exec_cmd("~/.local/bin/dictate.sh stop"), { release = true })

-- Audio and brightness ------------------------------------------------------
local volume = "/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga"
local vol_base = "wpctl set-volume "

local media = {
	XF86AudioRaiseVolume = {
		vol_base .. "-l 1.5 @DEFAULT_AUDIO_SINK@ 2%+ && pw-play " .. volume,
		true,
	},
	XF86AudioLowerVolume = { vol_base .. "@DEFAULT_AUDIO_SINK@ 2%- && pw-play " .. volume, true },
	XF86AudioMute = { "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", false },
	XF86AudioMicMute = { "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", false },
	XF86MonBrightnessUp = { "brightnessctl set +10%", true },
	XF86MonBrightnessDown = { "brightnessctl set 10%-", true },
}

for key, conf in pairs(media) do
	hl.bind(key, hl.dsp.exec_cmd(conf[1]), { locked = true, repeating = conf[2] })
end
