local specials = require("hyprland.specials")
local workspaces = require("hyprland.workspaces")

-- The launcher's keys list shows the binds in the order they are made here,
-- each under its section: the description reads "Windows: Close window".
-- Binds with the same description and modifiers share one line.
local function section(name)
	return function(keys, desc, action, opts)
		opts = opts or {}
		opts.description = name .. ": " .. desc
		if opts.repeating == nil then
			opts.repeating = false
		end
		hl.bind(keys, action, opts)
	end
end

local exec = hl.dsp.exec_cmd

-- A bind action that calls fn(arg).
local function calls(fn, arg)
	return function()
		fn(arg)
	end
end

do
	local bind = section("Essential")
	bind("SUPER + B", "Browser", exec("firefox"))
	bind("SUPER + RETURN", "Terminal", exec("ghostty"))
	bind("SUPER + space", "Launcher", exec("qs ipc call shell toggle launcher apps"))
end

do
	local bind = section("Windows")
	-- H J K L: the direction and a step that way. Left and right go on along
	-- the row of workspaces (workspaces.lua).
	local directions = {
		{ key = "H", dir = "left", x = -1, y = 0 },
		{ key = "J", dir = "down", x = 0, y = 1 },
		{ key = "K", dir = "up", x = 0, y = -1 },
		{ key = "L", dir = "right", x = 1, y = 0 },
	}
	for _, d in ipairs(directions) do
		bind(
			"SUPER + " .. d.key,
			"Focus window",
			d.x ~= 0 and calls(workspaces.focus, d.dir) or hl.dsp.focus({ direction = d.dir })
		)
	end
	for _, d in ipairs(directions) do
		bind(
			"SUPER + SHIFT + " .. d.key,
			"Move window",
			d.x ~= 0 and calls(workspaces.throw, d.dir) or hl.dsp.window.swap({ direction = d.dir })
		)
	end
	for _, d in ipairs(directions) do
		local resize = hl.dsp.window.resize({ x = d.x * 25, y = d.y * 25, relative = true })
		bind("SUPER + CTRL + " .. d.key, "Resize window", resize, { repeating = true })
	end
	bind("SUPER + TAB", "Focus previous window", hl.dsp.focus({ last = true }))
	for i = 1, 9 do
		bind("SUPER + " .. i, "Switch to workspace", calls(workspaces.focus_nth, i))
	end
	for i = 1, 9 do
		bind("SUPER + SHIFT + " .. i, "Move window to workspace", calls(workspaces.send_nth, i))
	end
	bind("SUPER + Q", "Close window", hl.dsp.window.close())
	bind("SUPER + F", "Toggle fullscreen", hl.dsp.window.fullscreen())
	bind("SUPER + T", "Toggle window split", hl.dsp.layout("togglesplit"))
	bind("SUPER + M", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))
end

do
	-- In the order of their keys.
	local bind = section("Special Workspaces")
	local keyed = {}
	for name, app in pairs(specials) do
		if app.key then
			table.insert(keyed, { name = name, app = app })
		end
	end
	table.sort(keyed, function(x, y)
		return x.app.key < y.app.key
	end)
	for _, sp in ipairs(keyed) do
		bind(
			"SUPER + SHIFT + " .. sp.app.key,
			sp.app.desc,
			hl.dsp.workspace.toggle_special(sp.name)
		)
	end
end

do
	local bind = section("System & Tools")
	bind("SUPER + A", "Actions", exec("qs ipc call shell toggle actions ''"))
	bind("SUPER + W", "Weather", exec("qs ipc call shell toggle weather ''"))
	bind("SUPER + E", "Emojis", exec("qs ipc call shell toggle launcher emoji"))
	bind("SUPER + V", "Clipboard history", exec("qs ipc call shell toggle launcher clipboard"))
	bind("SUPER + slash", "Keybindings", exec("qs ipc call shell toggle launcher keys"))
	bind("SUPER + P", "Next wallpaper", exec("~/.local/bin/wallpaper next"))
end

do
	local bind = section("Session")
	bind("SUPER + escape", "Lock system", exec("loginctl lock-session"))
end

do
	local bind = section("Capture")
	bind("print", "Screenshot", exec("~/.local/bin/screenshot region"))
	bind("SHIFT + print", "Screenshot of the screen", exec("~/.local/bin/screenshot fullscreen"))
	bind("SUPER + D", "Dictation", exec("~/.local/bin/dictation"))
end

do
	local bind = section("Notifications")
	bind(
		"SUPER + N",
		"Toggle notification center",
		exec("qs ipc call shell toggle notifications ''")
	)
	bind(
		"SUPER + period",
		"Open latest notification",
		exec("qs ipc call notifications activateLatest")
	)
	bind(
		"SUPER + comma",
		"Close latest notification",
		exec("qs ipc call notifications dismissLatest")
	)
end

do
	-- No resize drag: resize_on_border already does it from any edge.
	local bind = section("Mouse")
	bind("SUPER + mouse:272", "Move window", hl.dsp.window.drag(), { mouse = true })
end

do
	-- Locked: they work on the lock screen too. The shell shows the new level
	-- (Osd.qml follows PipeWire and the shell's own brightness).
	local bind = section("Media")
	local function audio(command)
		return command .. " && canberra-gtk-play -i audio-volume-change"
	end
	-- keys, description, command, repeats while held
	for _, m in ipairs({
		{
			"XF86AudioRaiseVolume",
			"Volume up",
			audio("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"),
			true,
		},
		{
			"XF86AudioLowerVolume",
			"Volume down",
			audio("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
			true,
		},
		{
			"XF86AudioMute",
			"Volume mute",
			audio("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
			false,
		},
		{
			"XF86AudioMicMute",
			"Microphone mute",
			audio("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
			false,
		},
		{ "XF86MonBrightnessUp", "Brightness up", "qs ipc call brightness up", true },
		{ "XF86MonBrightnessDown", "Brightness down", "qs ipc call brightness down", true },
		{ "XF86AudioNext", "Next track", "playerctl next", false },
		{ "XF86AudioPause", "Pause track", "playerctl play-pause", false },
		{ "XF86AudioPlay", "Play track", "playerctl play-pause", false },
		{ "XF86AudioPrev", "Previous track", "playerctl previous", false },
	}) do
		bind(m[1], m[2], exec(m[3]), { locked = true, repeating = m[4] })
	end
end
