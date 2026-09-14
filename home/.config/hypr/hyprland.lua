-- ─── Programs ────────────────────────────────────────────────────────────────

local bin = os.getenv("HOME") .. "/.local/bin"
local hypr = os.getenv("HOME") .. "/.config/hypr"

local ui_ok, ui = pcall(dofile, hypr .. "/ui.lua")
if not ui_ok then
	ui = {
		rounding = { window = 0, element = 0, subtle = 0 },
		border = { size = 2 },
		spacing = { gaps_in = 10, gaps_out = 20 },
		opacity = { active = 1.0, inactive = 0.75 },
		theme = { cursor = "Bibata-Modern-Classic", icon = "Papirus-Dark", gtk = "Adwaita-dark" },
		font = {
			family = "JetBrainsMono Nerd Font Propo",
			mono = "JetBrainsMono Nerd Font Mono",
			ui = "Adwaita Sans 12",
			size_cursor = 24,
		},
		colors = {
			border = "rgba(30363dee)",
			accent_blue = "rgba(58a6ffee)",
			accent_purple = "rgba(bc8cffee)",
			shadow = "rgba(010409ee)",
		},
	}
end

local programs = {
	terminal = "ghostty",
	browser = "firefox",
	launcher = "qs ipc call shell toggle launcher apps",

	special = {
		-- Apps
		discord = { exe = "discord", class = "discord", ws = "discord" },
		spotify = { exe = "flatpak run com.spotify.Client", class = "spotify", ws = "spotify" },
		-- Progressive web apps provisioned by FreshArchLinux
		-- (configure_progressive_webapps in fresh_archlinux.sh).
		-- Not stored in this repo; entries below degrade gracefully
		-- when the launchers are absent (no autostart, keybind still
		-- toggles the workspace).
		tasks = { exe = bin .. "/tasks", class = "tasks", ws = "tasks" },
		calendar = { exe = bin .. "/calendar", class = "calendar", ws = "calendar" },
		mail = { exe = bin .. "/gmail", class = "gmail", ws = "mail" },
		gemini = { exe = bin .. "/gemini", class = "gemini", ws = "gemini" },
		whatsapp = { exe = bin .. "/whatsapp", class = "whatsapp", ws = "whatsapp" },
		yazi = { exe = "ghostty --class=yazi -e yazi", class = "yazi", ws = "yazi" },
		notes = {
			exe = "ghostty --class=notes --working-directory="
				.. os.getenv("HOME")
				.. "/Notes -e nvim",
			class = "notes",
			ws = "notes",
		},

		-- System tools
		audio = {
			exe = "pwvucontrol --tab 4",
			class = "com.saivert.pwvucontrol",
			ws = "pwvucontrol",
		},
		bluetui = { exe = "ghostty --class=bluetui -e bluetui", class = "bluetui", ws = "bluetui" },
		calculator = {
			exe = "gnome-calculator",
			class = "org.gnome.Calculator",
			ws = "gnome-calculator",
		},
		jolt = { exe = "ghostty --class=jolt -e jolt", class = "jolt", ws = "jolt" },
		impala = { exe = "ghostty --class=impala -e impala", class = "impala", ws = "impala" },
		btop = { exe = "ghostty --class=btop -e btop", class = "btop", ws = "btop" },
	},
}

-- ─── Environment ─────────────────────────────────────────────────────────────

-- Both GPUs: external USB-C/DP ports on this Legion are wired to the NVIDIA
-- dGPU, so it must be listed for the external monitor to work (relogin
-- after change). iGPU stays primary; dGPU on demand via prime-run.
hl.env("AQ_DRM_DEVICES", "/dev/dri/amd-igpu:/dev/dri/nvidia-dgpu")
hl.env("GSK_RENDERER", "gl")
hl.env("GTK_A11Y", "none")
local vulkan_icd = "/usr/share/vulkan/icd.d/radeon_icd.json"
hl.env("VK_DRIVER_FILES", vulkan_icd)
hl.env("VK_ICD_FILENAMES", vulkan_icd)
hl.env("LIBVA_DRIVER_NAME", "radeonsi")
hl.env("XDG_SESSION_TYPE", "wayland")
for _, var in ipairs({ "XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP" }) do
	hl.env(var, "Hyprland")
end
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
for _, prefix in ipairs({ "XCURSOR", "HYPRCURSOR" }) do
	hl.env(prefix .. "_THEME", ui.theme.cursor)
	hl.env(prefix .. "_SIZE", tostring(ui.font.size_cursor))
