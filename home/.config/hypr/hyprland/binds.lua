local apps = require("hyprland.apps")
local specials = require("hyprland.specials")
local workspaces = require("hyprland.workspaces")

-- Keys changed in the shell's keys list (SUPER + /), from ~/.config/hypr/keys.lua:
-- { ["Windows: Close window"] = { mods = "ALT", key = "W" } }; with no key (a line
-- of several, 1..9 or H J K L) only the modifiers change, `off` removes the bind,
-- `run` makes a new one under "Custom: name".
local ok, moved = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/keys.lua")
if not ok or type(moved) ~= "table" then
	moved = {}
end

-- The keys list shows the binds in this order, as "Section: what it does";
-- same description and modifiers share one line.
local function section(name)
	return function(keys, desc, action, opts)
		opts = opts or {}
		opts.description = name .. ": " .. desc
		if opts.repeating == nil then
			opts.repeating = false
		end
		local to = moved[opts.description]
		if type(to) == "table" and to.off then
			return
		end
		if type(to) == "table" and type(to.mods) == "string" then
			local key = to.key or keys:match("([^%s+]+)%s*$")
			keys = to.mods ~= "" and to.mods .. " + " .. key or key
		end
		hl.bind(keys, action, opts)
	end
end

local exec = hl.dsp.exec_cmd

-- A panel of the shell or another of its shortcuts, straight to it: no process per press.
local function panel(name)
	return hl.dsp.global("shell:" .. name)
end

-- A bind action that calls fn(arg).
local function calls(fn, arg)
	return function()
		fn(arg)
	end
end

do
	local bind = section("Essential")
	-- SHIFT, as the specials: B is reserved for it in catalog.toml.
	bind("SUPER + B", "Browser", exec(apps.browser.exec))
	bind(
		"SUPER + RETURN",
		"Terminal",
		exec("gapplication action com.mitchellh.ghostty new-window || ghostty")
	)
	bind("SUPER + space", "Launcher", panel("launcher-apps"))
end

do
	-- The launcher's other lists, each straight to it.
	local bind = section("Launcher")
	bind("SUPER + O", "Open windows", panel("launcher-windows"))
	bind("SUPER + S", "Settings", panel("launcher-settings"))
	bind("SUPER + E", "Emojis", panel("launcher-emoji"))
	bind("SUPER + V", "Clipboard history", panel("launcher-clipboard"))
	bind("SUPER + slash", "Keybindings", panel("launcher-keys"))
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
		return d.x ~= 0 and calls(workspaces.throw, d.dir)
			or hl.dsp.window.swap({ direction = d.dir })
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
	for name, app in pairs(specials.list) do
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
			function()
				specials.toggle(sp.name)
			end
		)
	end
end

do
	local bind = section("System & Tools")
	bind("SUPER + A", "Actions", panel("actions"))
	bind("SUPER + W", "Weather", panel("weather"))
end

do
	-- AltGr + J / K scrolls Ghostty one-handed: Ghostty cannot see AltGr, so it
	-- gets CTRL + SHIFT + J / K; other windows get the key as it was.
	local bind = section("Terminal")
	for _, key in ipairs({ "J", "K" }) do
		bind("MOD5 + " .. key, "Scroll", function()
			local win = hl.get_active_window()
			local ghostty = win ~= nil and win.class == "com.mitchellh.ghostty"
			hl.dispatch(
				hl.dsp.send_shortcut({ mods = ghostty and "CTRL SHIFT" or "MOD5", key = key })
			)
		end, { repeating = true })
	end
end

do
	local bind = section("Session")
	-- Lock is its first row: SUPER + Escape, Enter.
	bind("SUPER + escape", "Power menu", panel("launcher-power"))
end

do
	local bind = section("Capture")
	bind("print", "Screenshot", exec("~/.local/bin/screenshot region"))
	bind("SHIFT + print", "Screenshot of the screen", exec("~/.local/bin/screenshot fullscreen"))
	bind("SUPER + D", "Dictation", exec("~/.local/bin/dictation"))
end

do
	local bind = section("Notifications")
	bind("SUPER + N", "Toggle notification center", panel("notifications"))
	bind("SUPER + period", "Open latest notification", panel("notification-open"))
	bind("SUPER + comma", "Close latest notification", panel("notification-close"))
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
	-- A click each step, held too: canberra-gtk-play costs 50 ms of CPU a play, pw-play 7.
	local function audio(command)
		return command .. " && pw-play /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga"
	end
	-- keys, description, command or the shell's own, repeats while held
	for _, m in ipairs({
		{
			"XF86AudioRaiseVolume",
			"Volume up",
			audio("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 2%+"),
			true,
		},
		{
			"XF86AudioLowerVolume",
			"Volume down",
			audio("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-"),
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
		{ "XF86MonBrightnessUp", "Brightness up", panel("brightness-up"), true },
		{ "XF86MonBrightnessDown", "Brightness down", panel("brightness-down"), true },
		{ "XF86AudioNext", "Next track", "playerctl next", false },
		{ "XF86AudioPause", "Pause track", "playerctl play-pause", false },
		{ "XF86AudioPlay", "Play track", "playerctl play-pause", false },
		{ "XF86AudioPrev", "Previous track", "playerctl previous", false },
	}) do
		local action = type(m[3]) == "string" and exec(m[3]) or m[3]
		bind(m[1], m[2], action, { locked = true, repeating = m[4] })
	end
end

do
	local bind = section("Custom")
	local names = {}
	for desc, to in pairs(moved) do
		if type(to) == "table" and type(to.run) == "string" and desc:find("^Custom: ") then
			table.insert(names, desc)
		end
	end
	table.sort(names)
	for _, desc in ipairs(names) do
		bind("", desc:sub(#"Custom: " + 1), exec(moved[desc].run))
	end
end

-- Over a fullscreen window the bar hides; the pointer resting 0.2 s at the top edge brings
-- it back (Bars.qml). Asked here: a strip of the shell's there would take the edge from the app.
-- Only while some window is fullscreen: the timer stops itself once none is left.
do
	local rested = 0
	local watch
	watch = hl.timer(function()
		local c, m = hl.get_cursor_pos(), hl.get_monitor_at_cursor()
		local ws = m and m.active_workspace
		if not (c and ws and ws.has_fullscreen and c.y - m.y < 2) then
			rested = 0
			for _, w in ipairs(hl.get_workspaces()) do
				if w.has_fullscreen then
					return
				end
			end
			watch:set_enabled(false)
			return
		end
		rested = rested + 1
		if rested == 2 then
			hl.dispatch(panel("bar-peek"))
		end
	end, { timeout = 100, type = "repeat" })
	hl.on("window.fullscreen", function()
		watch:set_enabled(true)
	end)
end

-- The keys list takes new keys in here: none of the binds above, so they reach
-- the shell. A submap needs one bind, on a key no keyboard has.
hl.define_submap("keycapture", function()
	hl.bind("XF86Tools", hl.dsp.submap("reset"))
end)
