.pragma library

// The special workspaces of hyprland.lua (`specials`, by the same names), as
// the shell shows them. `app` is the program's own name, which the launcher
// lists with `title` (or `desc`, when the two are the same) under it; `icon`
// is the bar's line icon and `appIcon` the launcher's: one of the shell's own
// (icons/, the web apps') or a theme icon, after that of `desktop`, the desktop
// entry of the same app, which the launcher lists as the special instead.
// `inBar: false` keeps it off the bar's row of specials (btop: the memory
// readout stands for it).
var list = [
	{ name: "calendar", app: "Google Calendar", title: "Calendar", icon: "calendar", desc: "Google Calendar", appIcon: "icons/google-calendar.svg", keywords: "google kalendarz" },
	{ name: "mail", app: "Gmail", title: "Mail", icon: "mail", desc: "Gmail", appIcon: "icons/gmail.svg", keywords: "gmail email poczta" },
	{ name: "tasks", app: "Google Tasks", title: "Tasks", icon: "circle-check", desc: "Google Tasks", appIcon: "icons/google-tasks.svg", keywords: "google todo zadania" },
	{ name: "whatsapp", app: "WhatsApp", title: "WhatsApp", icon: "message-circle", desc: "Messages", appIcon: "icons/whatsapp.svg", keywords: "chat messages wiadomości" },
	{ name: "spotify", app: "Spotify", title: "Spotify", icon: "audio-lines", desc: "Music", appIcon: "spotify", desktop: "com.spotify.Client", keywords: "music muzyka" },
	{ name: "btop", app: "btop", title: "Activity Monitor", icon: "memory-stick", desc: "Processes, memory, CPU", appIcon: "utilities-system-monitor", desktop: "btop", inBar: false, keywords: "btop top processes procesy memory pamięć cpu" },
	{ name: "yazi", app: "Yazi", title: "Files", icon: "folder", desc: "File manager", appIcon: "system-file-manager", desktop: "yazi", keywords: "yazi file manager pliki" },
	{ name: "jolt", app: "jolt", title: "Energy", icon: "zap", desc: "Battery and energy use", appIcon: "gnome-power-statistics", keywords: "jolt battery power usage bateria energia zużycie" }
];

function find(name) {
	return list.find(s => s.name === name) ?? null;
}

// The special workspace that stands for desktop entry `id`, or null.
function byDesktopEntry(id) {
	return list.find(s => s.desktop !== undefined && s.desktop === id) ?? null;
}
