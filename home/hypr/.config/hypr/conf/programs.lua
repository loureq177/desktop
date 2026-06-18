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
		exe = "app.zen_browser.zen",
		class = "app.zen_browser.zen",
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
			exe = pwaApp("pwa-mail"),
			class = "chrome-mail.google.com__-Default",
			ws = "mail",
		},
		whatsapp = {
			exe = pwaApp("pwa-whatsapp"),
			class = "chrome-web.whatsapp.com__-Default",
			ws = "whatsapp",
		},
	},
}
