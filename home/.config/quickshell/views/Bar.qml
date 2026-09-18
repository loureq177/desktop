// Status bar: one instance per screen (via shell.qml Variants).
// Fully transparent, minimal bar with clean hover highlights,
// hand cursors, and click passthrough.
// Layout: workspaces / memory / dGPU / power-save on the left,
// minimal time centered, record / screenshare / caffeine / bluetooth /
// network / battery / notification center on the right.
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

	// 2s/5s-polled states.
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

	// Slower cadence for /proc/meminfo and pgrep wf-recorder.
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

	// ─── Reusable Pill component ─────────────────────────────────────────
	// Minimal, borderless, transparent background with smooth hover feedback.
	component Pill: Rectangle {
		id: pill

		property string text: ""
		property string value: ""
		property color textColor: Theme.textMain
		property bool isActive: false
		property alias containsMouse: pillArea.containsMouse
		signal activated()
		signal wheeled(bool up)

		Layout.alignment: Qt.AlignVCenter
		implicitHeight: Theme.barHeight
		implicitWidth: (text !== "" || value !== "") ? pillRow.implicitWidth + 14 : 0
		visible: text !== "" || value !== ""
		color: pillArea.containsMouse ? Theme.bgHover : (isActive ? Qt.rgba(Theme.accentBlue.r, Theme.accentBlue.g, Theme.accentBlue.b, 0.16) : "transparent")
		border.width: 0
		radius: Theme.roundingElement

		Behavior on color {
			ColorAnimation { duration: 120 }
		}

		Row {
			id: pillRow
			anchors.centerIn: parent
			spacing: (pill.text !== "" && pill.value !== "") ? 6 : 0

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
			cursorShape: Qt.PointingHandCursor
			onClicked: pill.activated()
			onWheel: w => pill.wheeled(w.angleDelta.y > 0)
		}
	}

	Item {
		anchors.fill: parent

		// ─── Left zone: Workspaces + System Resources ─────────────────────
		RowLayout {
			id: leftModules
			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			spacing: 6

			// Workspaces container with wheel switching
			Rectangle {
				id: wsContainer
				Layout.alignment: Qt.AlignVCenter
				implicitHeight: Theme.barHeight
				implicitWidth: wsRow.implicitWidth
				color: "transparent"

				RowLayout {
					id: wsRow
					anchors.fill: parent
					spacing: 2

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
							implicitWidth: wsLabel.implicitWidth + 14
							color: wsArea.containsMouse ? Theme.bgHover : (isActive ? Qt.rgba(Theme.accentBlue.r, Theme.accentBlue.g, Theme.accentBlue.b, 0.18) : "transparent")
							border.width: 0
							radius: Theme.roundingElement

							Behavior on color { ColorAnimation { duration: 120 } }

							Text {
								id: wsLabel
								anchors.centerIn: parent
								text: wsButton.modelData.name
								font.family: Theme.fontMono
								font.pixelSize: Theme.fontSizeBar
								font.bold: true
								color: wsButton.isActive ? Theme.accentBlue : (wsArea.containsMouse ? Theme.textMain : Theme.textDim)
							}

							MouseArea {
								id: wsArea
								anchors.fill: parent
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onClicked: Quickshell.execDetached([
									"hyprctl", "dispatch", "hl.dsp.focus({workspace=" + wsButton.modelData.id + "})"
								])
							}
						}
					}
				}

				MouseArea {
					anchors.fill: parent
					acceptedButtons: Qt.NoButton
					onWheel: w => {
						if (w.angleDelta.y > 0)
							Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({workspace='+1'})"]);
						else
							Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({workspace='-1'})"]);
					}
				}
			}

			// Memory / RAM pill
			Pill {
				visible: bar.memPercent !== ""
				text: "󰍛"
				value: bar.memPercent !== "" ? bar.memPercent + "%" : ""
				textColor: Number(bar.memPercent) >= 90 ? Theme.critical : (Number(bar.memPercent) >= 75 ? Theme.warning : Theme.textDim)
				onActivated: Quickshell.execDetached([
					"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('btop')"
				])
			}

			// dGPU pill (NVIDIA) - minimal, icon-only, no "active" text
			Pill {
				visible: bar.gpuDevicePath !== ""
				text: "󰢮"
				value: ""
				textColor: bar.gpuActive ? Theme.accentGreen : Theme.textDim
				onActivated: Quickshell.execDetached([
					"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('btop')"
				])
			}

			// Power-save mode pill
			Pill {
				text: "󰌪"
				textColor: powerSaveMarker.loaded ? Theme.accentGreen : Theme.textDim
				onActivated: Quickshell.execDetached(["sh", "-c", "~/.local/bin/power-save.sh"])
			}
		}

		// ─── Center zone: Minimal Time (no date, no calendar icon) ────────
		Pill {
			id: clock
			anchors.centerIn: parent
			readonly property bool valid: !isNaN(clockSource.date?.getTime?.() ?? NaN)
			text: ""
			value: valid ? Qt.formatDateTime(clockSource.date, "hh:mm") : Qt.formatDateTime(new Date(), "hh:mm")
			textColor: Theme.textMain
			onActivated: Quickshell.execDetached([
				"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('calendar')"
			])

			SystemClock {
				id: clockSource
				precision: SystemClock.Minutes
			}
		}

		// ─── Right zone: Tray / Status ────────────────────────────────────
		RowLayout {
			id: rightModules
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			spacing: 6

			// Screen recording indicator
			Pill {
				visible: bar.recording
				text: "●"
				value: "REC"
				textColor: Theme.critical
				isActive: true
				onActivated: Quickshell.execDetached(["sh", "-c", "~/.local/bin/record-screen.sh"])
			}

			// Screencast indicator
			Pill {
				visible: bar.screencasts > 0
				text: "󰒎"
				textColor: Theme.accentPurple
				isActive: true
			}

			// Caffeine toggle indicator
			Pill {
				visible: caffeineMarker.loaded
				text: "󰖦"
				textColor: Theme.accentBlue
				onActivated: Quickshell.execDetached(["sh", "-c", "~/.local/bin/caffeine-toggle.sh"])
			}

			// Bluetooth indicator
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

				text: connectedCount > 0 ? "󰂲" : (adapter?.enabled ? "󰂯" : "󰂲")
				value: connectedCount > 1 ? String(connectedCount) : ""
				textColor: connectedCount > 0 ? Theme.accentBlue : (adapter?.enabled ? Theme.textMain : Theme.textDim)
				onActivated: Quickshell.execDetached([
					"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('bluetui')"
				])
			}

			// Network indicator (Wifi / Ethernet)
			Pill {
				readonly property bool wifiUp: bar.wifiDevice?.connected ?? false
				readonly property bool wiredUp: bar.wiredDevice?.connected ?? false

				text: wifiUp ? "󰖩" : (wiredUp ? "󰈀" : "󰖪")
				textColor: (wifiUp || wiredUp) ? Theme.textMain : Theme.textDim
				onActivated: Quickshell.execDetached([
					"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('impala')"
				])
			}

			// Battery indicator
			Pill {
				readonly property var device: bar.batteryDevice
				readonly property var bucketIcons: [
					"󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"
				]
				readonly property int pct: device ? Math.round(device.percentage * 100) : 0
				readonly property bool full: device && device.state === UPowerDeviceState.FullyCharged
				readonly property bool charging: device && (device.state === UPowerDeviceState.Charging
					|| device.state === UPowerDeviceState.PendingCharge)

				visible: device !== null
				text: charging ? "󰂄" : (full ? "󰁹" : bucketIcons[Math.min(10, Math.max(0, Math.floor(pct / 10)))])
				value: visible ? String(pct) + "%" : ""
				textColor: charging || full ? Theme.accentGreen
					: pct <= 10 ? Theme.critical
					: pct <= 30 ? Theme.warning
					: Theme.textMain
				onActivated: Quickshell.execDetached([
					"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('jolt')"
				])
			}

			// Notification center toggle bell
			Pill {
				readonly property int unreadCount: Notifications.toasts.length
				readonly property int historyCount: Notifications.history.length
				readonly property bool dnd: Notifications.dnd
				readonly property bool isOpen: Notifications.centerOpen

				text: dnd ? "󰂛" : (unreadCount > 0 ? "󰂚" : (historyCount > 0 ? "󰂚" : "󰂜"))
				value: !dnd && unreadCount > 0 ? String(unreadCount) : (!dnd && historyCount > 0 ? String(historyCount) : "")
				textColor: dnd ? Theme.warning : (unreadCount > 0 || isOpen ? Theme.accentBlue : (historyCount > 0 ? Theme.textMain : Theme.textDim))
				isActive: isOpen || (unreadCount > 0 && !dnd)
				onActivated: Notifications.toggle()
			}
		}
	}
}