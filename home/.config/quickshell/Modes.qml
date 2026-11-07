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
	readonly property bool recording: recordingMarker.loaded
	// "recording", "transcribing", or "" while it is off.
	readonly property string dictation: dictationMarker.loaded ? dictationMarker.state : ""
	property int screencasts: 0
	// The launcher's list of windows captures them, which is no sharing. Hyprland calls a
	// capture over half a second after its last frame, so that long past the list too.
	readonly property bool listingWindows: windowsOpen || windowsLeft.running
	readonly property bool windowsOpen: Panels.active === "launcher" && Panels.mode === "windows"
	onWindowsOpenChanged: {
		if (!windowsOpen)
			windowsLeft.restart();
	}
	// The countdown of ~/.local/bin/timer: seconds left, 0 while off.
	readonly property real timerStart: timerMarker.loaded ? timerMarker.start : 0
	readonly property real timerEnd: timerMarker.loaded ? timerMarker.end : 0
	property int timerLeft: 0
	readonly property real timerFraction: timerEnd > timerStart ? timerLeft / (timerEnd - timerStart) : 0
	// Just started, or a minute to go: said once over a fullscreen window too (Osd).
	signal timerMoment()

	function timerText(s: int): string {
		var h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60;
		var pad = n => (n < 10 ? "0" : "") + n;
		return (h > 0 ? h + ":" + pad(m) : m) + ":" + pad(s % 60);
	}

	function tickTimer(): void {
		var ms = timerEnd * 1000 - Date.now();
		var left = Math.max(0, Math.ceil(ms / 1000));
		if (left === 60 && timerLeft > 60 && timerEnd - timerStart > 120)
			timerMoment();
		timerLeft = left;
		if (left > 0) {
			timerTick.interval = ms % 1000 || 1000;
			timerTick.restart();
		}
	}

	onTimerEndChanged: {
		tickTimer();
		if (timerLeft > 0 && Date.now() / 1000 - timerStart < 5)
			timerMoment();
	}

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

	// On each whole second left.
	Timer {
		id: timerTick
		onTriggered: root.tickTimer()
	}

	Timer {
		id: windowsLeft
		interval: 600
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

	// For the schedule only: a restart would pass through neutral, hiding the change, so
	// hyprsunset-reload.timer restarts it before the night starts.
	Timer {
		id: nightLightSave
		interval: 500
		onTriggered: Quickshell.execDetached(["sed", "-i", "--follow-symlinks", "-E",
			"s/(temperature *= *)[0-9]+/\\1" + root.nightLightKelvin + "/", nightLightConfig.path])
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
		id: timerMarker

		property real start: 0
		property real end: 0

		path: root.runDir + "/timer"
		onLoaded: {
			var t = text().trim().split(" ");
			start = Number(t[0]) || 0;
			end = Number(t[1]) || 0;
		}
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

	// Ghostty's effects follow the power source. Also once the session is up.
	Connections {
		target: UPower
		function onOnBatteryChanged() {
			effectsSync.restart();
		}
	}

	Timer {
		id: effectsSync
		running: true
		onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/ghostty-effects"])
	}
}
