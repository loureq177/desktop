local bin = os.getenv("HOME") .. "/.local/bin"
local hypr = os.getenv("HOME") .. "/.config/hypr"

return {
	terminal = "ghostty",
	browser = "zen-browser",
	launcher = "rofi -show drun -replace",

	special = {
		discord = { exe = "discord", class = "discord", ws = "discord" },
		spotify = { exe = "flatpak run com.spotify.Client", class = "spotify", ws = "spotify" },
		tasks = { exe = bin .. "/tasks", class = "tasks", ws = "tasks" },
		calendar = { exe = bin .. "/calendar", class = "calendar", ws = "calendar" },
		mail = { exe = bin .. "/gmail", class = "gmail", ws = "mail" },
		gemini = { exe = bin .. "/gemini", class = "gemini", ws = "gemini" },
		whatsapp = { exe = bin .. "/whatsapp", class = "whatsapp", ws = "whatsapp" },
		yazi = { exe = "ghostty --class=yazi -e yazi", class = "yazi", ws = "yazi" },
		bluetui = { exe = "ghostty --class=bluetui -e bluetui", class = "bluetui", ws = "bluetui" },
		impala = { exe = "ghostty --class=impala -e impala", class = "impala", ws = "impala" },
		btop = { exe = "ghostty --class=btop -e btop", class = "btop", ws = "btop" },
		clipboard = { exe = hypr .. "/scripts/cliphist-paste.sh", class = "clipboard-special", ws = "clipboard" },
	},
}
