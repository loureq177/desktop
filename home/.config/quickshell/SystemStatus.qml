pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick

Singleton {
	id: root

	property int screencasts: 0
	property string memPercent: ""
	property string memTooltip: ""
	property string gpuDevicePath: ""
	property string gpuRuntimeStatus: ""
	property string dictationState: "idle"
	// Backlight in percent: -1 until it is read, and for good without a backlight.
	property int brightness: -1

	readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR")
	// The scripts behind these leave a file in runDir while they are on.
	readonly property bool awakeActive: awakeMarker.loaded
	readonly property bool powerSaveActive: powerSaveMarker.loaded
	readonly property bool recording: recordingMarker.loaded
	readonly property bool dictatingActive: dictationState !== "idle" || dictationMarker.loaded
	// Translucency costs GPU time: AC power only, and never in power-save,
	// which also turns Hyprland's blur off (see ghostty_candy in power-save).
	readonly property bool glass: !UPower.onBattery && !powerSaveActive

	readonly property var batteryDevice: UPower.devices.values.find(d => d.isLaptopBattery && d.isPresent) ?? null
	readonly property var wifiDevice: networkDevice(DeviceType.Wifi)
	readonly property var wiredDevice: networkDevice(DeviceType.Wired)

	// The default output and input. Their `audio` has the volume (0..1) and
	// mute; it holds real values once the node is `ready`.
	readonly property PwNode sink: Pipewire.defaultAudioSink
	readonly property PwNode source: Pipewire.defaultAudioSource

	function networkDevice(type): var {
		return Networking.devices.values.find(d => d.type === type) ?? null;
	}

	function readBrightness(): void {
		if (!briQuery.running)
			briQuery.running = true;
	}

	// Writes right away, then once more when a burst of calls (a slider drag)
	// settles, so the last value is the one that sticks.
	function setBrightness(percent: real): void {
		root.brightness = Math.max(0, Math.min(100, Math.round(percent)));
		if (!briSettle.running)
			root.writeBrightness();
		briSettle.restart();
	}

	function writeBrightness(): void {
		briSet.command = ["brightnessctl", "-q", "-c", "backlight", "set", root.brightness + "%"];
		briSet.running = true;
	}

	PwObjectTracker {
		objects: [root.sink, root.source].filter(n => n)
	}

	Connections {
		target: Hyprland
		function onRawEvent(ev) {
			if (ev.name !== "screencastv2")
				return;
			var state = (String(ev.data ?? "").split(",")[0] === "1") ? 1 : 0;
			root.screencasts = Math.max(0, root.screencasts + (state === 1 ? 1 : -1));
		}
	}

	// power-save follows the power source: AC ends power-save mode, and
	// Ghostty's effects switch with it. Also run once the session is up.
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

	Timer {
		interval: 5000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: memView.reload()
	}

	FileView {
		id: memView
		path: "/proc/meminfo"
		onLoaded: {
			var t = this.text();
			var total = Number((t.match(/MemTotal:\s+(\d+)/) || [0, 0])[1]);
			var avail = Number((t.match(/MemAvailable:\s+(\d+)/) || [0, 0])[1]);
			root.memPercent = (total > 0 && avail >= 0) ? String(Math.round((total - avail) * 100 / total)) : "";
			if (total > 0 && avail >= 0) {
				var usedGb = ((total - avail) / 1048576).toFixed(1);
				var totalGb = (total / 1048576).toFixed(1);
				root.memTooltip = usedGb + " / " + totalGb + " GiB";
			} else {
				root.memTooltip = "";
			}
		}
	}

	Process {
		id: gpuProbe
		command: ["sh", "-c", "grep -lx 0x10de /sys/bus/pci/devices/*/vendor 2>/dev/null | head -1"]
		running: true
		stdout: StdioCollector {
			onStreamFinished: {
				var vendor = this.text.trim();
				if (vendor !== "")
					root.gpuDevicePath = vendor.replace(/vendor$/, "") + "power/runtime_status";
			}
		}
	}

	// sysfs sends no change events for this file: poll it.
	Timer {
		interval: 2000
		running: root.gpuDevicePath !== ""
		repeat: true
		triggeredOnStart: true
		onTriggered: gpuStatus.reload()
	}

	FileView {
		id: gpuStatus
		path: root.gpuDevicePath
		printErrors: false
		onLoaded: {
			var before = root.gpuRuntimeStatus;
			var now = this.text().trim();
			root.gpuRuntimeStatus = now;
			// The panel dims when the power is cut, which is the end of
			// "suspending", not its start.
			if (before !== "" && before !== "suspended" && now === "suspended")
				restoreBacklightTimer.restart();
		}
	}

	Timer {
		id: restoreBacklightTimer
		interval: 400
		onTriggered: {
			restoreBacklightProc.running = false;
			restoreBacklightProc.running = true;
		}
	}

	Timer {
		id: bootBacklightTimer
		interval: 4000
		running: true
		onTriggered: {
			restoreBacklightProc.running = false;
			restoreBacklightProc.running = true;
		}
	}

	Process {
		id: restoreBacklightProc
		command: ["restore-backlight"]
	}

	Process {
		id: briQuery
		command: ["sh", "-c", "brightnessctl -c backlight -m 2>/dev/null | head -n 1 | cut -d, -f4 | tr -dc '0-9'"]
		stdout: StdioCollector {
			onStreamFinished: {
				var v = parseInt(String(this.text || "").trim());
				if (!isNaN(v))
					root.brightness = Math.max(0, Math.min(100, v));
			}
		}
	}

	Process {
		id: briSet
	}

	Timer {
		id: briSettle
		interval: 60
		onTriggered: root.writeBrightness()
	}

	FileView {
		id: awakeMarker
		path: root.runDir + "/awake_inhibit.pid"
		printErrors: false
		watchChanges: true
		onFileChanged: reload()
	}

	FileView {
		id: powerSaveMarker
		path: root.runDir + "/powersave_mode"
		printErrors: false
		watchChanges: true
		onFileChanged: reload()
	}

	FileView {
		id: dictationMarker
		path: root.runDir + "/dictation.pid"
		printErrors: false
		watchChanges: true
		onFileChanged: reload()
	}

	FileView {
		id: recordingMarker
		path: root.runDir + "/recording_status"
		printErrors: false
		watchChanges: true
		onFileChanged: reload()
	}

	IpcHandler {
		target: "dictation"

		function start(): void {
			root.dictationState = "recording";
		}
		function transcribing(): void {
			root.dictationState = "transcribing";
		}
		function stop(): void {
			root.dictationState = "idle";
		}
	}
}
