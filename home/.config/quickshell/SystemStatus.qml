// System status singleton: tracks global hardware and session state
// (memory, GPU, screen recording, screencast streams, awake, power-save).
// Prevents duplicate polling and process spawning across multiple monitors.
pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Singleton {
	id: root

	property int screencasts: 0
	property string memPercent: ""
	property string memTooltip: ""
	property string gpuDevicePath: ""
	property bool gpuActive: false
	property bool recording: false
	property bool dictating: false
	property string dictationState: "idle"

	readonly property bool awakeActive: awakeMarker.loaded
	readonly property bool powerSaveActive: powerSaveMarker.loaded
	readonly property bool dictatingActive: dictating || dictationState !== "idle" || dictationMarker.loaded

	function refresh(): void {
		gpuStatus.reload();
		awakeMarker.reload();
		powerSaveMarker.reload();
		dictationMarker.reload();
		memView.reload();
		recordProbe.running = true;
	}

	Connections {
		target: QuickSettings
		function onRefreshRequested() {
			root.refresh();
		}
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

	// 2s polling for fast lightweight checks (FileViews, no processes).
	Timer {
		interval: 2000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: {
			if (root.gpuDevicePath !== "")
				gpuStatus.reload();
			awakeMarker.reload();
			powerSaveMarker.reload();
			dictationMarker.reload();
		}
	}

	// 5s cadence for /proc/meminfo and pgrep wf-recorder.
	Timer {
		interval: 5000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: {
			memView.reload();
			if (!recordProbe.running)
				recordProbe.running = true;
		}
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
				root.memTooltip = "Memory: " + usedGb + " / " + totalGb + " GiB (" + root.memPercent + "%)";
			} else {
				root.memTooltip = "";
			}
		}
	}

	// Probe the dGPU's PCI device once at startup.
	Process {
		id: gpuProbe
		command: ["sh", "-c", "grep -lx 0x10de /sys/bus/pci/devices/*/vendor 2>/dev/null | head -1"]
		running: true
		stdout: StdioCollector {
			onStreamFinished: {
				var vendor = this.text.trim();
				if (vendor !== "") {
					root.gpuDevicePath = vendor.replace(/vendor$/, "") + "power/runtime_status";
					gpuStatus.reload();
				}
			}
		}
	}

	FileView {
		id: gpuStatus
		path: root.gpuDevicePath
		printErrors: false
		onLoaded: {
			var wasActive = root.gpuActive;
			var nowActive = this.text().trim() === "active";
			root.gpuActive = nowActive;
			if (wasActive && !nowActive) {
				restoreBacklightTimer.restart();
			}
		}
	}

	Timer {
		id: restoreBacklightTimer
		interval: 400
		repeat: false
		onTriggered: {
			restoreBacklightProc.running = false;
			restoreBacklightProc.running = true;
		}
	}

	Timer {
		id: bootBacklightTimer
		interval: 4000
		running: true
		repeat: false
		onTriggered: {
			restoreBacklightProc.running = false;
			restoreBacklightProc.running = true;
		}
	}

	Process {
		id: restoreBacklightProc
		command: ["restore-backlight"]
	}

	FileView {
		id: awakeMarker
		path: Quickshell.env("XDG_RUNTIME_DIR") + "/awake_inhibit.pid"
		printErrors: false
	}

	FileView {
		id: powerSaveMarker
		path: Quickshell.env("XDG_RUNTIME_DIR") + "/powersave_mode"
		printErrors: false
	}

	FileView {
		id: dictationMarker
		path: Quickshell.env("XDG_RUNTIME_DIR") + "/dictation.pid"
		printErrors: false
	}

	Process {
		id: recordProbe
		command: ["pgrep", "-x", "wf-recorder"]
		onExited: code => root.recording = code === 0
	}

	IpcHandler {
		target: "dictation"

		function start(): void {
			root.dictating = true;
			root.dictationState = "recording";
		}
		function transcribing(): void {
			root.dictating = true;
			root.dictationState = "transcribing";
		}
		function stop(): void {
			root.dictating = false;
			root.dictationState = "idle";
		}
		function toggle(): void {
			if (root.dictationState === "recording") {
				root.dictationState = "transcribing";
			} else if (root.dictationState === "transcribing") {
				root.dictating = false;
				root.dictationState = "idle";
			} else {
				root.dictating = true;
				root.dictationState = "recording";
			}
		}
	}
}
