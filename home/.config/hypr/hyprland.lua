local bin = os.getenv("HOME") .. "/.local/bin"
local hypr = os.getenv("HOME") .. "/.config/hypr"

local ui = dofile(hypr .. "/ui.lua")

local local_ok, local_cfg = pcall(dofile, hypr .. "/local.lua")
if not local_ok or type(local_cfg) ~= "table" then
	local_cfg = {}
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

local programs = {
	terminal = "ghostty",
	browser = "firefox",
	launcher = "qs ipc call shell toggle launcher apps",

	-- special workspace name -> app; `key` binds SUPER + SHIFT + key to toggle it.
	-- The shell lists them too (quickshell/Specials.js), by name and desc.
	special = {
		claude = webapp("claude", "https://claude.ai", "Claude", "A"),
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
	},
}

if type(local_cfg.env) == "function" then
	local_cfg.env()
end

hl.env("GSK_RENDERER", "gl")
hl.env("GTK_A11Y", "none")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("GDK_WAYLAND_DISABLE", "ext_background_effect_manager_v1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QS_ICON_THEME", ui.theme.icon)
hl.env("SDL_VIDEODRIVER", "wayland")
for _, prefix in ipairs({ "XCURSOR", "HYPRCURSOR" }) do
	hl.env(prefix .. "_THEME", ui.theme.cursor)
	hl.env(prefix .. "_SIZE", tostring(ui.font.size_cursor))
end
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("SAL_USE_VCLPLUGIN", "gtk3")

local function gset(key, val)
	return string.format("gsettings set org.gnome.desktop.interface %s '%s'", key, val)
end

hl.on("hyprland.start", function()
	-- Xwayland is off in Hyprland: xwayland-satellite.socket owns :0 and starts
	-- it for the first X11 client. Hyprland drops DISPLAY when it loads the
	-- config with Xwayland disabled, so it has to be set here, before anything
	-- is spawned (and before DISPLAY is exported to dbus/systemd below).
	hl.env("DISPLAY", ":0")

	local cmds = {
		-- First, so the session it locks on startup has nothing on screen yet.
		"~/.local/bin/quickshell-session",

		gset("cursor-theme", ui.theme.cursor),
		gset("icon-theme", ui.theme.icon),
		gset("font-name", ui.font.ui),
		gset("color-scheme", "prefer-dark"),
		gset("gtk-theme", ui.theme.gtk),
		gset("monospace-font-name", ui.font.mono .. " 12"),

		"dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE AQ_DRM_DEVICES VK_DRIVER_FILES VK_ICD_FILENAMES LIBVA_DRIVER_NAME GSK_RENDERER GTK_A11Y GDK_BACKEND GDK_WAYLAND_DISABLE XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_THEME HYPRCURSOR_SIZE QT_QPA_PLATFORM SDL_VIDEODRIVER ELECTRON_OZONE_PLATFORM_HINT",
		-- Nothing stops the target when Hyprland exits, so after a restart a plain
		-- start is a no-op and its services stay bound to the dead compositor.
		"sh -c 'systemctl --user reset-failed; systemctl --user restart hyprland-session.target'",

		"~/.local/bin/wallpaper init",
		"sh -c 'pidof hyprsunset >/dev/null || hyprsunset'",
		-- install.sh cannot do this before Firefox has made a profile.
		"sh -c '~/.local/bin/firefox-apply >/dev/null 2>&1'",
	}
	-- Machine-specific startup commands (local.lua).
	if type(local_cfg.autostart) == "table" then
		for _, cmd in ipairs(local_cfg.autostart) do
			table.insert(cmds, cmd)
		end
	end

	for _, cmd in ipairs(cmds) do
		hl.exec_cmd(cmd)
	end
end)

local function lid_is_closed()
	local f = io.popen("cat /proc/acpi/button/lid/*/state 2>/dev/null")
	if f == nil then
		return false
	end
	local out = f:read("*a") or ""
	f:close()
	return out:find("closed", 1, true) ~= nil
