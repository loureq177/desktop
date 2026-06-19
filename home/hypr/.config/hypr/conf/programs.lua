local terminal = "ghostty"
local launcher = "rofi -show drun -replace"
local runner = "rofi -show run -replace"

local function pwaApp(name)
	return os.getenv("HOME") .. "/.local/bin/" .. name
end

return {
	terminal = terminal,
	launcher = launcher,
	runner = runner,

	browser = {
		exe = "zen-browser",
		class = "zen",
	},

	special = {
		discord = { exe = "discord", class = "discord", ws = "discord" },
		spotify = { exe = "spotify-launcher", class = "Spotify", ws = "spotify" },
		yazi = { exe = "ghostty --class=yazi-special -e yazi", class = "yazi-special", ws = "yazi" },
		tasks = {
			exe = pwaApp("pwa-tasks"),
			class = "chrome-tasks.google.com__-Default",
			ws = "tasks",
		},
		calendar = {
			exe = pwaApp("pwa-calendar"),
			class = "chrome-calendar.google.com__-Default",
			ws = "calendar",
		},
		mail = {
			exe = pwaApp("pwa-gmail"),
			class = "chrome-mail.google.com__-Default",
			ws = "mail",
		},
		whatsapp = {
			exe = pwaApp("pwa-whatsapp"),
			class = "chrome-web.whatsapp.com__-Default",
			ws = "whatsapp",
		},
		bluetui = { exe = "ghostty --class=bluetui -e bluetui", class = "bluetui", ws = "bluetui" },
		impala = { exe = "ghostty --class=impala -e impala", class = "impala", ws = "impala" },
		btop = { exe = "ghostty --class=btop -e btop", class = "btop", ws = "btop" },
	},

	scratchpad = {
		calculator = { exe = "org.gnome.Calculator", class = "org.gnome.Calculator" },
		pwvucontrol = { exe = "com.saivert.pwvucontrol", class = "com.saivert.pwvucontrol" },
		clocks = { exe = "org.gnome.clocks", class = "org.gnome.clocks" },
		loupe = { exe = "org.gnome.Loupe", class = "org.gnome.Loupe" },
		showtime = { exe = "org.gnome.Showtime", class = "org.gnome.Showtime" },
		snapshot = { exe = "org.gnome.Snapshot", class = "org.gnome.Snapshot" },
	},
}
