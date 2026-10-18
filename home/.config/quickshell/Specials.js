.pragma library

// The special workspaces of programs.special in hyprland.lua, as the shell
// shows them: `title` is the app's desc there (its bind reads "Show <title>"),
// `desc` the launcher's line under it, `icon` the bar's line icon and
// `appIcon` the launcher's theme icon.
var list = [
	{ name: "claude", title: "Claude", icon: "sparkles", desc: "AI assistant", appIcon: "", keywords: "ai chat assistant" },
	{ name: "calendar", title: "Calendar", icon: "calendar", desc: "Google Calendar", appIcon: "calendar", keywords: "google kalendarz" },
	{ name: "mail", title: "Mail", icon: "mail", desc: "Gmail", appIcon: "gmail", keywords: "gmail email poczta" },
	{ name: "tasks", title: "Tasks", icon: "circle-check", desc: "Google Tasks", appIcon: "", keywords: "google todo zadania" },
	{ name: "whatsapp", title: "WhatsApp", icon: "message-circle", desc: "Messages", appIcon: "whatsapp", keywords: "chat messages wiadomości" },
	{ name: "spotify", title: "Spotify", icon: "audio-lines", desc: "Music", appIcon: "spotify", keywords: "music muzyka" },
	{ name: "btop", title: "Activity Monitor", icon: "memory-stick", desc: "Processes, memory, CPU", appIcon: "utilities-system-monitor", keywords: "btop top processes procesy memory pamięć cpu" },
	{ name: "yazi", title: "Files", icon: "folder", desc: "File manager", appIcon: "system-file-manager", keywords: "yazi file manager pliki" },
	{ name: "jolt", title: "Energy", icon: "zap", desc: "Battery and energy use", appIcon: "gnome-power-statistics", keywords: "jolt battery power usage bateria energia zużycie" }
];

function find(name) {
	for (var i = 0; i < list.length; i++) {
		if (list[i].name === name)
			return list[i];
	}
	return null;
}

function bindName(special) {
	return "Show " + special.title;
}
