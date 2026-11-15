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
	// Its strength in percent, 5500 K the weakest, 2500 K the strongest.
	readonly property int nightLightStrength: Math.round((5500 - nightLightKelvin) / 30)
	// When the schedule turns it on and off ("20:00", "6:00"); hyprsunset.conf.example's by default.
	property string nightStart: defaultNightStart
	property string dayStart: defaultDayStart
	readonly property string defaultNightStart: "20:00"
	readonly property string defaultDayStart: "6:00"
	// hyprsunset reads its schedule only as it starts, and a restart passes through neutral:
	// a change waits for a neutral screen.
	property bool reloadPending: false

	function setSchedule(on: string, off: string): void {
		var profile = /profile\s*\{[^}]*\}/g;
		var text = nightLightConfig.text().replace(profile, p => p.replace(/time\s*=\s*[0-9:]+/, "time = " + (/identity\s*=\s*true/.test(p) ? off : on)));
		nightStart = on;
		dayStart = off;
		nightLightConfig.setText(text);
		reloadPending = true;
		reloadWhenNeutral.restart();
	}

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
		blockLoading: true
		printErrors: false
		// In place: it may be a link into the machine's own files.
		atomicWrites: false
		onLoaded: {
			var found = /temperature\s*=\s*(\d+)/.exec(text());
			if (found)
				root.nightLightKelvin = parseInt(found[1]);
			for (const p of text().match(/profile\s*\{[^}]*\}/g) ?? []) {
				var time = /time\s*=\s*([0-9]{1,2}:[0-9]{2})/.exec(p);
				if (time && /identity\s*=\s*true/.test(p))
					root.dayStart = time[1].replace(/^0(\d)/, "$1");
				else if (time)
					root.nightStart = time[1].replace(/^0(\d)/, "$1");
			}
		}
	}

	Timer {
		id: reloadWhenNeutral
		interval: 1000
		repeat: true
		running: root.reloadPending
		onTriggered: {
			if (root.nightLight)
				return;
			root.reloadPending = false;
			Quickshell.execDetached(["systemctl", "--user", "try-restart", "hyprsunset.service"]);
		}
	}

	// For the schedule only: a restart would pass through neutral, hiding the change, so
	// hyprsunset-reload.timer restarts it before the night starts.
	Timer {
		id: nightLightSave
		interval: 500
		onTriggered: {
			nightLightConfig.setText(nightLightConfig.text().replace(/(temperature\s*=\s*)[0-9]+/, "$1" + root.nightLightKelvin));
			root.reloadPending = true;
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
