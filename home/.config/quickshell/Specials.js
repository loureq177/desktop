.pragma library

// The special workspaces of programs.special in hyprland.lua, as the shell
// shows them: `title` is the app's desc there (its bind reads "Show <title>"),
// `desc` the launcher's line under it, `icon` the bar's line icon and
// `appIcon` the launcher's theme icon. `desktop` is the desktop entry of the
// same app, which the launcher leaves out: the special workspace stands for it.
var list = [
	{ name: "claude", title: "Claude", icon: "sparkles", desc: "AI assistant", appIcon: "", keywords: "ai chat assistant" },
	{ name: "calendar", title: "Calendar", icon: "calendar", desc: "Google Calendar", appIcon: "calendar", desktop: "calendar", keywords: "google kalendarz" },
	{ name: "mail", title: "Mail", icon: "mail", desc: "Gmail", appIcon: "gmail", desktop: "gmail", keywords: "gmail email poczta" },
	{ name: "tasks", title: "Tasks", icon: "circle-check", desc: "Google Tasks", appIcon: "", desktop: "tasks", keywords: "google todo zadania" },
	{ name: "whatsapp", title: "WhatsApp", icon: "message-circle", desc: "Messages", appIcon: "whatsapp", desktop: "whatsapp", keywords: "chat messages wiadomości" },
	{ name: "spotify", title: "Spotify", icon: "audio-lines", desc: "Music", appIcon: "spotify", desktop: "com.spotify.Client", keywords: "music muzyka" },
	{ name: "btop", title: "Activity Monitor", icon: "memory-stick", desc: "Processes, memory, CPU", appIcon: "utilities-system-monitor", desktop: "btop", keywords: "btop top processes procesy memory pamięć cpu" },
	{ name: "yazi", title: "Files", icon: "folder", desc: "File manager", appIcon: "system-file-manager", desktop: "yazi", keywords: "yazi file manager pliki" },
	{ name: "jolt", title: "Energy", icon: "zap", desc: "Battery and energy use", appIcon: "gnome-power-statistics", keywords: "jolt battery power usage bateria energia zużycie" }
];

function find(name) {
	for (var i = 0; i < list.length; i++) {
		if (list[i].name === name)
			return list[i];
	}
	return null;
}

// The special workspace that stands for desktop entry `id`, or null.
function byDesktopEntry(id) {
	for (var i = 0; i < list.length; i++) {
		if (list[i].desktop && list[i].desktop === id)
			return list[i];
	}
	return null;
}

function bindName(special) {
	return "Show " + special.title;
}
