-- ─── Programs ────────────────────────────────────────────────────────────────

local bin = os.getenv("HOME") .. "/.local/bin"
local hypr = os.getenv("HOME") .. "/.config/hypr"

local programs = {
	terminal = "ghostty",
	browser = "firefox",
	launcher = "rofi -show drun -replace",

	special = {
		-- Apps
		discord = { exe = "discord", class = "discord", ws = "discord" },
		spotify = { exe = "flatpak run com.spotify.Client", class = "spotify", ws = "spotify" },
		tasks = { exe = bin .. "/tasks", class = "tasks", ws = "tasks" },
		calendar = { exe = bin .. "/calendar", class = "calendar", ws = "calendar" },
		mail = { exe = bin .. "/gmail", class = "gmail", ws = "mail" },
		gemini = { exe = bin .. "/gemini", class = "gemini", ws = "gemini" },
		whatsapp = { exe = bin .. "/whatsapp", class = "whatsapp", ws = "whatsapp" },
		yazi = { exe = "ghostty --class=yazi -e yazi", class = "yazi", ws = "yazi" },

		-- System tools
		audio = {
			exe = "pwvucontrol --tab 4",
			class = "com.saivert.pwvucontrol",
			ws = "pwvucontrol",
		},
		bluetui = { exe = "ghostty --class=bluetui -e bluetui", class = "bluetui", ws = "bluetui" },
		calculator = {
			exe = "gnome-calculator",
			class = "org.ghome.Calculator",
			ws = "gnome-calculator",
		},
		jolt = { exe = "ghostty --class=jolt -e jolt", class = "jolt", ws = "jolt" },
		impala = { exe = "ghostty --class=impala -e impala", class = "impala", ws = "impala" },
		btop = { exe = "ghostty --class=btop -e btop", class = "btop", ws = "btop" },
		nvtop = { exe = "ghostty --class=nvtop -e nvtop", class = "nvtop", ws = "nvtop" },
		clipboard = {
			exe = hypr .. "/scripts/cliphist-paste.sh",
			class = "clipboard-special",
			ws = "clipboard",
		},
	},
}

-- ─── Environment ─────────────────────────────────────────────────────────────

hl.env("AQ_DRM_DEVICES", "/dev/dri/amd-igpu:/dev/dri/nvidia-dgpu")
hl.env("GSK_RENDERER", "ngl")
hl.env("GTK_A11Y", "none")
hl.env(
	"VK_DRIVER_FILES",
	"/usr/share/vulkan/icd.d/radeon_icd.x86_64.json:/usr/share/vulkan/icd.d/radeon_icd.i686.json"
)
hl.env(
	"VK_ICD_FILENAMES",
	"/usr/share/vulkan/icd.d/radeon_icd.x86_64.json:/usr/share/vulkan/icd.d/radeon_icd.i686.json"
)
hl.env("LIBVA_DRIVER_NAME", "radeonsi")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("SAL_USE_VCLPLUGIN", "gtk3")

-- ─── Autostart ───────────────────────────────────────────────────────────────

local gsettings = "gsettings set org.gnome.desktop.interface"

hl.on("hyprland.start", function()
	local cmds = {
		gsettings .. " icon-theme 'Papirus-Dark'",
		gsettings .. " font-name 'Adwaita Sans 12'",
		gsettings .. " color-scheme 'prefer-dark'",
		gsettings .. " gtk-theme 'Adwaita-dark'",
		gsettings .. " monospace-font-name 'JetBrainsMono Nerd Font Mono 12'",

		"dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE",
		"systemctl --user start hyprland-session.target",

		"wl-paste --type text --watch cliphist -max-items 50 store",
		"wl-paste --type image/png --watch cliphist -max-items 10 store",
		"wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.25",
		"waybar",
		"swaybg -i ~/.config/hypr/wallpapers/hyprland.png",
		"swayosd-server",
		"hyprsunset",
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
	output = "DP-1",
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
	},
	gestures = {
		workspace_swipe_touch = true,
		workspace_swipe_cancel_ratio = 0.05,
	},
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- ─── Look & Feel ─────────────────────────────────────────────────────────────

local colors = {
	accent_blue = "rgba(58a6ffee)",
	accent_purple = "rgba(bc8cffee)",
	inactive_border = "rgba(30363dee)",
}

hl.config({
	general = {
		gaps_in = 8,
		gaps_out = 8,
		border_size = 2,
		col = {
			active_border = {
				colors = { colors.accent_blue, colors.accent_purple },
				angle = 45,
			},
			inactive_border = colors.inactive_border,
		},
		resize_on_border = true,
		allow_tearing = false,
		layout = "dwindle",
	},
	decoration = {
		rounding = 0,
		rounding_power = 0,
		active_opacity = 1.0,
		inactive_opacity = 0.75,
		shadow = {
			range = 4,
			render_power = 3,
			color = "0xee1a1a1a",
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

for _, app in pairs(programs.special) do
	local ws = "special:" .. app.ws
	hl.workspace_rule({
		workspace = ws,
		on_created_empty = app.exe,
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
	["SUPER + comma"] = "swaync-client --hide-latest", -- Dismiss notification
	["SUPER + SHIFT + comma"] = "swaync-client -a", -- Activate/open latest notification
	["SUPER + CTRL + D"] = "swaync-client -d", -- DND mode
	["SUPER + CTRL + comma"] = "swaync-client -t",

	-- ─── System ─────────────────────────────────────────────────────────────────
	["SUPER + CTRL + Q"] = "hyprlock",
	["SUPER + CTRL + M"] = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && pkill -RTMIN+8 waybar",
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
	{ "XF86AudioRaiseVolume", "swayosd-client --output-volume raise", true },
	{ "XF86AudioLowerVolume", "swayosd-client --output-volume lower", true },
	{ "XF86AudioMute", "swayosd-client --output-volume mute-toggle" },
	{ "XF86AudioMicMute", "swayosd-client --input-volume mute-toggle" },
	{ "XF86MonBrightnessUp", "swayosd-client --brightness raise", true },
	{ "XF86MonBrightnessDown", "swayosd-client --brightness lower", true },
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
