local bin = os.getenv("HOME") .. "/.local/bin"
local hypr = os.getenv("HOME") .. "/.config/hypr"

local ui = dofile(hypr .. "/ui.lua")

-- What belongs to one machine: keyboard, GPU, monitors, startup commands
-- (local.lua.example).
local ok, machine = pcall(dofile, hypr .. "/local.lua")
if not ok or type(machine) ~= "table" then
	machine = {}
end

local function list(t)
	return type(t) == "table" and t or {}
end

local function webapp(name, url, title, key, desc)
	return {
		exe = bin .. "/firefox-webapp " .. name .. " " .. url,
		class = "webapps",
		title = ".*" .. title .. ".*",
		key = key,
		desc = desc or title,
	}
end

-- Special workspace name -> the app that lives there, started when the
-- workspace is opened empty; `key` toggles it with SUPER + SHIFT. The shell
-- shows them under the same names (quickshell/Specials.js).
local specials = {
	calendar = webapp("calendar", "https://calendar.google.com", "Calendar", "C"),
	mail = webapp("gmail", "https://mail.google.com", "Gmail", "E", "Mail"),
	tasks = webapp("tasks", "https://tasks.google.com", "Tasks", "T"),
	whatsapp = webapp("whatsapp", "https://web.whatsapp.com", "WhatsApp", "W"),
	spotify = {
		exe = "flatpak run com.spotify.Client",
		class = "spotify",
		key = "S",
		desc = "Spotify",
	},
	btop = { exe = "ghostty +new-window -e btop", key = "B", desc = "Activity Monitor" },
	yazi = { exe = "ghostty +new-window -e yazi", key = "F", desc = "Files" },
	jolt = { exe = "ghostty +new-window -e jolt" },
}

-- Set for Hyprland and exported to the systemd user session at start, where
-- the shell and the other session services run.
local exported = { "WAYLAND_DISPLAY", "XDG_CURRENT_DESKTOP", "HYPRLAND_INSTANCE_SIGNATURE" }
local function env(name, value)
	hl.env(name, value)
	table.insert(exported, name)
end

if type(machine.env) == "function" then
	machine.env(env)
end

env("GSK_RENDERER", "gl")
env("GTK_A11Y", "none")
env("XDG_SESSION_DESKTOP", "Hyprland")
env("GDK_BACKEND", "wayland,x11")
env("GDK_WAYLAND_DISABLE", "ext_background_effect_manager_v1")
env("QT_QPA_PLATFORM", "wayland;xcb")
env("QS_ICON_THEME", ui.theme.icon)
env("SDL_VIDEODRIVER", "wayland")
for _, prefix in ipairs({ "XCURSOR", "HYPRCURSOR" }) do
	env(prefix .. "_THEME", ui.theme.cursor)
	env(prefix .. "_SIZE", tostring(ui.font.size_cursor))
end
env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
env("SAL_USE_VCLPLUGIN", "gtk3")

hl.on("hyprland.start", function()
	-- Xwayland is off in Hyprland: xwayland-satellite.socket owns :0 and starts
	-- it for the first X11 client. Hyprland drops DISPLAY when it loads the
	-- config with Xwayland disabled, so it has to be set here, before anything
	-- is spawned or exported.
	env("DISPLAY", ":0")

	local cmds = {
		-- First: autologin opened the session, the lock closes it before anything
		-- else is on screen.
		"hyprlock --config ~/.config/hypr/hyprlock-boot.conf",

		-- The session target starts the shell (quickshell.service). Nothing stops
		-- the target when Hyprland exits, so after a restart a plain start would
		-- be a no-op and leave its services bound to the dead compositor.
		"sh -c 'dbus-update-activation-environment --systemd "
			.. table.concat(exported, " ")
			.. "; systemctl --user reset-failed; systemctl --user restart hyprland-session.target'",

		-- The GTK settings of ui.toml, which apply-ui keeps.
		"~/.local/bin/apply-ui --gtk",
		"~/.local/bin/wallpaper init",
		-- install.sh cannot do this before Firefox has made a profile.
		"sh -c '~/.local/bin/firefox-apply >/dev/null 2>&1'",
	}
	for _, cmd in ipairs(list(machine.autostart)) do
		table.insert(cmds, cmd)
	end
	for _, cmd in ipairs(cmds) do
		hl.exec_cmd(cmd)
	end
end)

