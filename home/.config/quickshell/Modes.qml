pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

// What the session's scripts switched on, from their files in $XDG_RUNTIME_DIR,
// plus screen sharing (Hyprland) and night light (hyprsunset).
Singleton {
	id: root

	readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR")
	readonly property bool batteryCareSupported: batteryCareMarker.loaded
	readonly property bool batteryCare: batteryCareMarker.loaded && batteryCareMarker.state === "on"
	readonly property bool awake: awakeMarker.loaded
	readonly property bool powerSave: powerSaveMarker.loaded
	readonly property bool recording: recordingMarker.loaded
	readonly property bool phoneCam: phoneCamMarker.loaded
	// "recording", "transcribing", or "" while it is off.
	readonly property string dictation: dictationMarker.loaded ? dictationMarker.state : ""
	property int screencasts: 0
	property bool nightLight: false
	// What the schedule turns it on at (hyprsunset.conf).
	property int nightLightKelvin: 4500

	function readNightLight(): void {
		if (!nightLightQuery.running)
			nightLightQuery.running = true;
	}

	// Off reads back 6000 K.
	function nightLightCommand(): string {
		return nightLight ? "hyprctl hyprsunset temperature " + nightLightKelvin
			: "hyprctl hyprsunset temperature 6000 && hyprctl hyprsunset identity";
	}

	// Until the schedule's next change.
	function toggleNightLight(): void {
		nightLight = !nightLight;
		Quickshell.execDetached(["sh", "-c", nightLightCommand()]);
	}

	// On at once; kept for the schedule once the slider rests.
	function setNightLightKelvin(kelvin: int): void {
		if (kelvin === nightLightKelvin && nightLight)
			return;
		nightLight = true;
		nightLightKelvin = kelvin;
		Quickshell.execDetached(["sh", "-c", nightLightCommand()]);
		nightLightSave.restart();
	}

	Process {
		id: nightLightQuery
		command: ["hyprctl", "hyprsunset", "temperature"]
		stdout: StdioCollector {
			onStreamFinished: root.nightLight = parseInt(this.text) < 6000
		}
	}

	FileView {
		id: nightLightConfig
		path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hypr/hyprsunset.conf"
		printErrors: false
		onLoaded: {
			var found = /temperature\s*=\s*(\d+)/.exec(text());
			if (found)
				root.nightLightKelvin = parseInt(found[1]);
		}
	}

	// hyprsunset reads its schedule only as it starts, which also sets the screen by it:
	// what is on now goes back on, once its socket is up.
	Timer {
		id: nightLightSave
		interval: 500
		onTriggered: Quickshell.execDetached(["sh", "-c",
			"sed -i --follow-symlinks -E 's/(temperature *= *)[0-9]+/\\1" + root.nightLightKelvin + "/' '" + nightLightConfig.path + "'"
			+ " && systemctl --user try-restart hyprsunset; sleep 0.5; " + root.nightLightCommand()])
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
		id: phoneCamMarker
		path: root.runDir + "/phone_cam"
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