end
-- No QT_QPA_PLATFORMTHEME on purpose: qt6ct is not installed and forcing
-- it makes Qt fall back to a light Fusion palette. Qt apps follow the
-- portal prefer-dark setting instead.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("SAL_USE_VCLPLUGIN", "gtk3")

-- ─── Autostart ───────────────────────────────────────────────────────────────

local gsettings = "gsettings set org.gnome.desktop.interface"

hl.on("hyprland.start", function()
	local cmds = {
		gsettings .. " cursor-theme '" .. ui.theme.cursor .. "'",
		gsettings .. " icon-theme '" .. ui.theme.icon .. "'",
		gsettings .. " font-name '" .. ui.font.ui .. "'",
		gsettings .. " color-scheme 'prefer-dark'",
		gsettings .. " gtk-theme '" .. ui.theme.gtk .. "'",
		gsettings .. " monospace-font-name '" .. ui.font.mono .. " 12'",

		"dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE AQ_DRM_DEVICES VK_DRIVER_FILES VK_ICD_FILENAMES LIBVA_DRIVER_NAME GSK_RENDERER",
		"systemctl --user start hyprland-session.target",

		"wl-paste --type text --watch cliphist -max-items 50 store",
		"wl-paste --type image/png --watch cliphist -max-items 10 store",
		"wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.25",
		"swaybg -i ~/.config/hypr/wallpapers/hyprland.png",
		"quickshell -d",
		"hyprsunset",
		"hyprpm reload -n",
	}

	for _, cmd in ipairs(cmds) do
		hl.exec_cmd(cmd)
	end
end)

-- ─── Monitors ────────────────────────────────────────────────────────────────

local laptop_output = "desc:BOE 0x0998"
local laptop_mode = "1920x1080@165"
local laptop_pos = "320x1440"
local laptop_scale = 1

local external_output = "desc:Iiyama North America PL2792Q 1152011401936"

hl.monitor({
	output = laptop_output,
	mode = laptop_mode,
	position = laptop_pos,
	scale = laptop_scale,
})
hl.monitor({
	output = external_output,
	mode = "2560x1440@59.95",
	position = "0x0",
	scale = 1,
})
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = 1,
})

hl.bind("switch:on:Lid Switch", function()
	local mons = hl.get_monitors()
	if #mons > 1 then
		hl.dsp.dpms({ action = "off", monitor = laptop_output })
	end
end, { locked = true })

hl.bind("switch:off:Lid Switch", function()
	hl.dsp.dpms({ action = "on" })
end, { locked = true })

-- ─── Input & Gestures ────────────────────────────────────────────────────────

