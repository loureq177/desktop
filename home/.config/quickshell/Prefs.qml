pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The shell's own choices, changed in its settings (SUPER + S) and kept in prefs.json;
// a key left out is the default below. Read as the shell starts: its own writes only.
Singleton {
	id: root

	readonly property var values: adapter
	readonly property var defaults: ({
		// A panel's shortcut (Panels.qml), or "" for none.
		cornerLeft: "launcher-apps",
		cornerRight: "actions",
		batteryPercent: false,
		weather: true,
		clock24: true,
		clockSeconds: false,
		clockWeekday: false
	})

	function set(key: string, value: var): void {
		adapter[key] = value;
		file.writeAdapter();
	}

	function reset(key: string): void {
		set(key, defaults[key]);
	}

	function resetAll(): void {
		for (const k of Object.keys(defaults))
			adapter[k] = defaults[k];
		file.writeAdapter();
	}

	function changed(key: string): bool {
		return adapter[key] !== defaults[key];
	}

	FileView {
		id: file
		path: Quickshell.env("HOME") + "/.config/quickshell/prefs.json"
		blockLoading: true
		printErrors: false

		JsonAdapter {
			id: adapter

			property string cornerLeft: root.defaults.cornerLeft
			property string cornerRight: root.defaults.cornerRight
			property bool batteryPercent: root.defaults.batteryPercent
			property bool weather: root.defaults.weather
			property bool clock24: root.defaults.clock24
			property bool clockSeconds: root.defaults.clockSeconds
			property bool clockWeekday: root.defaults.clockWeekday
		}
	}
}
