local terminal = "ghostty"
local launcher = "rofi -show drun"
local runner = "rofi -show run"

local function webApp(url)
	return ("flatpak run org.chromium.Chromium --app=%s"):format(url)
end

return {
	terminal = terminal,
	launcher = launcher,
	runner = runner,

	browser = {
		exe = "flatpak run io.github.zen_browser.zen",
		class = "app.zen_browser.zen",
	},

	special = {
		discord = { exe = "flatpak run com.discordapp.Discord", class = "com.discordapp.Discord", ws = "discord" },
		spotify = { exe = "flatpak run com.spotify.Client", class = "spotify", ws = "spotify" },
		yazi = { exe = "ghostty --class=yazi-special -e yazi", class = "yazi-special", ws = "yazi" },
		calendar = {
			exe = webApp("https://calendar.google.com"),
			class = "chrome-calendar.google.com__-Default",
			ws = "calendar",
		},
		tasks = { exe = webApp("https://tasks.google.com"), class = "chrome-tasks.google.com__-Default", ws = "tasks" },
		mail = { exe = webApp("https://mail.google.com"), class = "chrome-mail.google.com__-Default", ws = "mail" },
		whatsapp = {
			exe = webApp("https://web.whatsapp.com"),
			class = "chrome-web.whatsapp.com__-Default",
			ws = "whatsapp",
		},
	},
}
