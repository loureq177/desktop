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

	// ─── Tooltip popup ───────────────────────────────────────────────────
	property Item tooltipTarget: null
	property string tooltipText: ""
	property bool tooltipVisible: false

	function showTooltip(item: Item, text: string): void {
		if (!text) {
			hideTooltip(item);
			return;
		}
		hideTimer.stop();
		tooltipTarget = item;
		tooltipText = text;
		if (tooltipVisible) {
			tipPop.visible = true;
			tipPop.anchor.updateAnchor();
		} else {
			tipTimer.restart();
		}
	}

	function hideTooltip(item: Item): void {
		if (tooltipTarget === item) {
			tipTimer.stop();
			hideTimer.restart();
		}
	}

	function updateTooltip(item: Item, text: string): void {
		if (tooltipTarget === item) {
			tooltipText = text;
			if (tipPop.visible)
				tipPop.anchor.updateAnchor();
		}
	}

	Timer {
		id: tipTimer
		interval: 300
		onTriggered: {
			if (bar.tooltipTarget && bar.tooltipText !== "") {
				bar.tooltipVisible = true;
				tipPop.visible = true;
				tipPop.anchor.updateAnchor();
			}
		}
	}

	Timer {
		id: hideTimer
		interval: 100
		onTriggered: {
			bar.tooltipTarget = null;
			bar.tooltipVisible = false;
			tipPop.visible = false;
		}
	}

	PopupWindow {
		id: tipPop
		visible: false
		color: "transparent"
		implicitWidth: tipBox.implicitWidth
		implicitHeight: tipBox.implicitHeight
		onImplicitWidthChanged: anchor.updateAnchor()

		anchor {
			window: bar
			adjustment: PopupAdjustment.SlideX
			gravity: Edges.Bottom | Edges.Right

			onAnchoring: {
				if (!bar.tooltipTarget)
					return;
				const item = bar.tooltipTarget;
				const pos = bar.contentItem.mapFromItem(
					item,
					Math.round(item.width / 2 - tipPop.width / 2),
					item.height + 6
				);
				anchor.rect.x = Math.max(0, Math.min(bar.width - tipPop.width, pos.x));
				anchor.rect.y = pos.y;
			}
		}

		Rectangle {
			id: tipBox
			implicitWidth: tipLabel.implicitWidth + 20
			implicitHeight: tipLabel.implicitHeight + 10
			color: Qt.rgba(Theme.bgCardColor.r, Theme.bgCardColor.g, Theme.bgCardColor.b, 0.96)
			border.color: Theme.border
			border.width: 1
			radius: Theme.roundingElement

			Text {
				id: tipLabel
				anchors.centerIn: parent
				text: bar.tooltipText
				color: Theme.textMain
				font.family: Theme.fontFamily
				font.pixelSize: Theme.fontSizeSmall
				font.bold: false
			}
		}
	}

	// ─── Reusable Pill component ─────────────────────────────────────────
	// Minimal, borderless, transparent background with smooth hover feedback.
	component Pill: Rectangle {
		id: pill

		property string text: ""
		property string value: ""
		property color textColor: Theme.textMain
		property bool isActive: false
		property string tooltipText: ""
		property alias containsMouse: pillArea.containsMouse
		signal activated()
		signal middleClicked()
		signal rightClicked()
		signal wheeled(bool up)

		onTooltipTextChanged: {
			if (pillArea.containsMouse && pill.tooltipText !== "")
				bar.updateTooltip(pill, pill.tooltipText);
		}

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
			acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
			onEntered: {
				if (pill.tooltipText !== "")
					bar.showTooltip(pill, pill.tooltipText);
			}
			onExited: {
				bar.hideTooltip(pill);
			}
			onClicked: mouse => {
				bar.hideTooltip(pill);
				if (mouse.button === Qt.RightButton) {
					pill.rightClicked();
				} else if (mouse.button === Qt.MiddleButton) {
					pill.middleClicked();
				} else {
					pill.activated();
				}
			}
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
								onEntered: bar.showTooltip(wsButton, "Workspace " + wsButton.modelData.name)
								onExited: bar.hideTooltip(wsButton)
								onClicked: {
									bar.hideTooltip(wsButton);
									Quickshell.execDetached([
										"hyprctl", "dispatch", "hl.dsp.focus({workspace=" + wsButton.modelData.id + "})"
									]);
								}
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
				visible: SystemStatus.memPercent !== ""
				text: "󰍛"
				value: SystemStatus.memPercent !== "" ? SystemStatus.memPercent + "%" : ""
				textColor: Number(SystemStatus.memPercent) >= 90 ? Theme.critical : (Number(SystemStatus.memPercent) >= 75 ? Theme.warning : Theme.textDim)
				tooltipText: SystemStatus.memTooltip
				onActivated: Quickshell.execDetached([
					"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('btop')"
				])
			}

			// dGPU pill (NVIDIA) - minimal, icon-only, only shown when active
			Pill {
				visible: SystemStatus.gpuDevicePath !== "" && SystemStatus.gpuActive
				text: "󰢮"
				value: ""
				textColor: Theme.accentGreen
				tooltipText: "dGPU: Active"
				onActivated: Quickshell.execDetached([
					"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('btop')"
				])
			}

			// Power-save mode pill (only shown when active)
			Pill {
				visible: SystemStatus.powerSaveActive
				text: "󰌪"
				textColor: Theme.accentGreen
				tooltipText: "Battery saver: On (60 Hz)"
				onActivated: Quickshell.execDetached(["sh", "-c", "~/.local/bin/power-save"])
			}
		}

		// ─── Center zone: Minimal Time & Weather ─────────────────────────
		RowLayout {
			anchors.centerIn: parent
			spacing: 4

			Pill {
				id: clock
				readonly property bool valid: !isNaN(clockSource.date?.getTime?.() ?? NaN)
				text: ""
				value: valid ? Qt.formatDateTime(clockSource.date, "hh:mm") : Qt.formatDateTime(new Date(), "hh:mm")
				textColor: Theme.textMain
				tooltipText: Qt.formatDateTime(clock.valid ? clockSource.date : new Date(), "dddd, MMMM d, yyyy")
				onActivated: Quickshell.execDetached([
					"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('calendar')"
				])

				SystemClock {
					id: clockSource
					precision: SystemClock.Minutes
				}
			}

			Pill {
				id: weatherPill
				visible: Weather.label !== ""
				text: Weather.label
				value: Weather.tempNum !== "" ? (Weather.tempNum + "°") : ""
				textColor: Theme.textMain
				isActive: Weather.panelOpen
				tooltipText: Weather.tooltipText
				onActivated: Weather.toggle()
				onMiddleClicked: Weather.refresh()
				onRightClicked: Quickshell.execDetached(["sh", "-c", "~/.local/bin/weather notify"])
			}
		}

		// ─── Right zone: Tray / Status ────────────────────────────────────
		RowLayout {
			id: rightModules
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			spacing: 6

			// Dictation indicator (red dot while recording, amber dots while transcribing)
			Pill {
				visible: SystemStatus.dictatingActive
				text: SystemStatus.dictationState === "transcribing" ? "…" : "●"
				textColor: SystemStatus.dictationState === "transcribing" ? Theme.warning : Theme.critical
				isActive: true
				tooltipText: SystemStatus.dictationState === "transcribing" ? "Transcribing audio..." : "Dictation active (Click to stop)"
				onActivated: Quickshell.execDetached(["sh", "-c", "~/.local/bin/dictation stop"])
			}

			// Screen recording indicator
			Pill {
				visible: SystemStatus.recording
				text: "●"
				value: "REC"
				textColor: Theme.critical
				isActive: true
				tooltipText: "Recording screen (Click to stop)"
				onActivated: Quickshell.execDetached(["sh", "-c", "~/.local/bin/record-screen"])
			}

			// Screencast indicator
			Pill {
				visible: SystemStatus.screencasts > 0
				text: "󰒎"
				textColor: Theme.accentPurple
				isActive: true
				tooltipText: "Screen sharing active (" + SystemStatus.screencasts + (SystemStatus.screencasts === 1 ? " stream)" : " streams)")
			}

			// Caffeine toggle indicator
			Pill {
				visible: SystemStatus.caffeineActive
				text: "󰖦"
				textColor: Theme.accentBlue
				tooltipText: "Stay awake: Active"
				onActivated: Quickshell.execDetached(["sh", "-c", "~/.local/bin/caffeine-toggle"])
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

				readonly property string tooltipInfo: {
					if (!adapter)
						return "Bluetooth: Unavailable";
					if (!adapter.enabled)
						return "Bluetooth: Off";
					if (connectedCount === 0)
						return "Bluetooth: Disconnected";
					var connectedNames = [];
					var vals = adapter.devices.values;
					for (var i = 0; i < vals.length; i++) {
						if (vals[i].connected) {
							var name = vals[i].name || vals[i].deviceName || vals[i].address;
							if (vals[i].batteryAvailable && vals[i].battery >= 0)
								name += " (" + Math.round(vals[i].battery * 100) + "%)";
							connectedNames.push(name);
						}
					}
					if (connectedNames.length > 0)
						return "Bluetooth: " + connectedNames.join(", ");
					return "Bluetooth: Connected";
				}

				text: !adapter?.enabled ? "󰂲" : (connectedCount > 0 ? "󰂱" : "󰂯")
				value: connectedCount > 1 ? String(connectedCount) : ""
				textColor: connectedCount > 0 ? Theme.accentBlue : (adapter?.enabled ? Theme.textMain : Theme.textDim)
				tooltipText: tooltipInfo
				onActivated: QuickSettings.openBluetooth()
			}

			// Network indicator (Wifi / Ethernet)
			Pill {
				readonly property bool wifiUp: bar.wifiDevice?.connected ?? false
				readonly property bool wiredUp: bar.wiredDevice?.connected ?? false
				readonly property string wifiName: {
					var d = bar.wifiDevice;
					if (!d || !d.networks || !d.networks.values)
						return "";
					var vals = d.networks.values;
					for (var i = 0; i < vals.length; i++)
						if (vals[i] && vals[i].connected)
							return vals[i].name || "";
					return "";
				}
				readonly property int wifiSignal: {
					var d = bar.wifiDevice;
					if (!d || !d.networks || !d.networks.values)
						return 0;
					var vals = d.networks.values;
					for (var i = 0; i < vals.length; i++)
						if (vals[i] && vals[i].connected)
							return vals[i].signalStrength ?? 0;
					return 0;
				}

				text: wifiUp ? "󰖩" : (wiredUp ? "󰈀" : "󰖪")
				textColor: (wifiUp || wiredUp) ? Theme.textMain : Theme.textDim
				tooltipText: {
					if (wifiUp)
						return "Wi-Fi: " + (wifiName !== "" ? wifiName : "Connected") + (wifiSignal > 0 ? " (" + wifiSignal + "%)" : "");
					if (wiredUp)
						return "Ethernet: Connected";
					return "Network: Disconnected";
				}
				onActivated: QuickSettings.openWifi()
			}

			// Battery indicator
			Pill {
				id: batteryPill
				readonly property var device: bar.batteryDevice
				readonly property var bucketIcons: [
					"󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"
				]
				readonly property int pct: device ? Math.round(device.percentage * 100) : 0
				readonly property bool full: device && device.state === UPowerDeviceState.FullyCharged
				readonly property bool charging: device && (device.state === UPowerDeviceState.Charging
					|| device.state === UPowerDeviceState.PendingCharge)

				readonly property string tooltipInfo: {
					if (!device)
						return "Battery";
					if (charging) {
						var fullTime = device.timeToFull > 0 ? (Math.floor(device.timeToFull / 3600) + "h " + Math.floor((device.timeToFull % 3600) / 60) + "m to full") : "";
						return "Battery: " + pct + "% (Charging" + (fullTime !== "" ? ", " + fullTime : "") + ")";
					}
					if (full)
						return "Battery: " + pct + "% (Fully charged)";
					var remTime = device.timeToEmpty > 0 ? (Math.floor(device.timeToEmpty / 3600) + "h " + Math.floor((device.timeToEmpty % 3600) / 60) + "m remaining") : "";
					return "Battery: " + pct + "%" + (remTime !== "" ? " (" + remTime + ")" : "");
				}

				visible: device !== null
				text: charging ? "󰂄" : (full ? "󰁹" : bucketIcons[Math.min(10, Math.max(0, Math.floor(pct / 10)))])
				value: visible ? String(pct) + "%" : ""
				textColor: charging || full ? Theme.accentGreen
					: pct <= 10 ? Theme.critical
					: pct <= 20 ? Theme.warning
					: Theme.textMain
				tooltipText: tooltipInfo
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
				tooltipText: {
					if (dnd)
						return "Notifications: Do not disturb";
					if (unreadCount > 0)
						return "Notifications: " + unreadCount + " unread";
					if (historyCount > 0)
						return "Notifications: " + historyCount + " in history";
					return "Notifications: None";
				}
				onActivated: Notifications.toggle()
			}
		}
	}
}