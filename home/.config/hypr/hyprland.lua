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
	launcher = "rofi -show drun -replace",

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
		clipboard = {
			exe = hypr .. "/scripts/cliphist-paste.sh",
			class = "clipboard-special",
			ws = "clipboard",
		},
	},
}

-- ─── Environment ─────────────────────────────────────────────────────────────

-- iGPU only: keeping the NVIDIA node open here blocks runtime suspend (~15W
-- idle). dGPU stays available on demand via prime-run offload.
hl.env("AQ_DRM_DEVICES", "/dev/dri/amd-igpu")
hl.env("GSK_RENDERER", "gl")
hl.env("GTK_A11Y", "none")
local vulkan_icd =
	"/usr/share/vulkan/icd.d/radeon_icd.x86_64.json:/usr/share/vulkan/icd.d/radeon_icd.i686.json"
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
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
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
		"waybar",
		"swaybg -i ~/.config/hypr/wallpapers/hyprland.png",
		"swayosd-server",
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
-- NOTE: DP-1 removed (duplicate of Iiyama on another port, same mode/pos).
-- The empty-output fallback below already covers unlisted outputs.
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
		workspace_swipe_cancel_ratio = 0.05,
	},
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- ─── Special workspace swipe ────────────────────────────────────────────────
-- Native finger-tracked gestures (CSpecialWorkspaceGesture in Hyprland source):
-- only one vertical 3-finger gesture can exist at a time and it needs a fixed
-- workspace name, so re-register it when visibility changes. Swipe down hides
-- the visible special workspace, swipe up restores the most recently used one.
-- Never creates an empty special workspace.

local special_gesture_mode = nil -- "down", "up" or nil
local special_gesture_name = nil
local last_special = nil

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

local function refresh_special_gestures()
	local name = special_short_name(visible_special_workspace())
	if name ~= nil then
		last_special = name
		set_special_gesture("down", name)
		return
	end
	if last_special ~= nil then
		local target = hl.get_workspace("special:" .. last_special)
		if target ~= nil and not target.is_empty then
			set_special_gesture("up", last_special)
			return
		end
		last_special = nil
	end
	set_special_gesture(nil, nil)
end

local function track_last_special()
	local best_id = -1
	for _, w in ipairs(hl.get_windows()) do
		if w.workspace ~= nil and w.workspace.special then
			local id = w.focus_history_id or 0
			if id >= best_id then
				best_id = id
				last_special = special_short_name(w.workspace)
			end
		end
	end
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

track_last_special()
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
	name = "swaync-control-center-slide",
	match = { namespace = "^swaync-control-center$" },
	animation = "slide right",
})
hl.layer_rule({
	name = "blur-layer-popups",
	match = { namespace = "^(rofi|swaync-control-center)$" },
	blur = true,
	ignore_alpha = 0.2,
})
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

local cmds = {
	-- ─── Essential ──────────────────────────────────────────────────────────────
	["SUPER + RETURN"] = programs.terminal,
	["SUPER + B"] = programs.browser,
	["SUPER + space"] = programs.launcher,

	--  ─── Notifications ─────────────────────────────────────────────────────────
	["SUPER + comma"] = "swaync-client --close-latest",
	["SUPER + SHIFT + comma"] = "swaync-client --action",
	["SUPER + ALT + 1"] = "swaync-client -a 0",
	["SUPER + ALT + 2"] = "swaync-client -a 1",
	["SUPER + ALT + 3"] = "swaync-client -a 2",
	["SUPER + CTRL + D"] = "swaync-client --toggle-dnd",
	["SUPER + CTRL + comma"] = "swaync-client -t",

	-- ─── System ─────────────────────────────────────────────────────────────────
	["SUPER + CTRL + Q"] = "hyprlock",
	["SUPER + CTRL + I"] = "~/.config/hypr/scripts/caffeine-toggle.sh",
	["SUPER + CTRL + P"] = "hyprpicker -a --notify", -- Pick colors from the screen
	["SUPER + CTRL + space"] = "rofi -show run -replace", -- Run commands
	["SUPER + CTRL + E"] = "rofi -show emoji -modi emoji -emoji-mode copy -emoji-format '{emoji}' -theme emoji",
	["SUPER + escape"] = "~/.config/hypr/scripts/powermenu.sh",

	-- ─── Capture ────────────────────────────────────────────────────────────────
	["SUPER + CTRL + R"] = "~/.config/hypr/scripts/record-screen.sh region",
	["SUPER + CTRL + SHIFT + R"] = "~/.config/hypr/scripts/record-screen.sh fullscreen",
	["SUPER + CTRL + O"] = "~/.config/hypr/scripts/ocr.sh",
	["SHIFT + print"] = "~/.config/hypr/scripts/screenshot.sh fullscreen",
	["print"] = "~/.config/hypr/scripts/screenshot.sh region",
}

