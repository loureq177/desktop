pragma Singleton
import Quickshell
import Quickshell.Bluetooth
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
	readonly property int batteryPct: batteryDevice ? Math.round(batteryDevice.percentage * 100) : 0
	readonly property bool batteryFull: batteryDevice?.state === UPowerDeviceState.FullyCharged
	readonly property bool charging: batteryDevice?.state === UPowerDeviceState.Charging || batteryDevice?.state === UPowerDeviceState.PendingCharge
	// Green while charging, then warning and critical as it runs down.
	readonly property color batteryTint: charging ? Theme.accentGreen
		: batteryPct <= 10 ? Theme.critical
		: batteryPct <= 20 ? Theme.warning
		: Theme.textMain
	readonly property string batterySummary: {
		if (!batteryDevice)
			return "";
		if (charging)
			return "Battery: " + batteryPct + "% (Charging" + (batteryDevice.timeToFull > 0 ? ", " + duration(batteryDevice.timeToFull) + " to full" : "") + ")";
		if (batteryFull)
			return "Battery: " + batteryPct + "% (Fully charged)";
		return "Battery: " + batteryPct + "%" + (batteryDevice.timeToEmpty > 0 ? " (" + duration(batteryDevice.timeToEmpty) + " remaining)" : "");
	}

	readonly property var wifiDevice: networkDevice(DeviceType.Wifi)
	readonly property var wiredDevice: networkDevice(DeviceType.Wired)
	readonly property bool wifiUp: wifiDevice?.connected ?? false
	readonly property bool wiredUp: wiredDevice?.connected ?? false
	readonly property bool online: wifiUp || wiredUp
	readonly property string netIcon: wifiUp ? "wifi" : (wiredUp ? "ethernet-port" : "wifi-off")
	// The network the Wi-Fi is on, or null.
	readonly property var wifiNetwork: (wifiDevice?.networks?.values ?? []).find(n => n?.connected) ?? null
	readonly property string wifiStatus: !Networking.wifiHardwareEnabled ? "Blocked"
		: !Networking.wifiEnabled ? "Off"
		: wifiNetwork?.name || (wifiUp ? "On" : "No connection")
	readonly property string netSummary: {
		if (wifiUp) {
			var signal = Math.round(signalPercent(wifiNetwork));
			return "Wi-Fi: " + (wifiNetwork?.name || "Connected") + (signal > 0 ? " (" + signal + "%)" : "");
		}
		return wiredUp ? "Ethernet: Connected" : "Network: Disconnected";
	}

	readonly property var btAdapter: Bluetooth.defaultAdapter
	readonly property bool btEnabled: btAdapter?.enabled ?? false
	readonly property var btConnected: (btAdapter?.devices?.values ?? []).filter(d => d.connected)
	readonly property string btIcon: !btEnabled ? "bluetooth-off" : (btConnected.length > 0 ? "bluetooth-connected" : "bluetooth")
	readonly property string btStatus: !btAdapter ? "No adapter"
		: btConnected.length > 1 ? btConnected.length + " connected"
		: btConnected.length === 1 ? deviceName(btConnected[0])
		: btEnabled ? "On" : "Off"
	readonly property string btSummary: {
		if (!btAdapter)
			return "Bluetooth: Unavailable";
		if (!btEnabled)
			return "Bluetooth: Off";
		if (btConnected.length === 0)
			return "Bluetooth: Disconnected";
		return "Bluetooth: " + btConnected.map(d => deviceName(d) + (d.batteryAvailable && d.battery >= 0 ? " (" + Math.round(d.battery * 100) + "%)" : "")).join(", ");
	}

	// The default output and input. Their `audio` has the volume (0..1) and
	// mute; it holds real values once the node is `ready`.
	readonly property PwNode sink: Pipewire.defaultAudioSink
	readonly property PwNode source: Pipewire.defaultAudioSource
	readonly property bool volumeReady: sink?.ready ?? false
	readonly property bool muted: sink?.audio?.muted ?? false
	readonly property int volume: Math.round(Math.min(1, sink?.audio?.volume ?? 0) * 100)

	function volumeIcon(pct: int, isMuted: bool): string {
		return isMuted ? "volume-x" : pct <= 1 ? "volume" : pct <= 50 ? "volume-1" : "volume-2";
	}

	function setVolume(pct: real): void {
		if (!sink?.audio)
			return;
		sink.audio.volume = Math.max(0, Math.min(100, Math.round(pct))) / 100;
		volumeSound.restart();
	}

	function toggleMute(): void {
		if (sink?.audio)
			sink.audio.muted = !sink.audio.muted;
	}

	function toggleWifi(): void {
		if (Networking.wifiHardwareEnabled)
			Networking.wifiEnabled = !Networking.wifiEnabled;
	}

	function toggleBluetooth(): void {
		if (btAdapter)
			btAdapter.enabled = !btEnabled;
	}

	function networkDevice(type): var {
		return Networking.devices.values.find(d => d.type === type) ?? null;
	}

	// A network's signal in percent. NetworkManager reports a 0..1
	// fraction, some backends already a percentage.
	function signalPercent(net): real {
		var s = net?.signalStrength ?? 0;
		return s > 1 ? s : s * 100;
	}

	// What a Bluetooth device calls itself, falling back to its address.
	function deviceName(d): string {
		return d.name || d.deviceName || d.address;
	}

	// How long until `seconds` run out: "1h 5m".
	function duration(seconds: real): string {
		return Math.floor(seconds / 3600) + "h " + Math.floor((seconds % 3600) / 60) + "m";
	}

	// One click once a drag or a run of key presses settles.
	Timer {
		id: volumeSound
		interval: 120
		onTriggered: {
			if (!root.muted)
				Quickshell.execDetached(["canberra-gtk-play", "-i", "audio-volume-change"]);
		}
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
		onTriggered: Quickshell.execDetached([Commands.bin + "power-save", "--sync"])
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
