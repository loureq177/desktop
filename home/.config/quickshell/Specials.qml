pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The specials as the shell shows them, from apply-apps (~/.config/apps/apps.json):
// `icon` is the bar's, `appIcon` the launcher's, `desktop` the app's desktop entry
// it replaces there, `player` its MPRIS player, `inBar: false` keeps it off the bar.
Singleton {
	id: root

	readonly property var list: {
		try {
			return JSON.parse(file.text()).specials ?? [];
		} catch (e) {
			return [];
		}
	}

	function find(name) {
		return list.find(s => s.name === name) ?? null;
	}

	// The special workspace that stands for desktop entry `id`, or null.
	function byDesktopEntry(id) {
		return list.find(s => s.desktop !== undefined && s.desktop === id) ?? null;
	}

	FileView {
		id: file
		path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/apps/apps.json"
		blockLoading: true
		printErrors: false
		watchChanges: true
		onFileChanged: reload()
	}
}