-- Monitors: the ones local.lua names where it puts them, anything else next
-- to them. The laptop panel is off while the lid is closed and another screen
-- is connected, and sits where the connected external monitor wants it.
local laptop = machine.laptop
local monitors = list(machine.monitors)

for _, m in ipairs(monitors) do
	hl.monitor({ output = m.output, mode = m.mode or "preferred", position = m.position or "auto", scale = m.scale or 1 })
end
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

local function lid_closed()
	local f = io.popen("cat /proc/acpi/button/lid/*/state 2>/dev/null")
	if f == nil then
		return false
	end
	local out = f:read("*a") or ""
	f:close()
	return out:find("closed", 1, true) ~= nil
end

-- FALLBACK is Hyprland's stand-in while no real output is left.
local function has_external()
	for _, m in ipairs(hl.get_monitors()) do
		local name = m.name or ""
		if not name:find("^eDP") and name ~= "FALLBACK" then
			return true
		end
	end
	return false
end

-- Whether a monitor rule's output ("DP-1", "desc:...") is connected.
local function connected(output)
	for _, m in ipairs(hl.get_monitors()) do
		local desc = "desc:" .. (m.description or "")
		if output == m.name or desc:sub(1, #output) == output then
			return true
		end
	end
	return false
end

-- Applied again only when it changes: a rule for the panel is itself a
-- monitor change.
local laptop_applied = nil
local function place_laptop()
	if type(laptop) ~= "table" then
		return
	end
	local position = "auto"
	for _, m in ipairs(monitors) do
		if m.laptop and connected(m.output) then
			position = m.laptop
			break
		end
	end
	local disabled = lid_closed() and has_external()
	local state = tostring(disabled) .. " " .. position
	if state == laptop_applied then
		return
	end
	laptop_applied = state
	hl.monitor({
		output = laptop.output,
		mode = laptop.mode or "preferred",
		position = position,
		scale = laptop.scale or 1,
		disabled = disabled,
	})
end

place_laptop()
hl.on("monitor.added", place_laptop)
hl.on("monitor.removed", place_laptop)
-- At login the outputs are still coming up when the session starts.
hl.on("hyprland.start", function()
	hl.timer(place_laptop, { timeout = 1500, type = "oneshot" })
end)

hl.bind("switch:on:Lid Switch", function()
	place_laptop()
	if not has_external() then
		hl.dispatch(hl.dsp.dpms({ action = "off" }))
	end
end, { locked = true })

hl.bind("switch:off:Lid Switch", function()
	hl.dispatch(hl.dsp.dpms({ action = "on" }))
	place_laptop()
end, { locked = true })

-- The layout belongs to the machine (local.lua).
local keyboard = type(machine.keyboard) == "table" and machine.keyboard or {}

hl.config({
	input = {
		kb_layout = keyboard.layout or "us",
		kb_options = keyboard.options or "",
		repeat_delay = 200,
		repeat_rate = 20,
		sensitivity = 0.2,
		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
		},
	},
	cursor = {
		warp_on_change_workspace = true,
	},
	-- H and L past the last window go to the next workspace, not the next
	-- monitor (focus_or_step).
	binds = {
		window_direction_monitor_fallback = false,
	},
	gestures = {
		workspace_swipe_touch = true,
		workspace_swipe_cancel_ratio = 0.02,
	},
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

local function toggle_special(ws)
	hl.dispatch(hl.dsp.workspace.toggle_special((ws.name:gsub("^special:", ""))))
end

-- Three fingers up bring back the special workspace used last, down put away
-- the one that is showing.
hl.gesture({
	fingers = 3,
	direction = "up",
	action = function()
		if hl.get_active_special_workspace() ~= nil then
			return
		end
		local last
		for _, w in ipairs(hl.get_windows()) do
			local age = w.focus_history_id
			if w.workspace ~= nil and w.workspace.special and age ~= nil and age >= 0 then
				if last == nil or age < last.focus_history_id then
					last = w
				end
			end
		end
		if last ~= nil then
			toggle_special(last.workspace)
		end
	end,
})

hl.gesture({
	fingers = 3,
	direction = "down",
	action = function()
		local ws = hl.get_active_special_workspace()
		if ws ~= nil then
			toggle_special(ws)
		end
	end,
})

hl.config({
	general = {
		gaps_in = ui.spacing.gaps_in,
		gaps_out = ui.spacing.gaps_out,
		border_size = ui.border.size,
		col = {
			active_border = {
				colors = { ui.colors.accent_blue, ui.colors.accent_purple },
				angle = 45,
			},
			inactive_border = ui.colors.border,
		},
		resize_on_border = true,
		snap = {
			enabled = true,
		},
	},
	decoration = {
		rounding = ui.rounding.window,
		rounding_power = ui.rounding.power,
		active_opacity = ui.opacity.active,
		inactive_opacity = ui.opacity.inactive,
		dim_inactive = true,
		dim_strength = 0.15,
		dim_special = ui.opacity.dim_special,
		shadow = {
			range = 16,
			render_power = 4,
			color = ui.colors.shadow,
		},
		blur = {
			enabled = true,
			size = 8,
			passes = 3,
			ignore_opacity = true,
			-- live (non-xray) blur halves the frame rate on outputs driven through the multi-GPU blit
			xray = true,
			vibrancy = 0.4,
			noise = 0.02,
		},
	},
	dwindle = {
		preserve_split = true,
	},
})

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

for _, animation in ipairs({
	{ leaf = "global", speed = 10, bezier = "default" },
	{ leaf = "border", speed = 5.39, bezier = "easeOutQuint" },
	{ leaf = "windows", speed = 4, bezier = "myBezier" },
	{ leaf = "windowsIn", speed = 4, bezier = "myBezier", style = "popin 80%" },
	{ leaf = "windowsOut", speed = 5, bezier = "myBezier", style = "popin 85%" },
	{ leaf = "fadeIn", speed = 1.73, bezier = "almostLinear" },
	{ leaf = "fadeOut", speed = 1.46, bezier = "almostLinear" },
	{ leaf = "fade", speed = 4, bezier = "default" },
	{ leaf = "layersIn", speed = 1.79, bezier = "almostLinear", style = "fade" },
	{ leaf = "layersOut", speed = 1.39, bezier = "almostLinear", style = "fade" },
	{ leaf = "fadeLayersIn", speed = 1.79, bezier = "almostLinear" },
	{ leaf = "fadeLayersOut", speed = 1.39, bezier = "almostLinear" },
	{ leaf = "workspacesIn", speed = 3, bezier = "quick" },
	{ leaf = "workspacesOut", speed = 3, bezier = "quick" },
	{ leaf = "zoomFactor", speed = 7, bezier = "quick" },
	{ leaf = "specialWorkspaceIn", speed = 4, bezier = "default", style = "slide bottom" },
	{ leaf = "specialWorkspaceOut", speed = 4, bezier = "default", style = "slide top" },
}) do
	animation.enabled = true
	hl.animation(animation)
end

hl.config({
	xwayland = {
		enabled = false,
	},
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		focus_on_activate = true,
		key_press_enables_dpms = true,
		mouse_move_enables_dpms = true,
		allow_session_lock_restore = true,
	},
})

hl.layer_rule({
	name = "no-anim-capture",
	match = { namespace = "^(hyprpicker|selection)$" },
	no_anim = true,
})
hl.layer_rule({
	name = "no-anim-wallpaper",
	match = { namespace = "^wallpaper$" },
	no_anim = true,
})
hl.layer_rule({
	name = "blur-shell-panels",
	match = { namespace = "^quickshell$" },
	blur = true,
	-- the shell animates its own panels; Hyprland's fade on top shows the
	-- card unblurred for a moment and freezes its last frame on the way out
	no_anim = true,
	-- above the backdrop dim, so only the panels themselves get frosted
	ignore_alpha = 0.5,
})
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

for name, app in pairs(specials) do
	local ws = "special:" .. name
	hl.workspace_rule({ workspace = ws, on_created_empty = app.exe, gaps_out = 48 })
	if app.class then
		hl.window_rule({ match = { class = app.class, title = app.title }, workspace = ws })
	end
end

hl.window_rule({
	name = "picture-in-picture",
	match = { title = "^(Picture-in-Picture)$" },
	float = true,
	pin = true,
	idle_inhibit = "always",
})

hl.window_rule({
	name = "webcam-overlay",
	match = { title = "^(WebcamOverlay)$" },
	float = true,
	pin = true,
	no_initial_focus = true,
	no_dim = true,
})

hl.window_rule({
	-- Steam places its toasts by X11 coordinates, which xwayland-satellite
	-- drops, so without this they float in the middle of the screen.
	name = "steam-toasts",
	match = { class = "^(steam)$", title = "^(notificationtoasts_.*)$" },
	float = true,
	pin = true,
	move = string.format("monitor_w-window_w-%d monitor_h-window_h-%d", ui.spacing.gaps_out, ui.spacing.gaps_out),
	no_initial_focus = true,
	no_dim = true,
})

hl.window_rule({
	name = "idle-inhibit-fullscreen",
	match = { class = ".*" },
	idle_inhibit = "fullscreen",
})

hl.window_rule({
	match = {
		class = "^(org.gnome.*|com.saivert.pwvucontrol|xdg-desktop-portal-gtk)$",
	},
	float = true,
	center = true,
})

-- The workspaces form one row, left to right across the monitors (by their
-- position) and by id on each: SUPER + 1..9 count along it, and H and L go on
-- past the last window of a workspace to the next one in it.
local function row()
	local out = {}
	for _, ws in ipairs(hl.get_workspaces()) do
		if ws.id > 0 then
			table.insert(out, ws)
		end
	end
	local function pos(ws)
		local m = ws.monitor
		if m == nil then
			return math.huge, math.huge
		end
		return m.x, m.y
	end
	table.sort(out, function(a, b)
		local ax, ay = pos(a)
		local bx, by = pos(b)
		if ax ~= bx then
			return ax < bx
		end
		if ay ~= by then
			return ay < by
		end
		return a.id < b.id
	end)
	return out
end

-- An id no workspace has: focusing or moving to it makes a new workspace.
local function new_workspace(workspaces)
	local last = 0
	for _, ws in ipairs(workspaces) do
		last = math.max(last, ws.id)
	end
	return last + 1
end

-- The workspace at place n of the row, or a new one.
local function nth(n)
	local workspaces = row()
	return workspaces[n] ~= nil and workspaces[n].id or new_workspace(workspaces)
end

-- The place of the active workspace in the row, and the row; nothing while a
-- special workspace has the focus.
local function place_in_row()
	local win = hl.get_active_window()
	local active = hl.get_active_workspace()
	if active == nil or (win ~= nil and win.workspace ~= nil and win.workspace.id < 0) then
		return nil
	end
	local workspaces = row()
	for i, ws in ipairs(workspaces) do
		if ws.id == active.id then
			return i, workspaces
		end
	end
	return nil
end

-- Whether a window of `win`'s workspace lies to the `dir` side of it. Focus
-- in a direction wraps round at the edge of the screen, so it is asked only
-- when there is something to go to.
local function anything_beyond(win, dir)
	if win == nil or win.workspace == nil then
		return false
	end
	for _, w in ipairs(hl.get_windows()) do
		if
			w.workspace ~= nil
			and w.workspace.id == win.workspace.id
			and w.mapped
			and not w.hidden
			and w.address ~= win.address
			and ((dir == "left" and w.at.x < win.at.x) or (dir == "right" and w.at.x > win.at.x))
		then
			return true
		end
	end
	return false
end

-- The tiled window of a workspace nearest its `side`, the top one of a column.
local function window_at_side(ws, side)
	local best, best_key
	for _, w in ipairs(hl.get_windows()) do
		if w.workspace ~= nil and w.workspace.id == ws.id and w.mapped and not w.hidden and not w.floating then
			local key = side == "left" and w.at.x or -(w.at.x + w.size.x)
			if best == nil or key < best_key or (key == best_key and w.at.y < best.at.y) then
				best, best_key = w, key
			end
		end
	end
	return best
end

local function focus_or_step(dir)
	if anything_beyond(hl.get_active_window(), dir) then
		hl.dispatch(hl.dsp.focus({ direction = dir }))
		return
	end
	local i, workspaces = place_in_row()
	local ws = i and workspaces[i + (dir == "left" and -1 or 1)]
	if not ws then
		return
	end
	hl.dispatch(hl.dsp.focus({ workspace = ws.id }))
	-- Coming in from the left, the first window in; from the right, the last.
	local entry = window_at_side(ws, dir == "left" and "right" or "left")
	if entry ~= nil then
		hl.dispatch(hl.dsp.focus({ window = entry }))
	end
end

-- Swap with the window on that side; with none there, the window goes on to
-- the next workspace of the row (a new one past its right end).
local function swap_or_throw(dir)
	local win = hl.get_active_window()
	if win == nil then
		return
	end
	if dir == "up" or dir == "down" or anything_beyond(win, dir) then
		hl.dispatch(hl.dsp.window.swap({ direction = dir }))
		return
	end
	local i, workspaces = place_in_row()
	if i == nil then
		return
	end
	local ws = workspaces[i + (dir == "left" and -1 or 1)]
	local target = ws and ws.id or (dir == "right" and new_workspace(workspaces))
	if target then
		hl.dispatch(hl.dsp.window.move({ workspace = target, window = win }))
	end
end

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

local directions = { H = "left", J = "down", K = "up", L = "right" }

do
	local bind = section("Essential")
	bind("SUPER + B", "Browser", exec("firefox"))
	bind("SUPER + RETURN", "Terminal", exec("ghostty"))
	bind("SUPER + space", "Launcher", exec("qs ipc call shell toggle launcher apps"))
end

do
	local bind = section("Windows")
	local step = 25
	for _, key in ipairs({ "H", "J", "K", "L" }) do
		local dir = directions[key]
		if dir == "left" or dir == "right" then
			bind("SUPER + " .. key, "Focus window", function()
				focus_or_step(dir)
			end)
		else
			bind("SUPER + " .. key, "Focus window", hl.dsp.focus({ direction = dir }))
		end
	end
	for _, key in ipairs({ "H", "J", "K", "L" }) do
		local dir = directions[key]
		bind("SUPER + SHIFT + " .. key, "Move window", function()
			swap_or_throw(dir)
		end)
	end
	for _, key in ipairs({ "H", "J", "K", "L" }) do
		local dir = directions[key]
		bind(
			"SUPER + CTRL + " .. key,
			"Resize window",
			hl.dsp.window.resize({
				x = (dir == "left" and -step) or (dir == "right" and step) or 0,
				y = (dir == "up" and -step) or (dir == "down" and step) or 0,
				relative = true,
			}),
			{ repeating = true }
		)
	end
	bind("SUPER + TAB", "Focus previous window", hl.dsp.focus({ last = true }))
	for i = 1, 9 do
		bind("SUPER + " .. i, "Switch to workspace", function()
			hl.dispatch(hl.dsp.focus({ workspace = nth(i) }))
		end)
	end
	for i = 1, 9 do
		bind("SUPER + SHIFT + " .. i, "Move window to workspace", function()
			hl.dispatch(hl.dsp.window.move({ workspace = nth(i) }))
		end)
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
		bind("SUPER + SHIFT + " .. sp.app.key, sp.app.desc, hl.dsp.workspace.toggle_special(sp.name))
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
	bind("SUPER + N", "Toggle notification center", exec("qs ipc call shell toggle notifications ''"))
	bind("SUPER + comma", "Close latest notification", exec("qs ipc call notifications dismissLatest"))
end

do
	-- No resize drag: resize_on_border already does it from any edge.
	local bind = section("Mouse")
	bind("SUPER + mouse:272", "Move window", hl.dsp.window.drag(), { mouse = true })
	bind("SUPER + mouse:274", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))
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
		{ "XF86AudioRaiseVolume", "Volume up", audio("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), true },
		{ "XF86AudioLowerVolume", "Volume down", audio("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), true },
		{ "XF86AudioMute", "Volume mute", audio("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), false },
		{ "XF86AudioMicMute", "Microphone mute", audio("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), false },
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