hl.config({
	input = {
		kb_layout = "pl",
		kb_variant = "",
		kb_model = "",
		kb_options = "caps:escape,altwin:swap_lalt_lwin",
		kb_rules = "",
		repeat_delay = 200,
		repeat_rate = 20,
		follow_mouse = 1,
		sensitivity = 0.2,
		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
		},
	},
	cursor = {
		inactive_timeout = 0,
		warp_on_change_workspace = true,
		enable_hyprcursor = true,
		sync_gsettings_theme = true,
	},
	gestures = {
		workspace_swipe_touch = true,
		workspace_swipe_cancel_ratio = 0.02,
	},
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- 4-finger drag moves the active window like SUPER + left-click drag.
-- Tiled windows pop out to floating while dragging and dock back to tiling
-- on release. Already-floating windows stay floating.
-- The cursor rides along with the window, like a real mouse drag.
-- SUPER + click bind below is left untouched.
local drag_move_scale = 2.5
local drag_win = nil
local drag_was_tiled = false
local function drag_move_by(delta)
	if delta == nil then
		return
	end
	local dx = math.floor(delta.x * drag_move_scale)
	local dy = math.floor(delta.y * drag_move_scale)
	if dx == 0 and dy == 0 then
		return
	end
	if drag_win ~= nil then
		hl.dispatch(hl.dsp.window.move({ x = dx, y = dy, relative = true, window = drag_win }))
	else
		hl.dispatch(hl.dsp.window.move({ x = dx, y = dy, relative = true }))
	end
	-- Keep the cursor glued to the dragged window, like a real mouse drag.
	local pos = hl.get_cursor_pos()
	if pos ~= nil then
		hl.dispatch(hl.dsp.cursor.move({ x = pos.x + dx, y = pos.y + dy }))
	end
end
local function drag_move_begin()
	local w = hl.get_active_window()
	if w == nil then
		drag_win = nil
		drag_was_tiled = false
		return
	end
	drag_win = w
	drag_was_tiled = not w.floating
	if w.fullscreen ~= 0 then
		hl.dispatch(hl.dsp.window.fullscreen({ action = "unset", window = w }))
	end
	if drag_was_tiled then
		hl.dispatch(hl.dsp.window.float({ action = "set", window = w }))
	end
end
local function drag_move_end()
	if drag_win ~= nil and drag_was_tiled then
		hl.dispatch(hl.dsp.window.float({ action = "unset", window = drag_win }))
	end
	drag_win = nil
	drag_was_tiled = false
end
hl.gesture({
	fingers = 4,
	direction = "swipe",
	action = {
		start = function(e)
			drag_move_begin()
			drag_move_by(e.delta)
		end,
		update = function(e)
			drag_move_by(e.delta)
		end,
		finish = function(_e)
			drag_move_end()
		end,
	},
})

-- ─── Special workspace swipe ────────────────────────────────────────────────
-- Native finger-tracked gestures (CSpecialWorkspaceGesture in Hyprland source):
-- only one vertical 3-finger gesture can exist at a time and it needs a fixed
-- workspace name, so re-register it when visibility changes. Swipe down hides
-- the visible special workspace, swipe up restores the most recently used one.
-- Never creates an empty special workspace.
--
-- Open specials are tracked as an MRU stack (most recent first), rebuilt from
-- window focus history on every relevant event. Closing a special instead of
-- hiding it drops it from the stack, so swipe-up falls back to the next most
-- recently used open special.
--
-- While a special workspace is visible, the 3-finger horizontal workspace
-- swipe is replaced with discrete left/right gestures that cycle through the
-- open specials. Hiding the special restores the normal workspace swipe.

local special_gesture_mode = nil -- "down", "up" or nil
local special_gesture_name = nil
local special_history = {} -- MRU stack of short names, most recent first
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

-- All non-empty special workspaces, most recently focused first. Sources are
-- merged so a workspace is never lost: window focus history gives the order,
-- the previous stack covers transients, and the workspace list is the safety
-- net for anything still open.
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
	-- Note: lower focus_history_id means more recently focused (0 is the
	-- focused window); windows missing from history sort as least recent.
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
	if hl.get_workspaces ~= nil then
		for _, ws in ipairs(hl.get_workspaces()) do
			if ws.special then
				push(special_short_name(ws))
			end
		end
	end
	return ordered
end

-- Cycling between specials is a plain toggle_special dispatch: the native
-- special workspace gesture finger-tracks the card between the running
-- animation's begun/goal offsets, so any horizontal In/Out restyling here
-- would make the next swipe-down hide slide sideways instead of down. The
-- vertical card styles (bottom In, top Out) keep the gesture tracking
-- coherent: cards always rise from the bottom and sink back down.
local function cycle_special(step)
	local visible = special_short_name(visible_special_workspace())
	if visible == nil then
		return
	end
	local list = list_open_specials()
	if #list < 2 then
		return
	end
	local idx = 1
	for i, name in ipairs(list) do
		if name == visible then
			idx = i
			break
		end
	end
	local target = list[((idx - 1 + step) % #list) + 1]
	-- The cycled-to special is now the most recently used.
	for i, name in ipairs(special_history) do
		if name == target then
			table.remove(special_history, i)
			break
		end
	end
	table.insert(special_history, 1, target)
	hl.dispatch(hl.dsp.workspace.toggle_special(target))
end

local function cycle_special_next()
	cycle_special(1)
end

local function cycle_special_prev()
	cycle_special(-1)
end

-- While a special workspace is visible, horizontal motion cycles specials
-- instead of switching regular workspaces underneath the overlay.
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
		hl.gesture({ fingers = 3, direction = "left", action = cycle_special_next })
		hl.gesture({ fingers = 3, direction = "right", action = cycle_special_prev })
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

hl.on("workspace.special_active", function()
	refresh_special_gestures()
end)
hl.on("workspace.active", function()
	refresh_special_gestures()
end)
hl.on("window.active", function()
	refresh_special_gestures()
end)
hl.on("window.close", function()
	refresh_special_gestures()
end)

refresh_special_gestures()

-- ─── Look & Feel ─────────────────────────────────────────────────────────────

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
		allow_tearing = false,
		layout = "dwindle",
	},
	decoration = {
		rounding = ui.rounding.window,
		rounding_power = 0,
		active_opacity = ui.opacity.active,
		inactive_opacity = ui.opacity.inactive,
		shadow = {
			range = 4,
			render_power = 3,
			color = ui.colors.shadow or "rgba(010409ee)",
		},
		blur = {
			size = 6,
			passes = 2,
			vibrancy = 0.1696,
		},
	},
	dwindle = {
		preserve_split = true,
	},
	master = {
		new_status = "master",
	},
	scrolling = {
		fullscreen_on_one_column = true,
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
hl.animation({ leaf = "windowsOut", speed = 4, bezier = "myBezier", style = "popin 80%" })
hl.animation({ leaf = "fadeIn", speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", speed = 4, bezier = "default" })
hl.animation({ leaf = "layers", speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", speed = 4, bezier = "myBezier", style = "popin 90%" })
hl.animation({ leaf = "layersOut", speed = 4, bezier = "myBezier", style = "popin 90%" })
hl.animation({ leaf = "fadeLayersIn", speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", speed = 5, bezier = "quick", style = "slidevert" })
hl.animation({ leaf = "workspacesIn", speed = 3, bezier = "quick" })
hl.animation({ leaf = "workspacesOut", speed = 3, bezier = "quick" })
hl.animation({ leaf = "zoomFactor", speed = 7, bezier = "quick" })
hl.animation({ leaf = "specialWorkspaceIn", speed = 4, bezier = "default", style = "slide bottom" })
hl.animation({ leaf = "specialWorkspaceOut", speed = 4, bezier = "default", style = "slide top" })

-- ─── Misc ────────────────────────────────────────────────────────────────────

hl.config({
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		focus_on_activate = true,
		key_press_enables_dpms = true,
		mouse_move_enables_dpms = true,
		vrr = 0,
	},
})

-- ─── Plugins ─────────────────────────────────────────────────────────────────

if hl.plugin and hl.plugin.dynamic_cursors then
	hl.config({
		plugin = {
			dynamic_cursors = {
				enabled = true,
				mode = "tilt",
				threshold = 2,

				tilt = {
					limit = 5000,
					activation = "negative_quadratic",
					window = 100,
					full = 60,
				},

				shake = {
					enabled = true,
					threshold = 6.0,
					base = 4.0,
					speed = 4.0,
					influence = 0.0,
					limit = 0.0,
					timeout = 2000,
					effects = false,
					ipc = false,
				},

				hyprcursor = {
					nearest = 0,
					enabled = true,
					resolution = 256,
					fallback = "clientside",
				},
			},
		},
	})
end

-- ─── Windows & Workspaces ────────────────────────────────────────────────────

hl.layer_rule({
	name = "no-anim-capture",
	match = { namespace = "^(hyprpicker|selection)$" },
	no_anim = true,
})
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h-120",
	float = true,
})

-- Skip autostart when the launcher does not exist (e.g. standalone
-- dotfiles clone without the FreshArchLinux PWA step). The workspace
-- and keybind still work; only the auto-spawn is skipped.
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

for _, app in pairs(programs.special) do
	local ws = "special:" .. app.ws
	hl.workspace_rule({
		workspace = ws,
		on_created_empty = autostart_for(app.exe),
		gaps_out = 75,
	})
	hl.window_rule({ match = { class = app.class }, workspace = ws })
end

hl.window_rule({
	name = "picture-in-picture",
	match = { title = "^(Picture-in-Picture)$" },
	float = true,
	pin = true,
})

hl.window_rule({
	match = {
		class = "^(org.gnome.*|com.saivert.pwvucontrol|pavucontrol|nm-connection-editor|blueman-manager|xdg-desktop-portal-gtk|file-roller)$",
	},
	float = true,
	center = true,
})

-- ─── Keybindings ────────────────────────────────────────────────────────────────
-- Every bind carries a description so the SUPER + ? cheatsheet
-- (quickshell keybindings menu, fed by `hyprctl binds`) can list it.

local function b(keys, desc, dispatcher, opts)
	opts = opts or {}
	opts.description = desc
	hl.bind(keys, dispatcher, opts)
end

local cmds = {
	-- ─── Essential ──────────────────────────────────────────────────────────────
	["SUPER + RETURN"] = { programs.terminal, "Terminal" },
	["SUPER + B"] = { programs.browser, "Browser" },
	["SUPER + space"] = { programs.launcher, "Launch apps" },
	["SUPER + slash"] = { "qs ipc call shell toggle keybindings ''", "Keybindings" },

	--  ─── Notifications (quickshell) ────────────────────────────────────────────
	["SUPER + comma"] = { "qs ipc call notifications dismissLatest", "Close latest notification" },
	["SUPER + SHIFT + comma"] = { "qs ipc call notifications invokeDefault", "Notification action" },
	["SUPER + ALT + 1"] = { "qs ipc call notifications invokeAction 0", "Notification action 1" },
	["SUPER + ALT + 2"] = { "qs ipc call notifications invokeAction 1", "Notification action 2" },
	["SUPER + ALT + 3"] = { "qs ipc call notifications invokeAction 2", "Notification action 3" },
	["SUPER + CTRL + D"] = { "qs ipc call notifications toggleDnd", "Toggle Do Not Disturb" },
	["SUPER + CTRL + comma"] = { "qs ipc call notifications toggle", "Toggle notification center" },
	["SUPER + CTRL + V"] = { "qs ipc call clipboard toggle", "Clipboard history" },

	-- ─── System ─────────────────────────────────────────────────────────────────
	["SUPER + CTRL + Q"] = { "hyprlock", "Lock system" },
	["SUPER + CTRL + I"] = { "~/.local/bin/caffeine-toggle.sh", "Toggle idle inhibit" },
	["SUPER + CTRL + P"] = { "hyprpicker -a --notify", "Color picker" },
	["SUPER + CTRL + space"] = { "qs ipc call shell toggle launcher run", "Run commands" },
	["SUPER + period"] = { "qs ipc call shell toggle launcher emoji", "Emoji picker" },
	["SUPER + CTRL + E"] = { "qs ipc call shell toggle launcher emoji", "Emoji picker" },
	["SUPER + escape"] = { "qs ipc call shell toggle launcher power", "System menu" },

	-- ─── Capture ────────────────────────────────────────────────────────────────
	["SUPER + CTRL + R"] = {
		"~/.local/bin/record-screen.sh region",
		"Screen recording (region)",
	},
	["SUPER + CTRL + SHIFT + R"] = {
		"~/.local/bin/record-screen.sh fullscreen",
		"Screen recording (fullscreen)",
	},
	["SUPER + CTRL + O"] = { "~/.local/bin/ocr.sh", "OCR from screen" },
	["SHIFT + print"] = {
		"~/.local/bin/screenshot.sh fullscreen",
		"Screenshot (fullscreen)",
	},
	["print"] = { "~/.local/bin/screenshot.sh region", "Screenshot (region)" },
}

for bind, entry in pairs(cmds) do
	b(bind, entry[2], hl.dsp.exec_cmd(entry[1]))
end

local special_apps = {
	["SUPER + SHIFT + C"] = { "calendar", "Calendar" },
	["SUPER + SHIFT + T"] = { "tasks", "Tasks" },
	["SUPER + SHIFT + W"] = { "whatsapp", "WhatsApp" },
	["SUPER + SHIFT + E"] = { "mail", "Mail" },
	["SUPER + SHIFT + D"] = { "discord", "Discord" },
	["SUPER + SHIFT + S"] = { "spotify", "Spotify" },
	["SUPER + SHIFT + A"] = { "gemini", "Gemini" },
	["SUPER + SHIFT + F"] = { "yazi", "File manager (yazi)" },
	["SUPER + SHIFT + N"] = { "notes", "Notes" },

	-- ─── "System" Apps ──────────────────────────────────────────────────────────

	["SUPER + CTRL + A"] = { "audio", "Audio controls" },
	["SUPER + CTRL + B"] = { "bluetui", "Bluetooth controls" },
	["SUPER + CTRL + C"] = { "calculator", "Calculator" },
	["SUPER + CTRL + W"] = { "impala", "Wifi controls" },
	["SUPER + CTRL + T"] = { "btop", "Activity Monitor" },
}

for bind, entry in pairs(special_apps) do
	b(bind, entry[2], hl.dsp.workspace.toggle_special(programs.special[entry[1]].ws))
end

b("SUPER + Q", "Close window", hl.dsp.window.close())
b("SUPER + F", "Toggle fullscreen", hl.dsp.window.fullscreen())
b("SUPER + T", "Toggle window split", hl.dsp.layout("togglesplit"))
b("SUPER + CTRL + F", "Toggle floating", hl.dsp.window.float())

local directions = { H = "left", L = "right", K = "up", J = "down" }
local step = 25

for key, dir in pairs(directions) do
	b("SUPER + " .. key, "Focus " .. dir, hl.dsp.focus({ direction = dir }))
	b("SUPER + SHIFT + " .. key, "Swap window " .. dir, hl.dsp.window.swap({ direction = dir }))

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
	b(
		"SUPER + CTRL + SHIFT + " .. i,
		"Move window silently to workspace " .. i,
		hl.dsp.window.move({ workspace = i, follow = false })
	)
end

b("SUPER + mouse:272", "Drag window", hl.dsp.window.drag(), { mouse = true })
b("SUPER + mouse:273", "Resize window (mouse)", hl.dsp.window.resize(), { mouse = true })

local media = {
	{ "XF86AudioRaiseVolume", "~/.local/bin/volume.sh output raise", true, "Volume up" },
	{
		"XF86AudioLowerVolume",
		"~/.local/bin/volume.sh output lower",
		true,
		"Volume down",
	},
	{ "XF86AudioMute", "~/.local/bin/volume.sh output mute-toggle", nil, "Volume mute" },
	{
		"XF86AudioMicMute",
		"~/.local/bin/volume.sh input mute-toggle",
		nil,
		"Microphone mute",
	},
	{ "XF86MonBrightnessUp", "~/.local/bin/brightness.sh up", true, "Brightness up" },
	{ "XF86MonBrightnessDown", "~/.local/bin/brightness.sh down", true, "Brightness down" },
}

for _, m in ipairs(media) do
	b(m[1], m[4], hl.dsp.exec_cmd(m[2]), { locked = true, repeating = m[3] })
end

-- ─── Universal Clipboard & Selection ────────────────────────────────────────

local function send_shortcut_once(mods, key)
	return function()
		hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
		hl.timer(function()
			hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
		end, { timeout = 50, type = "oneshot" })
	end
end

local function active_window_is_terminal()
	local window = hl.get_active_window()
	if not window then
		return false
	end

	for _, tag in ipairs(window.tags or {}) do
		if tag:gsub("%*$", "") == "terminal" then
			return true
		end
	end

	local class = (window.class or ""):lower()
	local initial_class = (window.initial_class or ""):lower()
	if
		class:find("ghostty")
		or initial_class:find("ghostty")
		or class:find("kitty")
		or initial_class:find("kitty")
		or class:find("alacritty")
		or initial_class:find("alacritty")
		or class:find("foot")
		or initial_class:find("foot")
		or class:find("wezterm")
		or initial_class:find("wezterm")
	then
		return true
	end

	if window.pid and window.pid > 0 then
		local f = io.open("/proc/" .. window.pid .. "/comm", "r")
		if f then
			local comm = (f:read("*l") or ""):lower():gsub("%s+", "")
			f:close()
			if
				comm == "ghostty"
				or comm == "kitty"
				or comm == "alacritty"
				or comm == "foot"
				or comm == "wezterm"
			then
				return true
			end
		end
	end

	return false
end

local function universal_shortcut(gui_mods, gui_key, term_mods, term_key)
	return function()
		if active_window_is_terminal() then
			send_shortcut_once(term_mods, term_key)()
		else
			send_shortcut_once(gui_mods, gui_key)()
		end
	end
end

b("SUPER + C", "Copy", universal_shortcut("CTRL", "C", "CTRL", "Insert"))
b("SUPER + V", "Paste", universal_shortcut("CTRL", "V", "SHIFT", "Insert"))
b("SUPER + X", "Cut", send_shortcut_once("CTRL", "X"))
b("SUPER + A", "Select all", universal_shortcut("CTRL", "A", "CTRL+SHIFT", "A"))

-- ─── Cursor Magnify (hypr-dynamic-cursors) ───────────────────────────────────

if hl.plugin and hl.plugin.dynamic_cursors and hl.plugin.dynamic_cursors.dsp_magnify then
	b(
		"SUPER + CTRL + Z",
		"Magnify cursor",
		hl.plugin.dynamic_cursors.dsp_magnify({ duration = 1500, size = 4.0 })
	)
else
	b("SUPER + CTRL + Z", "Magnify cursor", function()
		if hl.plugin and hl.plugin.dynamic_cursors and hl.plugin.dynamic_cursors.dsp_magnify then
			hl.plugin.dynamic_cursors.dsp_magnify({ duration = 2000, size = 4.0 })()
		end
	end)
end
