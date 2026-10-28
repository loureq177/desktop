pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

// What the session's scripts have switched on. Each leaves a file in
// $XDG_RUNTIME_DIR while it is on: awake-toggle, power-save, record-screen and
// dictation, which writes what it is doing into its own. battery-care writes
// "on" or "off", and nothing where the battery has no charge limit. The
// screens being shared, which Hyprland reports. And night light, which
// hyprsunset tells when asked: its schedule (hyprsunset.conf) changes it too.
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
	property bool nightLight: false

	function readNightLight(): void {
		if (!nightLightQuery.running)
			nightLightQuery.running = true;
	}

	// Until the schedule's next change; 4500 K as in hyprsunset.conf. Off
	// reads back 6000 K, as hyprsunset's identity profile does: `identity`
	// alone leaves the warm temperature to be read.
	function toggleNightLight(): void {
		nightLight = !nightLight;
		Quickshell.execDetached(["sh", "-c", nightLight ? "hyprctl hyprsunset temperature 4500"
			: "hyprctl hyprsunset temperature 6000 && hyprctl hyprsunset identity"]);
	}

	Process {
		id: nightLightQuery
		command: ["hyprctl", "hyprsunset", "temperature"]
		stdout: StdioCollector {
			onStreamFinished: root.nightLight = parseInt(this.text) < 6000
		}
	}

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
	Component.onCompleted: {
		Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/battery-care", "--sync"]);
		readNightLight();
	}

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
		running: true
		onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/power-save", "--sync"])
	}
}
