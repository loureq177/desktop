.pragma library

// The specials as the shell shows them: `icon` is the bar's, `appIcon` the launcher's,
// `desktop` the app's desktop entry it replaces there, `inBar: false` keeps it off the bar.
var list = [
	{ name: "calendar", app: "Google Calendar", title: "Calendar", icon: "googlecalendar", desc: "Google Calendar", appIcon: "icons/google-calendar.svg" },
	{ name: "mail", app: "Gmail", title: "Mail", icon: "gmail", desc: "Gmail", appIcon: "icons/gmail.svg", keywords: "email" },
	{ name: "tasks", app: "Google Tasks", title: "Tasks", icon: "googletasks", desc: "Google Tasks", appIcon: "icons/google-tasks.svg", keywords: "todo" },
	{ name: "whatsapp", app: "WhatsApp", title: "WhatsApp", icon: "whatsapp", desc: "Messages", appIcon: "icons/whatsapp.svg", keywords: "chat" },
	{ name: "spotify", app: "Spotify", title: "Spotify", icon: "spotify", desc: "Music", appIcon: "spotify", desktop: "com.spotify.Client" },
	{ name: "btop", app: "btop", title: "Activity Monitor", icon: "memory-stick", desc: "Processes, memory, CPU", appIcon: "utilities-system-monitor", desktop: "btop", inBar: false },
	{ name: "yazi", app: "Yazi", title: "Files", icon: "folder", desc: "File manager", appIcon: "system-file-manager", desktop: "yazi" },
	{ name: "jolt", app: "jolt", title: "Energy", icon: "zap", desc: "Battery and energy use", appIcon: "gnome-power-statistics" }
];

function find(name) {
	return list.find(s => s.name === name) ?? null;
}

// The special workspace that stands for desktop entry `id`, or null.
function byDesktopEntry(id) {
	return list.find(s => s.desktop !== undefined && s.desktop === id) ?? null;
}
