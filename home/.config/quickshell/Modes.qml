pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

// What the session's scripts have switched on. Each leaves a file in
// $XDG_RUNTIME_DIR while it is on: awake-toggle, power-save, record-screen and
// dictation, which writes what it is doing into its own. battery-care writes
// "on" or "off", and nothing where the battery has no charge limit. And the
// screens being shared, which Hyprland reports.
Singleton {
	id: root

	readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR")
	readonly property bool batteryCareSupported: batteryCareMarker.loaded
	readonly property bool batteryCare: batteryCareMarker.loaded && batteryCareMarker.state === "on"
	readonly property bool awake: awakeMarker.loaded
	readonly property bool powerSave: powerSaveMarker.loaded
	readonly property bool recording: recordingMarker.loaded
	// "recording", "transcribing", or "" while it is off.
	readonly property string dictation: dictationMarker.loaded ? dictationMarker.state : ""
	property int screencasts: 0

	component Marker: FileView {
		printErrors: false
		watchChanges: true
		onFileChanged: reload()
	}

	Marker {
		id: awakeMarker
		path: root.runDir + "/awake_inhibit.pid"
	}

	Marker {
		id: powerSaveMarker
		path: root.runDir + "/powersave_mode"
	}

	Marker {
		id: recordingMarker
		path: root.runDir + "/recording_status"
	}

	Marker {
		id: dictationMarker

		property string state: ""

		path: root.runDir + "/dictation"
		onLoaded: state = text().trim()
	}

	Marker {
		id: batteryCareMarker

		property string state: ""

		path: root.runDir + "/battery_care"
		onLoaded: state = text().trim()
	}

	// UPower keeps the charge limit across reboots; the marker is per session.
	Component.onCompleted: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/battery-care", "--sync"])

	Connections {
		target: Hyprland
		function onRawEvent(ev) {
			if (ev.name !== "screencastv2")
				return;
			var on = String(ev.data ?? "").split(",")[0] === "1";
			root.screencasts = Math.max(0, root.screencasts + (on ? 1 : -1));
		}
	}

	// power-save follows the power source: AC ends power-save mode, and
	// Ghostty's effects switch with it. Also once the session is up.
	Connections {
		target: UPower
		function onOnBatteryChanged() {
			powerSync.restart();
		}
	}

	Timer {
		id: powerSync
		interval: 1000
		running: true
		onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/power-save", "--sync"])
	}
}
