local apps = require("hyprland.apps")
local specials = require("hyprland.specials")
local workspaces = require("hyprland.workspaces")

-- The keys list shows the binds in this order, as "Section: what it does";
-- same description and modifiers share one line.
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
	bind("SUPER + B", "Browser", exec(apps.browser.exec))
	bind("SUPER + RETURN", "Terminal", exec("ghostty"))
	bind("SUPER + space", "Launcher", exec("qs ipc call shell toggle launcher apps"))
end

do
	local bind = section("Windows")
	-- H J K L, or the arrows: the direction and a step that way. Left and
	-- right go on along the row of workspaces (workspaces.lua).
	local directions = {
		{ keys = { "H", "left" }, dir = "left", x = -1, y = 0 },
		{ keys = { "J", "down" }, dir = "down", x = 0, y = 1 },
		{ keys = { "K", "up" }, dir = "up", x = 0, y = -1 },
		{ keys = { "L", "right" }, dir = "right", x = 1, y = 0 },
	}
	-- Each direction's bind, on both of its keys.
	local function each(mods, desc, action_of, opts)
		for _, d in ipairs(directions) do
			for _, key in ipairs(d.keys) do
				bind(mods .. key, desc, action_of(d), opts and { repeating = opts.repeating })
			end
		end
	end
	each("SUPER + ", "Focus window", function(d)
		return d.x ~= 0 and calls(workspaces.focus, d.dir) or hl.dsp.focus({ direction = d.dir })
	end)
	each("SUPER + SHIFT + ", "Move window", function(d)
		return d.x ~= 0 and calls(workspaces.throw, d.dir) or hl.dsp.window.swap({ direction = d.dir })
	end)
	each("SUPER + CTRL + ", "Resize window", function(d)
		return hl.dsp.window.resize({ x = d.x * 25, y = d.y * 25, relative = true })
	end, { repeating = true })
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
	bind("SUPER + S", "Settings", exec("qs ipc call shell toggle launcher settings"))
	bind("SUPER + W", "Weather", exec("qs ipc call shell toggle weather ''"))
	bind("SUPER + E", "Emojis", exec("qs ipc call shell toggle launcher emoji"))
	bind("SUPER + V", "Clipboard history", exec("qs ipc call shell toggle launcher clipboard"))
	bind("SUPER + slash", "Keybindings", exec("qs ipc call shell toggle launcher keys"))
	-- And the desktop's own, in among them (wallpaper).
	bind("SUPER + P", "Next wallpaper from ~/Pictures/Wallpapers", exec("~/.local/bin/wallpaper next"))
end

do
	-- AltGr + J / K scrolls Ghostty one-handed: Ghostty cannot see AltGr, so it
	-- gets CTRL + SHIFT + J / K; other windows get the key as it was.
	local bind = section("Terminal")
	for _, key in ipairs({ "J", "K" }) do
		bind("MOD5 + " .. key, "Scroll", function()
			local win = hl.get_active_window()
			local ghostty = win ~= nil and win.class == "com.mitchellh.ghostty"
			hl.dispatch(hl.dsp.send_shortcut({ mods = ghostty and "CTRL SHIFT" or "MOD5", key = key }))
		end, { repeating = true })
	end
end

do
	local bind = section("Session")
	-- Both under the left hand: the lock on its own, the way out next to it
	-- (and in Actions, on its power button).
	bind("SUPER + escape", "Lock system", exec("loginctl lock-session"))
	bind("SUPER + SHIFT + escape", "Power menu", exec("qs ipc call shell toggle launcher session"))
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
