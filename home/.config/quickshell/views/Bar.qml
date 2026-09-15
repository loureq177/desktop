// Status bar: one instance per screen (via shell.qml Variants).
// Fully transparent window; modules are floating translucent pills with
// hover highlights and click passthrough. Modules: workspaces / memory /
// dGPU / power-save on the left, clock centered, record / notifications /
// screenshare / caffeine / bluetooth / network / battery on the right.
// Clicks open the matching special workspaces.
import ".."
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
	id: bar

	required property var modelData
	readonly property string screenName: modelData?.name ?? ""

	// Active portal screencasts (screenshare privacy indicator), tracked
	// from Hyprland's screencastv2 events: "screencastv2>><state>,<type>".
	property int screencasts: 0

	screen: modelData
	color: "transparent"
	WlrLayershell.layer: WlrLayer.Top
	WlrLayershell.namespace: "quickshell-bar"

	anchors {
		top: true
		left: true
		right: true
	}
	margins {
		top: Theme.barMarginY
		left: Theme.barMarginX
		right: Theme.barMarginX
	}

	implicitHeight: Theme.barHeight

	Connections {
		target: Hyprland
		function onRawEvent(ev) {
			if (ev.name !== "screencastv2")
				return;
			var state = (String(ev.data ?? "").split(",")[0] === "1") ? 1 : 0;
			bar.screencasts = Math.max(0, bar.screencasts + (state === 1 ? 1 : -1));
		}
	}

	// ─── Native status data ─────────────────────────────────────────────
	// UPower/Networking push updates; the 2s poll timer covers state files
	// and /proc sources that have no notification mechanism.

	// UPower's aggregate DisplayDevice is broken on some machines (always
	// 0%); pick the real laptop battery from the device list instead.
	readonly property var batteryDevice: {
		var vals = UPower.devices.values;
		for (var i = 0; i < vals.length; i++)
			if (vals[i].isLaptopBattery && vals[i].isPresent)
				return vals[i];
		return null;
	}

	readonly property var wifiDevice: {
		var vals = Networking.devices.values;
		for (var i = 0; i < vals.length; i++)
			if (vals[i].type === DeviceType.Wifi)
				return vals[i];
		return null;
	}

	readonly property var wiredDevice: {
		var vals = Networking.devices.values;
		for (var i = 0; i < vals.length; i++)
			if (vals[i].type === DeviceType.Wired)
				return vals[i];
		return null;
	}

	// dGPU: PCI path probed once at startup, runtime_status re-read by the
	// poll timer (sysfs emits no change events for this file).
	property string gpuDevicePath: ""
	property bool gpuActive: false

	// 2s-polled states.
	property string memPercent: ""
	property bool recording: false

	// Cheap state files, polled at 2s: they are FileViews, no process spawns.
	Timer {
		interval: 2000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: {
			gpuStatus.reload();
			caffeineMarker.reload();
			powerSaveMarker.reload();
		}
	}

	// Slower cadence for the two expensive probes: reading /proc/meminfo and
	// spawning pgrep every 2s costs a process fork every two seconds forever,
	// and neither value moves fast enough to justify it.
	Timer {
		interval: 5000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: {
			memView.reload();
			recordProbe.running = true;
		}
	}

	// Memory: parse /proc/meminfo into a used-percentage string.
	FileView {
		id: memView
		path: "/proc/meminfo"
		onLoaded: {
			var t = this.text();
			var total = Number((t.match(/MemTotal:\s+(\d+)/) || [0, 0])[1]);
			var avail = Number((t.match(/MemAvailable:\s+(\d+)/) || [0, 0])[1]);
			bar.memPercent = (total > 0 && avail >= 0) ? String(Math.round((total - avail) * 100 / total)) : "";
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
				if (vendor !== "")
					bar.gpuDevicePath = vendor.replace(/vendor$/, "") + "power/runtime_status";
			}
		}
	}

	FileView {
		id: gpuStatus
		path: bar.gpuDevicePath
		printErrors: false
		onLoaded: bar.gpuActive = this.text().trim() === "active"
	}

	// Caffeine / power-save toggles leave marker files in XDG_RUNTIME_DIR;
	// their existence is the state (loadFailed = absent = off).
	FileView {
		id: caffeineMarker
		path: Quickshell.env("XDG_RUNTIME_DIR") + "/caffeine_inhibit.pid"
		printErrors: false
	}
	FileView {
		id: powerSaveMarker
		path: Quickshell.env("XDG_RUNTIME_DIR") + "/powersave_mode"
		printErrors: false
	}

	Process {
		id: recordProbe
		command: ["pgrep", "-x", "wf-recorder"]
		onExited: code => bar.recording = code === 0
	}

	// A bar module pill: translucent background, hover highlight, click
	// passthrough, wheel signal, Nerd Font label. Icon glyphs render in the
	// Propo family (Nerd Font Mono shrinks glyphs into the fixed cell,
	// which reads as "too small").
	component Pill: Rectangle {
		id: pill

		property string text: ""
		property string value: ""
		property color textColor: Theme.textMain
		signal activated()
		signal wheeled(bool up)

		implicitHeight: Theme.barHeight
		implicitWidth: (text !== "" || value !== "") ? pillRow.implicitWidth + Theme.barPad * 2 : 0
		visible: text !== "" || value !== ""
		color: pillArea.containsMouse ? Theme.bgHover : Theme.barStripColor
		radius: Theme.roundingElement

		Behavior on color {
			ColorAnimation { duration: 120 }
		}

		Row {
			id: pillRow
			anchors.centerIn: parent
			spacing: 7

			Text {
				anchors.verticalCenter: parent.verticalCenter
				visible: pill.text !== ""
				text: pill.text
				font.family: Theme.fontFamily
				font.pixelSize: Theme.fontSizeBarIcon
				font.bold: true
				color: pill.textColor
			}

			Text {
				anchors.verticalCenter: parent.verticalCenter
				visible: pill.value !== ""
				text: pill.value
				font.family: Theme.fontMono
				font.pixelSize: Theme.fontSizeBar
				font.bold: true
				color: pill.textColor
			}
		}

		MouseArea {
			id: pillArea
			anchors.fill: parent
			hoverEnabled: true
			onClicked: pill.activated()
			onWheel: w => pill.wheeled(w.angleDelta.y > 0)
		}
	}

	Item {
		anchors.fill: parent

		RowLayout {
			id: leftModules
			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			spacing: Theme.barSpacing

			// Workspaces of this monitor (specials always start with "special:").
			Repeater {
				model: {
					var ws = Hyprland.workspaces.values.filter(w => w.monitor?.name === bar.screenName && !String(w.name).startsWith("special:"));
					ws.sort((a, b) => a.id - b.id);
					return ws;
				}

				delegate: Rectangle {
					id: wsButton
					required property var modelData
					readonly property bool isActive: modelData.active

					Layout.alignment: Qt.AlignVCenter
					implicitHeight: Theme.barHeight
					implicitWidth: wsLabel.implicitWidth + Theme.paddingItem * 2
					color: wsArea.containsMouse ? Theme.bgHover : (isActive ? Theme.selectionBg : Theme.barStripColor)
					radius: Theme.roundingElement

					Behavior on color {
						ColorAnimation { duration: 120 }
					}

					Text {
						id: wsLabel
						anchors.centerIn: parent
						text: wsButton.modelData.name
						font.family: Theme.fontMono
						font.pixelSize: Theme.fontSizeBar
						font.bold: true
						color: wsButton.isActive ? Theme.accentBlue : Theme.textDim
					}

					MouseArea {
						id: wsArea
						anchors.fill: parent
						hoverEnabled: true
						onClicked: Quickshell.execDetached([
							"hyprctl", "dispatch", "hl.dsp.focus({workspace=" + wsButton.modelData.id + "})"
						])
					}
				}
			}

			Pill {
				visible: bar.memPercent !== ""
				text: "󰍛"
				value: bar.memPercent
				onActivated: Quickshell.execDetached([
					"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('btop')"
				])
			}

			Pill {
				visible: bar.gpuDevicePath !== ""
				text: "󰢮"
				textColor: bar.gpuActive ? Theme.accentGreen : Theme.textDim
			}

			Pill {
				text: "󰌪"
				textColor: powerSaveMarker.loaded ? Theme.accentGreen : Theme.textDim
				onActivated: Quickshell.execDetached(["sh", "-c", "~/.local/bin/power-save.sh"])
			}
		}

		Pill {
			id: clock
			anchors.centerIn: parent
			// SystemClock.date is the live timestamp; it is invalid until the
			// first tick boundary.
			readonly property bool valid: !isNaN(clockSource.date?.getTime?.() ?? NaN)
			value: valid ? Qt.formatDateTime(clockSource.date, "hh:mm") : Qt.formatDateTime(new Date(), "hh:mm")
			onActivated: Quickshell.execDetached([
				"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('calendar')"
			])

			SystemClock {
				id: clockSource
				precision: SystemClock.Minutes
			}
		}

		RowLayout {
			id: rightModules
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			spacing: Theme.barSpacing

			Pill {
				visible: bar.recording
				text: visible ? "●" : ""
				textColor: Theme.critical
				onActivated: Quickshell.execDetached(["sh", "-c", "~/.local/bin/record-screen.sh"])
			}

			Pill {
				// Notification indicator: reads the notification singleton
				// directly (no script/IPC round-trip).
				readonly property int count: Notifications.toasts.length
				readonly property bool dnd: Notifications.dnd

				text: dnd ? "󰂛" : (count > 0 ? "󰂚" : "󰂜")
				textColor: count > 0 && !dnd ? Theme.accentBlue : Theme.textDim
				onActivated: Notifications.toggle()
			}

			Pill {
				visible: bar.screencasts > 0
				text: visible ? "󰒎" : ""
				textColor: Theme.accentPurple
			}

			Pill {
				// Hidden while idle (previous script mode emitted empty text,
				// which collapsed the module — this only shows while active).
				visible: caffeineMarker.loaded
				text: visible ? "󰖦" : ""
				textColor: Theme.accentBlue
				onActivated: Quickshell.execDetached(["sh", "-c", "~/.local/bin/caffeine-toggle.sh"])
			}

			Pill {
				id: bluetooth
				readonly property var adapter: Bluetooth.defaultAdapter
				readonly property int connectedCount: {
					var a = adapter;
					if (!a)
						return 0;
					var n = 0;
					var vals = a.devices.values;
					for (var i = 0; i < vals.length; i++)
						if (vals[i].connected)
							n++;
					return n;
				}

				// Distinct from the notification bell glyphs (which share the
				// 󰂜 icon family); bluetooth uses the bluetooth family.
				text: connectedCount > 0 ? "󰂲" : "󰂯"
				textColor: connectedCount > 0 ? Theme.accentBlue : (adapter?.enabled ? Theme.textMain : Theme.textDim)
				onActivated: Quickshell.execDetached([
					"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('bluetui')"
				])
			}

			Pill {
				readonly property bool wifiUp: bar.wifiDevice?.connected ?? false
				readonly property bool wiredUp: bar.wiredDevice?.connected ?? false

				text: wifiUp ? "󰖩" : (wiredUp ? "󰈀" : "󰖪")
				textColor: (wifiUp || wiredUp) ? Theme.textMain : Theme.textDim
				onActivated: Quickshell.execDetached([
					"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('impala')"
				])
			}

			Pill {
				readonly property var device: bar.batteryDevice
				// Discharge icon bucket by 10% steps; 󰂄 charging, 󰁹 full.
				readonly property var bucketIcons: [
					"󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"
				]
				readonly property int pct: device ? Math.round(device.percentage * 100) : 0
				readonly property bool full: device && device.state === UPowerDeviceState.FullyCharged
				readonly property bool charging: device && (device.state === UPowerDeviceState.Charging
					|| device.state === UPowerDeviceState.PendingCharge)

				visible: device !== null
				text: charging ? "󰂄" : (full ? "󰁹" : bucketIcons[Math.min(10, Math.max(0, Math.floor(pct / 10)))])
				value: visible ? String(pct) : ""
				textColor: charging || full ? Theme.accentGreen
					: pct <= 10 ? Theme.critical
					: pct <= 30 ? Theme.warning
					: Theme.textMain
				onActivated: Quickshell.execDetached([
					"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('jolt')"
				])
			}
		}
	}
}