end

local function has_external_monitor()
	for _, m in ipairs(hl.get_monitors()) do
		if not (m.name or ""):find("^eDP") then
			return true
		end
	end
	return false
end

local laptop_disabled = nil

local function apply_monitors()
	laptop_disabled = lid_is_closed() and has_external_monitor()
	if type(local_cfg.monitors) == "function" then
		local_cfg.monitors({ laptop_disabled = laptop_disabled })
	end
	hl.monitor({
		output = "",
		mode = "preferred",
		position = "auto",
		scale = 1,
	})
end

local function sync_monitors()
	if (lid_is_closed() and has_external_monitor()) ~= laptop_disabled then
		apply_monitors()
		return true
	end
	return false
end

apply_monitors()

local compacting = false
local compact_gen = 0

local function is_compactable_ws(ws)
	if ws == nil or ws.special then
		return false
	end
	local id = ws.id
	if type(id) ~= "number" or id < 1 or id ~= math.floor(id) then
		return false
	end
	if not tostring(ws.name or ""):match("^%d+$") then
		return false
	end
	return true
end

local function compact_workspaces()
	if compacting then
		return
	end
	compacting = true
	pcall(function()
		local nums = {}
		for _, ws in ipairs(hl.get_workspaces()) do
			if is_compactable_ws(ws) then
				table.insert(nums, ws)
			end
		end
		if #nums == 0 then
			return
		end
		-- Number left to right across monitors, then by id within one. Hyprland
		-- hands out initial workspaces in monitor id order, not by position.
		local function pos(ws)
			local m = ws.monitor
			return m ~= nil and m.x or math.huge, m ~= nil and m.y or math.huge
		end
		table.sort(nums, function(a, b)
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
		local active = hl.get_active_workspace()
		local focused_old = active ~= nil and active.id or nil
		local focused_new = focused_old
		-- Two passes through a free id range so swaps (1 <-> 2) never collide.
		local moved = {}
		for idx, ws in ipairs(nums) do
			if ws.id ~= idx then
				local tmp = 10000 + idx
				hl.dispatch(hl.dsp.workspace.change_id({ workspace = ws.id, id = tmp }))
				moved[idx] = tmp
				if focused_old == ws.id then
					focused_new = idx
				end
			end
		end
		for idx, tmp in pairs(moved) do
			hl.dispatch(hl.dsp.workspace.change_id({ workspace = tmp, id = idx }))
		end
		if focused_new ~= nil and focused_new ~= focused_old then
			pcall(function()
				hl.dispatch(hl.dsp.focus({ workspace = focused_new }))
			end)
		end
	end)
	compacting = false
end

local function schedule_compact(ms)
	compact_gen = compact_gen + 1
	local gen = compact_gen
	hl.timer(function()
		if gen ~= compact_gen then
			return
		end
		compact_workspaces()
	end, { timeout = ms or 500, type = "oneshot" })
end

if not local_cfg.custom_lid_switch then
	hl.bind("switch:on:Lid Switch", function()
		if not sync_monitors() and not has_external_monitor() then
			hl.dispatch(hl.dsp.dpms({ action = "off" }))
		end
		schedule_compact(500)
	end, { locked = true })

	hl.bind("switch:off:Lid Switch", function()
		hl.dispatch(hl.dsp.dpms({ action = "on" }))
		sync_monitors()
		schedule_compact(800)
	end, { locked = true })

	hl.on("hyprland.start", function()
		hl.timer(function()
			if sync_monitors() then
				schedule_compact(500)
			end
		end, { timeout = 1500, type = "oneshot" })
	end)

	hl.on("monitor.added", function()
		sync_monitors()
		schedule_compact(500)
	end)
	hl.on("monitor.removed", function()
		sync_monitors()
		schedule_compact(500)
	end)
	-- Monitor positions can move without a monitor coming or going (local.lua).
	hl.on("monitor.layout_changed", function()
		schedule_compact(500)
	end)
	hl.on("config.reloaded", function()
		-- --verify-config has no monitors and crashes on the timer.
		if #hl.get_monitors() > 0 then
			schedule_compact(500)
		end
	end)
end

-- The layout belongs to the machine (local.lua), like the Alt/Super swap.
local keyboard = type(local_cfg.keyboard) == "table" and local_cfg.keyboard or {}

hl.config({
	input = {
		kb_layout = keyboard.layout or "us",
		kb_options = keyboard.options or "",
		repeat_delay = 200,
		repeat_rate = 20,
		sensitivity = 0.2,
		scroll_factor = 0.5,
		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
		},
	},
	cursor = {
		warp_on_change_workspace = true,
	},
	gestures = {
		workspace_swipe_touch = true,
		workspace_swipe_cancel_ratio = 0.02,
	},
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

local special_gesture_mode = nil
local special_gesture_name = nil
local special_history = {}
local special_cycle_active = false

local function special_short_name(ws)
	if ws == nil then
		return nil
	end
	local name = (ws.name or ""):gsub("^special:", "")
	if name == "" then
		return nil
	end
	return name
end

local function visible_special_workspace()
	local mon = hl.get_active_monitor()
	if mon ~= nil and mon.active_special_workspace ~= nil then
		return mon.active_special_workspace
	end
	for _, m in ipairs(hl.get_monitors()) do
		if m.active_special_workspace ~= nil then
			return m.active_special_workspace
		end
	end
	return nil
end

local function set_special_gesture(mode, name)
	if mode == special_gesture_mode and name == special_gesture_name then
		return
	end
	if special_gesture_mode ~= nil then
		hl.gesture({ fingers = 3, direction = special_gesture_mode, action = "unset" })
	end
	special_gesture_mode = nil
	special_gesture_name = nil
	if mode ~= nil and name ~= nil then
		hl.gesture({ fingers = 3, direction = mode, action = "special", workspace_name = name })
		special_gesture_mode = mode
		special_gesture_name = name
	end
end

local function list_open_specials()
	local seen = {}
	local ordered = {}
	local function push(name)
		if name == nil or seen[name] then
			return
		end
		local target = hl.get_workspace("special:" .. name)
		if target ~= nil and not target.is_empty then
			seen[name] = true
			table.insert(ordered, name)
		end
	end
	local wins = hl.get_windows()
	local function focus_age(w)
		local id = w.focus_history_id
		if id == nil or id < 0 then
			return math.huge
		end
		return id
	end
	table.sort(wins, function(a, b)
		return focus_age(a) < focus_age(b)
	end)
	for _, w in ipairs(wins) do
		if w.workspace ~= nil and w.workspace.special then
			push(special_short_name(w.workspace))
		end
	end
	for _, name in ipairs(special_history) do
		push(name)
	end
	for _, ws in ipairs(hl.get_workspaces()) do
		if ws.special then
			push(special_short_name(ws))
		end
	end
	return ordered
end

local function cycle_special(delta)
	local visible = special_short_name(visible_special_workspace())
	if visible == nil then
		return
	end
	local list = list_open_specials()
	if #list < 2 then
		return
	end
	table.sort(list)
	local idx = 1
	for i, name in ipairs(list) do
		if name == visible then
			idx = i
			break
		end
	end
	local target = list[((idx - 1 + delta) % #list) + 1]
	for i, name in ipairs(special_history) do
		if name == target then
			table.remove(special_history, i)
			break
		end
	end
	table.insert(special_history, 1, target)
	hl.dispatch(hl.dsp.workspace.toggle_special(target))
end

local function set_cycle_gestures(enabled)
	if enabled == special_cycle_active then
		return
	end
	if special_cycle_active then
		hl.gesture({ fingers = 3, direction = "left", action = "unset" })
		hl.gesture({ fingers = 3, direction = "right", action = "unset" })
		hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
		special_cycle_active = false
	end
	if enabled then
		hl.gesture({ fingers = 3, direction = "horizontal", action = "unset" })
		for dir, delta in pairs({ left = 1, right = -1 }) do
			hl.gesture({
				fingers = 3,
				direction = dir,
				action = function()
					cycle_special(delta)
				end,
			})
		end
		special_cycle_active = true
	end
end

local function refresh_special_gestures()
	special_history = list_open_specials()
	local visible = special_short_name(visible_special_workspace())
	if visible ~= nil then
		for i, name in ipairs(special_history) do
			if name == visible then
				table.remove(special_history, i)
				break
			end
		end
		table.insert(special_history, 1, visible)
		set_special_gesture("down", visible)
	else
		set_special_gesture("up", special_history[1])
	end
	set_cycle_gestures(visible ~= nil)
end

for _, ev in ipairs({
	"workspace.special_active",
	"workspace.active",
	"window.active",
	"window.close",
}) do
	hl.on(ev, refresh_special_gestures)
end

refresh_special_gestures()

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

local original_animation = hl.animation
hl.animation = function(config)
	if config.enabled == nil then
		config.enabled = true
	end
	original_animation(config)
end

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", speed = 10, bezier = "default" })
hl.animation({ leaf = "border", speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", speed = 4, bezier = "myBezier" })
hl.animation({ leaf = "windowsIn", speed = 4, bezier = "myBezier", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", speed = 5, bezier = "myBezier", style = "popin 85%" })
hl.animation({ leaf = "fadeIn", speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", speed = 4, bezier = "default" })
hl.animation({ leaf = "layersIn", speed = 1.79, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "layersOut", speed = 1.39, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspacesIn", speed = 3, bezier = "quick" })
hl.animation({ leaf = "workspacesOut", speed = 3, bezier = "quick" })
hl.animation({ leaf = "zoomFactor", speed = 7, bezier = "quick" })
hl.animation({ leaf = "specialWorkspaceIn", speed = 4, bezier = "default", style = "slide bottom" })
hl.animation({ leaf = "specialWorkspaceOut", speed = 4, bezier = "default", style = "slide top" })

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
	-- the dim under the launcher and clipboard fades on its own
	name = "no-anim-shell-dim",
	match = { namespace = "^quickshell-dim$" },
	no_anim = true,
})
hl.layer_rule({
	name = "blur-shell-panels",
	match = { namespace = "^quickshell(-bar|-polkit)?$" },
	blur = true,
	-- the shell animates its own panels; Hyprland's fade on top shows the
	-- card unblurred for a moment and freezes its last frame on the way out
	no_anim = true,
	-- above the backdrop dim, so only the panels themselves get frosted
	ignore_alpha = 0.5,
})
hl.layer_rule({
	name = "blur-keybindings-cheatsheet",
	match = { namespace = "^quickshell-keybindings$" },
	blur = true,
	no_anim = true,
	ignore_alpha = 0.2,
})
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

local function autostart_for(exe)
	local prog = exe:match("^(%S+)")
	if prog ~= nil and prog:find("/", 1, true) ~= nil then
		local f = io.open(prog, "r")
		if f == nil then
			return nil
		end
		f:close()
	end
	return exe
end

for name, app in pairs(programs.special) do
	local ws = "special:" .. name
	hl.workspace_rule({
		workspace = ws,
		on_created_empty = autostart_for(app.exe),
		gaps_out = 48,
	})
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

hl.window_rule({
	name = "ghostty-focus-opacity",
	match = { class = "^(com.mitchellh.ghostty)$" },
	opacity = "1.0 0.97",
})

local function b(keys, desc, dispatcher, opts)
	opts = opts or {}
	opts.description = desc
	if opts.repeating == nil then
		opts.repeating = false
	end
	hl.bind(keys, dispatcher, opts)
end

b("SUPER + Q", "Close window", hl.dsp.window.close())
b("SUPER + F", "Toggle fullscreen", hl.dsp.window.fullscreen())
b("SUPER + T", "Toggle window split", hl.dsp.layout("togglesplit"))
b("SUPER + M", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))
-- Alt+Tab in place: with Alt and Super swapped, SUPER is the key labelled Alt.
b("SUPER + TAB", "Focus previous window", hl.dsp.focus({ last = true }))

local directions = { H = "left", L = "right", K = "up", J = "down" }
local mon_short = { left = "l", right = "r", up = "u", down = "d" }
local step = 25

local function overlap(a1, a2, b1, b2)
	return a1 < b2 and a2 > b1
end

local function monitor_in_direction(dir)
	local win = hl.get_active_window()
	local cur = (win ~= nil and win.monitor) or hl.get_active_monitor()
	if cur == nil then
		return false
	end
	for _, m in ipairs(hl.get_monitors()) do
		if
			m.name ~= cur.name
			and overlap(m.y, m.y + m.height, cur.y, cur.y + cur.height)
			and (
				(dir == "left" and m.x + m.width <= cur.x)
				or (dir == "right" and m.x >= cur.x + cur.width)
			)
		then
			return true
		end
	end
	return false
end

local function same_workspace_neighbor(dir)
	local active = hl.get_active_window()
	if active == nil or active.workspace == nil then
		return false
	end
	local ax, ay = active.at.x, active.at.y
	local aw, ah = active.size.x, active.size.y
	local acx, acy = ax + aw / 2, ay + ah / 2
	for _, w in ipairs(hl.get_windows()) do
		if
			w.address ~= active.address
			and w.workspace ~= nil
			and w.workspace.id == active.workspace.id
			and not w.floating
			and w.mapped
			and not w.hidden
		then
			local cx, cy = w.at.x + w.size.x / 2, w.at.y + w.size.y / 2
			local same_row = overlap(w.at.y, w.at.y + w.size.y, ay, ay + ah)
			local same_col = overlap(w.at.x, w.at.x + w.size.x, ax, ax + aw)
			if
				(dir == "left" and cx < acx and same_row)
				or (dir == "right" and cx > acx and same_row)
				or (dir == "up" and cy < acy and same_col)
				or (dir == "down" and cy > acy and same_col)
			then
				return true
			end
		end
	end
	return false
end

local function swap_or_throw(dir)
	if same_workspace_neighbor(dir) then
		pcall(hl.dispatch, hl.dsp.window.swap({ direction = dir }))
		return
	end
	-- At the screen edge: sideways goes to the neighbouring monitor, or to the
	-- previous/next workspace when there is none (workspaces slide horizontally).
	local mon = mon_short[dir]
	if mon ~= "l" and mon ~= "r" then
		return
	end
	if monitor_in_direction(dir) then
		pcall(hl.dispatch, hl.dsp.window.move({ monitor = mon }))
	else
		pcall(hl.dispatch, hl.dsp.window.move({ workspace = dir == "left" and "r-1" or "r+1" }))
	end
end

for key, dir in pairs(directions) do
	b("SUPER + " .. key, "Focus " .. dir, hl.dsp.focus({ direction = dir }))
	b("SUPER + SHIFT + " .. key, "Swap window " .. dir, function()
		swap_or_throw(dir)
	end)

	b(
		"SUPER + CTRL + " .. key,
		"Resize window " .. dir,
		hl.dsp.window.resize({
			x = (dir == "left" and -step) or (dir == "right" and step) or 0,
			y = (dir == "up" and -step) or (dir == "down" and step) or 0,
			relative = true,
		}),
		{ repeating = true }
	)
end

for i = 1, 9 do
	b("SUPER + " .. i, "Switch to workspace " .. i, hl.dsp.focus({ workspace = i }))
	b(
		"SUPER + SHIFT + " .. i,
		"Move window to workspace " .. i,
		hl.dsp.window.move({ workspace = i })
	)
end

local cmds = {

	["SUPER + RETURN"] = { programs.terminal, "Terminal" },
	["SUPER + B"] = { programs.browser, "Browser" },

	["SUPER + space"] = { programs.launcher, "Launcher" },
	["SUPER + A"] = { "qs ipc call shell toggle quicksettings ''", "Quick actions" },
	["SUPER + N"] = { "qs ipc call shell toggle notifications ''", "Toggle notification center" },
	["SUPER + comma"] = { "qs ipc call notifications dismissLatest", "Close latest notification" },
	["SUPER + W"] = { "qs ipc call shell toggle weather ''", "Weather" },
	["SUPER + E"] = { "qs ipc call shell toggle launcher emoji", "Emoji picker" },
	["SUPER + V"] = { "qs ipc call shell toggle clipboard ''", "Clipboard history" },
	["SUPER + escape"] = { "qs ipc call session lock", "Lock system" },
	["SUPER + slash"] = { "qs ipc call shell toggle keybindings ''", "Keybindings" },

	["SUPER + D"] = { "~/.local/bin/dictation", "Dictation" },
	["SUPER + P"] = { "~/.local/bin/wallpaper next", "Next wallpaper" },
	["print"] = { "~/.local/bin/screenshot region", "Screenshot (region)" },
	["SHIFT + print"] = { "~/.local/bin/screenshot fullscreen", "Screenshot (full)" },
}

for bind, entry in pairs(cmds) do
	b(bind, entry[2], hl.dsp.exec_cmd(entry[1]))
end

for name, app in pairs(programs.special) do
	if app.key then
		-- "Show ...": the keybindings sheet files these under special workspaces.
		b("SUPER + SHIFT + " .. app.key, "Show " .. app.desc, hl.dsp.workspace.toggle_special(name))
	end
end

-- The shell shows the new level on its own (Osd.qml follows PipeWire).
local function audio(cmd)
	return cmd .. " && canberra-gtk-play -i audio-volume-change"
end

local media = {
	{
		"XF86AudioRaiseVolume",
		audio("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"),
		true,
		"Volume up",
	},
	{
		"XF86AudioLowerVolume",
		audio("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
		true,
		"Volume down",
	},
	{ "XF86AudioMute", audio("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), nil, "Volume mute" },
	{
		"XF86AudioMicMute",
		audio("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
		nil,
		"Microphone mute",
	},
	{ "XF86MonBrightnessUp", "~/.local/bin/brightness up", true, "Brightness up" },
	{ "XF86MonBrightnessDown", "~/.local/bin/brightness down", true, "Brightness down" },
	{ "XF86AudioNext", "playerctl next", nil, "Next track" },
	{ "XF86AudioPause", "playerctl play-pause", nil, "Pause track" },
	{ "XF86AudioPlay", "playerctl play-pause", nil, "Play track" },
	{ "XF86AudioPrev", "playerctl previous", nil, "Previous track" },
}

for _, m in ipairs(media) do
	b(m[1], m[4], hl.dsp.exec_cmd(m[2]), { locked = true, repeating = m[3] })
end

local function mouse_binds(mod)
	b(mod .. "mouse_down", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
	b(mod .. "mouse_up", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
	b(
		mod .. "SHIFT + mouse_down",
		"Move window to next workspace",
		hl.dsp.window.move({ workspace = "r+1" })
	)
	b(
		mod .. "SHIFT + mouse_up",
		"Move window to previous workspace",
		hl.dsp.window.move({ workspace = "r-1" })
	)
	b(mod .. "mouse:274", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))
	hl.bind(mod .. "mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window" })
	hl.bind(
		mod .. "mouse:273",
		hl.dsp.window.resize(),
		{ mouse = true, description = "Resize window" }
	)
end

mouse_binds("SUPER + ")