for bind, cmd in pairs(cmds) do
	hl.bind(bind, hl.dsp.exec_cmd(cmd))
end

local special_apps = {
	["SUPER + SHIFT + C"] = "calendar",
	["SUPER + SHIFT + T"] = "tasks",
	["SUPER + SHIFT + W"] = "whatsapp",
	["SUPER + SHIFT + E"] = "mail",
	["SUPER + SHIFT + D"] = "discord",
	["SUPER + SHIFT + S"] = "spotify",
	["SUPER + SHIFT + A"] = "gemini",
	["SUPER + SHIFT + F"] = "yazi",
	["SUPER + SHIFT + N"] = "notes",

	-- ─── "System" Apps ──────────────────────────────────────────────────────────

	["SUPER + CTRL + A"] = "audio", -- Audio control
	["SUPER + CTRL + B"] = "bluetui", -- Bluetooth
	["SUPER + CTRL + C"] = "calculator",
	["SUPER + CTRL + V"] = "clipboard",
	["SUPER + CTRL + W"] = "impala", -- WiFi
	["SUPER + CTRL + T"] = "btop", --Activity Monitor
}

for bind, app in pairs(special_apps) do
	hl.bind(bind, hl.dsp.workspace.toggle_special(programs.special[app].ws))
end

hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + T", hl.dsp.layout("togglesplit"))

local directions = { H = "left", L = "right", K = "up", J = "down" }
local step = 25

for key, dir in pairs(directions) do
	hl.bind("SUPER + " .. key, hl.dsp.focus({ direction = dir }))
	hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }))

	hl.bind(
		"SUPER + CTRL + " .. key,
		hl.dsp.window.resize({
			x = (dir == "left" and -step) or (dir == "right" and step) or 0,
			y = (dir == "up" and -step) or (dir == "down" and step) or 0,
			relative = true,
		}),
		{ repeating = true }
	)
end

for i = 1, 9 do
	hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }))
	hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
	hl.bind("SUPER + CTRL + SHIFT + " .. i, hl.dsp.window.move({ workspace = i, follow = false }))
end

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

local media = {
	{ "XF86AudioRaiseVolume", "~/.config/hypr/scripts/volume.sh output raise", true },
	{ "XF86AudioLowerVolume", "~/.config/hypr/scripts/volume.sh output lower", true },
	{ "XF86AudioMute", "~/.config/hypr/scripts/volume.sh output mute-toggle" },
	{ "XF86AudioMicMute", "~/.config/hypr/scripts/volume.sh input mute-toggle" },
	{ "XF86MonBrightnessUp", "swayosd-client --brightness +10", true },
	{ "XF86MonBrightnessDown", "swayosd-client --brightness -10", true },
}

for _, m in ipairs(media) do
	hl.bind(m[1], hl.dsp.exec_cmd(m[2]), { locked = true, repeating = m[3] })
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

hl.bind("SUPER + C", universal_shortcut("CTRL", "C", "CTRL", "Insert"))
hl.bind("SUPER + V", universal_shortcut("CTRL", "V", "SHIFT", "Insert"))
hl.bind("SUPER + X", send_shortcut_once("CTRL", "X"))
hl.bind("SUPER + A", universal_shortcut("CTRL", "A", "CTRL+SHIFT", "A"))

-- ─── Cursor Magnify (hypr-dynamic-cursors) ───────────────────────────────────

if hl.plugin and hl.plugin.dynamic_cursors and hl.plugin.dynamic_cursors.dsp_magnify then
	hl.bind(
		"SUPER + CTRL + Z",
		hl.plugin.dynamic_cursors.dsp_magnify({ duration = 1500, size = 4.0 })
	)
else
	hl.bind("SUPER + CTRL + Z", function()
		if hl.plugin and hl.plugin.dynamic_cursors and hl.plugin.dynamic_cursors.dsp_magnify then
			hl.plugin.dynamic_cursors.dsp_magnify({ duration = 2000, size = 4.0 })()
		end
	end)
end
