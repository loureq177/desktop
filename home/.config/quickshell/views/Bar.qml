import ".."
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
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
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell-bar"

	readonly property bool hasFullscreen: {
		var ws = Hyprland.workspaces.values.find(w => w.monitor?.name === bar.screenName && w.active);
		return ws?.hasFullscreen ?? false;
	}
	visible: !hasFullscreen

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

	Component.onCompleted: Bars.add(bar)
	Component.onDestruction: Bars.remove(bar)

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

	function hideTooltipNow(): void {
		tipTimer.stop();
		hideTimer.stop();
		tooltipTarget = null;
		tooltipVisible = false;
		tipPop.visible = false;
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
			color: Theme.alpha(Theme.bgCardColor, 0.96)
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

	component Pill: Rectangle {
		id: pill

		property string text: ""
		property string value: ""
		property color textColor: Theme.textMain
		property bool isActive: false
		property string tooltipText: ""
		property bool custom: false
		default property alias content: pillRow.data
		property alias containsMouse: pillArea.containsMouse
		signal activated()
		signal middleClicked()
		signal rightClicked()

		onTooltipTextChanged: {
			if (pillArea.containsMouse && pill.tooltipText !== "")
				bar.updateTooltip(pill, pill.tooltipText);
		}

		Layout.alignment: Qt.AlignVCenter
		implicitHeight: Theme.barHeight
		implicitWidth: (text !== "" || value !== "" || custom) ? pillRow.implicitWidth + 14 : 0
		visible: text !== "" || value !== "" || custom
		color: isActive ? Theme.alpha(Theme.accent, 0.16) : (pillArea.containsMouse ? Theme.bgHover : "transparent")
		border.width: 0
		radius: Theme.roundingElement

		Behavior on color {
			ColorAnimation { duration: 120 }
		}

		Row {
			id: pillRow
			anchors.centerIn: parent
			spacing: pill.custom ? 10 : ((pill.text !== "" && pill.value !== "") ? 6 : 0)

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
				if (pill.tooltipText !== "" && !pill.isActive)
					bar.showTooltip(pill, pill.tooltipText);
			}
			onExited: {
				bar.hideTooltip(pill);
			}
			onPressed: mouse => {
				bar.hideTooltipNow();
				if (mouse.button === Qt.RightButton) {
					pill.rightClicked();
				} else if (mouse.button === Qt.MiddleButton) {
					pill.middleClicked();
				} else {
					pill.activated();
				}
			}
		}
	}

	Item {
		anchors.fill: parent

		MouseArea {
			anchors.fill: parent
			z: -1
			enabled: QuickSettings.panelOpen || Notifications.centerOpen || Weather.panelOpen
			onPressed: {
				QuickSettings.close();
				Notifications.closeCenter();
				Weather.close();
			}
		}

		RowLayout {
			id: leftModules
			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			spacing: 6

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
							color: wsArea.containsMouse ? Theme.bgHover : (isActive ? Theme.alpha(Theme.accent, 0.18) : "transparent")
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

			Pill {
				visible: SystemStatus.powerSaveActive
				text: "󰌪"
				textColor: Theme.accentGreen
				tooltipText: "Battery saver: On (60 Hz)"
				onActivated: Quickshell.execDetached(["sh", "-c", "~/.local/bin/power-save"])
			}
		}

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
				onRightClicked: Quickshell.execDetached(["sh", "-c", "~/.local/bin/weather"])
			}
		}

		RowLayout {
			id: rightModules
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			spacing: 6

			Pill {
				visible: SystemStatus.dictatingActive
				text: SystemStatus.dictationState === "transcribing" ? "…" : "●"
				textColor: SystemStatus.dictationState === "transcribing" ? Theme.warning : Theme.critical
				isActive: true
				tooltipText: SystemStatus.dictationState === "transcribing" ? "Transcribing audio..." : "Dictation active (Click to stop)"
				onActivated: Quickshell.execDetached(["sh", "-c", "~/.local/bin/dictation stop"])
			}

			Pill {
				visible: SystemStatus.recording
				text: "●"
				value: "REC"
				textColor: Theme.critical
				isActive: true
				tooltipText: "Recording screen (Click to stop)"
				onActivated: Quickshell.execDetached(["sh", "-c", "~/.local/bin/record-screen"])
			}

			Pill {
				visible: SystemStatus.screencasts > 0
				text: "󰒎"
				textColor: Theme.accentPurple
				isActive: true
				tooltipText: "Screen sharing active (" + SystemStatus.screencasts + (SystemStatus.screencasts === 1 ? " stream)" : " streams)")
			}

			Pill {
				visible: SystemStatus.awakeActive
				text: "󰖦"
				textColor: Theme.accentBlue
				tooltipText: "Awake: Active"
				onActivated: Quickshell.execDetached(["sh", "-c", "~/.local/bin/awake-toggle"])
			}

			Pill {
				id: statusPill
				readonly property var adapter: Bluetooth.defaultAdapter
				readonly property var btConnected: (adapter?.devices?.values ?? []).filter(d => d.connected)
				readonly property bool wifiUp: bar.wifiDevice?.connected ?? false
				readonly property bool wiredUp: bar.wiredDevice?.connected ?? false
				readonly property var wifiNetwork: (bar.wifiDevice?.networks?.values ?? []).find(n => n && n.connected) ?? null
				readonly property var battery: bar.batteryDevice
				readonly property int pct: battery ? Math.round(battery.percentage * 100) : 0
				readonly property bool full: battery && battery.state === UPowerDeviceState.FullyCharged
				readonly property bool charging: battery && (battery.state === UPowerDeviceState.Charging
					|| battery.state === UPowerDeviceState.PendingCharge)

				readonly property string btInfo: {
					if (!adapter)
						return "Bluetooth: Unavailable";
					if (!adapter.enabled)
						return "Bluetooth: Off";
					if (btConnected.length === 0)
						return "Bluetooth: Disconnected";
					return "Bluetooth: " + btConnected.map(d => {
						var name = d.name || d.deviceName || d.address;
						if (d.batteryAvailable && d.battery >= 0)
							name += " (" + Math.round(d.battery * 100) + "%)";
						return name;
					}).join(", ");
				}

				readonly property string netInfo: {
					if (wifiUp) {
						var signal = wifiNetwork?.signalStrength ?? 0;
						return "Wi-Fi: " + (wifiNetwork?.name || "Connected") + (signal > 0 ? " (" + signal + "%)" : "");
					}
					if (wiredUp)
						return "Ethernet: Connected";
					return "Network: Disconnected";
				}

				readonly property string batteryInfo: {
					if (!battery)
						return "";
					if (charging) {
						var fullTime = battery.timeToFull > 0 ? (Math.floor(battery.timeToFull / 3600) + "h " + Math.floor((battery.timeToFull % 3600) / 60) + "m to full") : "";
						return "Battery: " + pct + "% (Charging" + (fullTime !== "" ? ", " + fullTime : "") + ")";
					}
					if (full)
						return "Battery: " + pct + "% (Fully charged)";
					var remTime = battery.timeToEmpty > 0 ? (Math.floor(battery.timeToEmpty / 3600) + "h " + Math.floor((battery.timeToEmpty % 3600) / 60) + "m remaining") : "";
					return "Battery: " + pct + "%" + (remTime !== "" ? " (" + remTime + ")" : "");
				}

				custom: true
				isActive: QuickSettings.panelOpen
				tooltipText: [btInfo, netInfo, batteryInfo].filter(s => s !== "").join("\n")
				onActivated: QuickSettings.toggle()
				onRightClicked: Quickshell.execDetached([
					"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('jolt')"
				])

				Text {
					anchors.verticalCenter: parent.verticalCenter
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSizeBarIcon
					font.bold: true
					text: !statusPill.adapter?.enabled ? "󰂲" : (statusPill.btConnected.length > 0 ? "󰂱" : "󰂯")
					color: statusPill.btConnected.length > 0 ? Theme.accentBlue : (statusPill.adapter?.enabled ? Theme.textMain : Theme.textDim)
				}

				Text {
					anchors.verticalCenter: parent.verticalCenter
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSizeBarIcon
					font.bold: true
					text: statusPill.wifiUp ? "󰖩" : (statusPill.wiredUp ? "󰈀" : "󰖪")
					color: (statusPill.wifiUp || statusPill.wiredUp) ? Theme.accentBlue : Theme.textDim
				}

				Text {
					anchors.verticalCenter: parent.verticalCenter
					visible: statusPill.battery !== null
					text: statusPill.pct + "%"
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeBar
					font.bold: true
					color: statusPill.charging || statusPill.full ? Theme.accentGreen
						: statusPill.pct <= 10 ? Theme.critical
						: statusPill.pct <= 20 ? Theme.warning
						: Theme.textMain
				}
			}

			Pill {
				readonly property int historyCount: Notifications.history.length
				readonly property bool dnd: Notifications.dnd
				readonly property bool isOpen: Notifications.centerOpen
				readonly property bool hasNotifications: historyCount > 0

				text: dnd ? "󰂛" : (hasNotifications ? "󰂚" : "󰂜")
				value: ""
				textColor: dnd ? Theme.warning : (hasNotifications || isOpen ? Theme.accentBlue : Theme.textDim)
				isActive: isOpen
				tooltipText: {
					if (dnd)
						return "Notifications: Do not disturb";
					if (historyCount > 0)
						return "Notifications: " + historyCount + (historyCount === 1 ? " notification" : " notifications");
					return "Notifications: None";
				}
				onActivated: Notifications.toggle()
			}
		}
	}
}
