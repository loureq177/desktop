import ".."
import "../widgets"
import "../Specials.js" as Specials
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
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
	WlrLayershell.namespace: "quickshell"

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

	// Hyprland only reports the visible special through events; the monitor
	// snapshot covers the time before the first one arrives.
	property var specialEvent: null
	readonly property string visibleSpecial: {
		var name = specialEvent ?? Hyprland.monitorFor(modelData)?.lastIpcObject?.specialWorkspace?.name ?? "";
		return String(name).replace(/^special:/, "");
	}
	// Joined first so the list only changes when the set of specials does.
	readonly property string specialsKey: Hyprland.workspaces.values
		.map(w => String(w.name))
		.filter(n => n.startsWith("special:"))
		.map(n => n.slice(8))
		.sort()
		.join("\n")
	readonly property var specials: specialsKey !== "" ? specialsKey.split("\n") : []

	readonly property var players: Mpris.players.values

	// A click on a module puts the open panel away, as a click anywhere else
	// does, unless it is that module's own (`except`). A module that opens a
	// panel replaces the open one instead, with Panels.toggle.
	function leavePanels(except: string): void {
		if (Panels.active !== "" && Panels.active !== except)
			Panels.close();
	}

	// Right-click closes a special: closing its windows removes the workspace
	// (misc:close_special_on_empty). Hiding, which leaves the app running,
	// stays on the left click.
	function closeSpecial(name: string): void {
		if (name === "")
			return;
		var ws = "special:" + name;
		var wins = Hyprland.toplevels.values.filter(t => t?.workspace?.name === ws);
		for (var i = 0; i < wins.length; i++) {
			var addr = String(wins[i].address ?? "");
			if (!addr.startsWith("0x"))
				addr = "0x" + addr;
			// A selector that matches nothing also lands on the focused window.
			if (!/^0x[0-9a-f]+$/i.test(addr))
				continue;
			// The selector must go in the table: a bare string arg is ignored
			// and the dispatcher falls back to the focused window.
			Quickshell.execDetached([
				"hyprctl", "dispatch", "hl.dsp.window.close({ window = 'address:" + addr + "' })"
			]);
		}
	}

	function playerFor(special: string): var {
		return players.find(p => ((p?.desktopEntry ?? "") + " " + (p?.identity ?? "")).toLowerCase().includes(special)) ?? null;
	}

	function trackLabel(player: var): string {
		if (!player)
			return "";
		return [player.trackArtist, player.trackTitle].filter(s => s).join(" — ");
	}

	Connections {
		target: Hyprland
		function onRawEvent(ev) {
			if (ev.name !== "activespecial")
				return;
			var parts = String(ev.data ?? "").split(",");
			if (parts.pop() === bar.screenName)
				bar.specialEvent = parts.join(",");
		}
	}

	// Colour rule: at rest the workspace group on the left is textDim and the
	// readouts (clock, weather, status) are textMain. Blue marks what is on
	// screen or wants attention, green what is running (playback, charging), dim
	// what is switched off; warning and critical speak for themselves.

	// The bar has no background of its own, so hover is a tint rather than a solid fill.
	readonly property color hoverColor: Theme.alpha(Theme.textMain, 0.1)

	property Item tooltipTarget: null
	// What a module reads out, nothing about its clicks or keys (those are in
	// the launcher's actions).
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
			implicitWidth: tipText.implicitWidth + 20
			implicitHeight: tipText.implicitHeight + 10
			color: Theme.bgCard
			border.color: Theme.border
			border.width: 1
			radius: Theme.roundingElement

			StyledText {
				id: tipText
				anchors.centerIn: parent
				text: bar.tooltipText
				font.pixelSize: Theme.fontSizeSmall
			}
		}
	}

	component Pill: Rectangle {
		id: pill

		property string text: ""
		property string icon: ""
		property string value: ""
		property color textColor: Theme.textMain
		property bool isActive: false
		property string tooltipText: ""
		// The panel this module opens, if any.
		property string panel: ""
		property bool custom: false
		default property alias content: pillRow.data
		property alias containsMouse: pillArea.containsMouse
		signal activated()
		signal rightClicked()

		onTooltipTextChanged: {
			if (pillArea.containsMouse && pill.tooltipText !== "")
				bar.updateTooltip(pill, pill.tooltipText);
		}

		Layout.alignment: Qt.AlignVCenter
		implicitHeight: Theme.barHeight
		implicitWidth: (text !== "" || icon !== "" || value !== "" || custom) ? pillRow.implicitWidth + 14 : 0
		visible: text !== "" || icon !== "" || value !== "" || custom
		color: isActive ? Theme.alpha(Theme.accent, 0.16) : (pillArea.containsMouse ? bar.hoverColor : "transparent")
		border.width: 0
		radius: Theme.roundingElement

		Behavior on color {
			ColorAnimation { duration: Theme.animFast }
		}

		Row {
			id: pillRow
			anchors.centerIn: parent
			spacing: pill.custom ? 10 : (((pill.text !== "" || pill.icon !== "") && pill.value !== "") ? 6 : 0)

			LineIcon {
				anchors.verticalCenter: parent.verticalCenter
				name: pill.icon
				color: pill.textColor
			}

			StyledText {
				anchors.verticalCenter: parent.verticalCenter
				visible: pill.text !== ""
				text: pill.text
				font.pixelSize: Theme.fontSizeLarge
				font.bold: true
				color: pill.textColor
			}

			StyledText {
				anchors.verticalCenter: parent.verticalCenter
				visible: pill.value !== ""
				text: pill.value
				mono: true
				font.pixelSize: Theme.fontSizeSmall
				font.bold: true
				color: pill.textColor
			}
		}

		MouseArea {
			id: pillArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			acceptedButtons: Qt.LeftButton | Qt.RightButton
			onEntered: {
				if (pill.tooltipText !== "" && !pill.isActive)
					bar.showTooltip(pill, pill.tooltipText);
			}
			onExited: {
				bar.hideTooltip(pill);
			}
			onPressed: mouse => {
				bar.hideTooltipNow();
				if (pill.panel === "" || mouse.button !== Qt.LeftButton)
					bar.leavePanels(pill.panel);
				if (mouse.button === Qt.RightButton)
					pill.rightClicked();
				else
					pill.activated();
			}
		}
	}

	Item {
		anchors.fill: parent

		MouseArea {
			anchors.fill: parent
			z: -1
			enabled: Panels.active !== "" || bar.visibleSpecial !== ""
			onPressed: {
				// Panels first; with none open, the click puts the special away.
				if (Panels.active !== "")
					Panels.close();
				else
					Actions.toggleSpecial(bar.visibleSpecial);
			}
		}

		RowLayout {
			id: leftModules
			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			spacing: 6

			Pill {
				icon: "layout-grid"
				textColor: Panels.active === "launcher" ? Theme.accentBlue : Theme.textDim
				isActive: Panels.active === "launcher"
				panel: "launcher"
				onActivated: Panels.toggle("launcher", "apps")
			}

			Item {
				id: wsContainer
				Layout.alignment: Qt.AlignVCenter
				implicitHeight: Theme.barHeight
				implicitWidth: wsRow.width

				Row {
					id: wsRow
					height: parent.height

					Repeater {
						model: {
							var ws = Hyprland.workspaces.values.filter(w => w.monitor?.name === bar.screenName && !String(w.name).startsWith("special:"));
							ws.sort((a, b) => a.id - b.id);
							return ws;
						}

						delegate: Item {
							id: wsButton
							required property var modelData
							readonly property bool isActive: modelData.active

							height: Theme.barHeight
							width: wsDot.width + 10

							Rectangle {
								id: wsDot
								anchors.centerIn: parent
								width: wsButton.isActive ? 26 : 8
								height: 8
								radius: 4
								color: wsButton.isActive ? Theme.accentBlue : (wsArea.containsMouse ? Theme.textMain : Theme.textDim)

								Behavior on width {
									NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
								}
								Behavior on color { ColorAnimation { duration: Theme.animFast } }
							}

							MouseArea {
								id: wsArea
								anchors.fill: parent
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onClicked: {
									bar.leavePanels("");
									Quickshell.execDetached([
										"hyprctl", "dispatch", "hl.dsp.focus({workspace=" + wsButton.modelData.id + "})"
									]);
								}
							}
						}
					}
				}
			}

			Item {
				id: specialsZone
				Layout.alignment: Qt.AlignVCenter
				implicitHeight: Theme.barHeight
				implicitWidth: specialsRow.width

				Row {
					id: specialsRow
					height: parent.height

					// Memory doubles as the btop special; the other open specials follow it.
					Pill {
						visible: SystemStatus.memPercent !== ""
						icon: "memory-stick"
						value: SystemStatus.memPercent !== "" ? SystemStatus.memPercent + "%" : ""
						textColor: Number(SystemStatus.memPercent) >= 90 ? Theme.critical : (Number(SystemStatus.memPercent) >= 75 ? Theme.warning : (bar.visibleSpecial === "btop" ? Theme.accentBlue : Theme.textDim))
						isActive: bar.visibleSpecial === "btop"
						tooltipText: SystemStatus.memTooltip
						onActivated: Actions.toggleSpecial("btop")
						onRightClicked: bar.closeSpecial("btop")
					}

					Repeater {
						model: bar.specials.filter(name => name !== "btop")

						delegate: Item {
							id: sp
							required property string modelData
							readonly property var player: bar.playerFor(modelData)
							readonly property bool playing: player?.isPlaying ?? false
							readonly property bool shown: modelData === bar.visibleSpecial
							readonly property var special: Specials.find(modelData)
							readonly property string icon: special?.icon ?? ""
							readonly property color tint: shown ? Theme.accentBlue
								: playing ? Theme.accentGreen
								: (spArea.containsMouse ? Theme.textMain : Theme.textDim)
							readonly property string tip: {
								var title = special?.title ?? (modelData.charAt(0).toUpperCase() + modelData.slice(1));
								var track = bar.trackLabel(player);
								return track !== "" ? title + "\n" + track : title;
							}

							onTipChanged: bar.updateTooltip(sp, tip)

							height: Theme.barHeight
							width: 30

							Rectangle {
								anchors.fill: parent
								color: spArea.containsMouse ? bar.hoverColor : (sp.shown ? Theme.alpha(Theme.accent, 0.18) : "transparent")
								radius: Theme.roundingElement

								Behavior on color { ColorAnimation { duration: Theme.animFast } }
							}

							LineIcon {
								anchors.centerIn: parent
								name: sp.icon
								color: sp.tint
							}

							StyledText {
								anchors.centerIn: parent
								visible: sp.icon === ""
								text: sp.modelData.charAt(0).toUpperCase()
								mono: true
								font.pixelSize: Theme.fontSizeSmall
								font.bold: true
								color: sp.tint
							}

							MouseArea {
								id: spArea
								anchors.fill: parent
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								acceptedButtons: Qt.LeftButton | Qt.RightButton
								onEntered: bar.showTooltip(sp, sp.tip)
								onExited: bar.hideTooltip(sp)
								onPressed: mouse => {
									bar.hideTooltipNow();
									bar.leavePanels("");
									if (mouse.button === Qt.RightButton)
										bar.closeSpecial(sp.modelData);
									else
										Actions.toggleSpecial(sp.modelData);
								}
							}
						}
					}
				}
			}

			Pill {
				visible: SystemStatus.powerSaveActive
				icon: "leaf"
				textColor: Theme.textMain
				tooltipText: "Battery saver (60 Hz)"
				onActivated: Actions.togglePowerSave()
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
				onActivated: Actions.toggleSpecial("calendar")

				SystemClock {
					id: clockSource
					precision: SystemClock.Minutes
				}
			}

			Pill {
				id: weatherPill
				visible: Weather.current !== null
				icon: Weather.current?.icon ?? ""
				value: Weather.current ? Weather.current.tempNum + "°" : ""
				textColor: Theme.textMain
				isActive: Panels.active === "weather"
				tooltipText: Weather.tooltipText
				panel: "weather"
				onActivated: Panels.toggle("weather")
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
				tooltipText: SystemStatus.dictationState === "transcribing" ? "Transcribing..." : "Dictation"
				onActivated: Actions.script("dictation stop")
			}

			Pill {
				visible: SystemStatus.recording
				text: "●"
				value: "REC"
				textColor: Theme.critical
				isActive: true
				tooltipText: "Recording the screen"
				onActivated: Actions.script("record-screen")
			}

			Pill {
				visible: SystemStatus.screencasts > 0
				icon: "screen-share"
				textColor: Theme.accentPurple
				isActive: true
				tooltipText: "Sharing the screen" + (SystemStatus.screencasts > 1 ? " (" + SystemStatus.screencasts + " streams)" : "")
			}

			Pill {
				visible: SystemStatus.awakeActive
				icon: "coffee"
				textColor: Theme.textMain
				tooltipText: "Keep awake"
				onActivated: Actions.toggleAwake()
			}

			Pill {
				id: statusPill
				readonly property bool online: SystemStatus.wifiUp || SystemStatus.wiredUp
				readonly property var battery: SystemStatus.batteryDevice
				readonly property int pct: battery ? Math.round(battery.percentage * 100) : 0
				readonly property bool full: battery && battery.state === UPowerDeviceState.FullyCharged
				readonly property bool charging: battery && (battery.state === UPowerDeviceState.Charging
					|| battery.state === UPowerDeviceState.PendingCharge)

				readonly property string btInfo: {
					if (!SystemStatus.btAdapter)
						return "Bluetooth: Unavailable";
					if (!SystemStatus.btEnabled)
						return "Bluetooth: Off";
					if (SystemStatus.btConnected.length === 0)
						return "Bluetooth: Disconnected";
					return "Bluetooth: " + SystemStatus.btConnected.map(d => {
						var name = SystemStatus.deviceName(d);
						if (d.batteryAvailable && d.battery >= 0)
							name += " (" + Math.round(d.battery * 100) + "%)";
						return name;
					}).join(", ");
				}

				readonly property string netInfo: {
					if (SystemStatus.wifiUp) {
						var net = SystemStatus.wifiNetwork;
						var signal = Math.round(SystemStatus.signalPercent(net));
						return "Wi-Fi: " + (net?.name || "Connected") + (signal > 0 ? " (" + signal + "%)" : "");
					}
					if (SystemStatus.wiredUp)
						return "Ethernet: Connected";
					return "Network: Disconnected";
				}

				readonly property string batteryInfo: {
					if (!battery)
						return "";
					if (charging)
						return "Battery: " + pct + "% (Charging" + (battery.timeToFull > 0 ? ", " + SystemStatus.duration(battery.timeToFull) + " to full" : "") + ")";
					if (full)
						return "Battery: " + pct + "% (Fully charged)";
					return "Battery: " + pct + "%" + (battery.timeToEmpty > 0 ? " (" + SystemStatus.duration(battery.timeToEmpty) + " remaining)" : "");
				}

				custom: true
				isActive: Panels.active === "actions"
				tooltipText: [btInfo, netInfo, batteryInfo].filter(s => s !== "").join("\n")
				panel: "actions"
				onActivated: Panels.toggle("actions")

				LineIcon {
					anchors.verticalCenter: parent.verticalCenter
					name: SystemStatus.btIcon
					color: SystemStatus.btEnabled ? Theme.textMain : Theme.textDim
				}

				LineIcon {
					anchors.verticalCenter: parent.verticalCenter
					name: SystemStatus.wifiUp ? "wifi" : (SystemStatus.wiredUp ? "ethernet-port" : "wifi-off")
					color: statusPill.online ? Theme.textMain : Theme.textDim
				}

				StyledText {
					anchors.verticalCenter: parent.verticalCenter
					visible: statusPill.battery !== null
					text: statusPill.pct + "%"
					mono: true
					font.pixelSize: Theme.fontSizeSmall
					font.bold: true
					color: statusPill.charging ? Theme.accentGreen
						: statusPill.pct <= 10 ? Theme.critical
						: statusPill.pct <= 20 ? Theme.warning
						: Theme.textMain
				}
			}

			Pill {
				readonly property int historyCount: Notifications.history.count
				readonly property bool dnd: Notifications.dnd
				readonly property bool isOpen: Panels.active === "notifications"
				readonly property bool hasNotifications: historyCount > 0

				icon: dnd ? "bell-off" : (hasNotifications ? "bell-dot" : "bell")
				value: ""
				textColor: dnd ? Theme.warning : (hasNotifications || isOpen ? Theme.accentBlue : Theme.textMain)
				isActive: isOpen
				tooltipText: {
					if (dnd)
						return "Do not disturb";
					if (historyCount > 0)
						return historyCount + (historyCount === 1 ? " notification" : " notifications");
					return "No notifications";
				}
				panel: "notifications"
				onActivated: Panels.toggle("notifications")
			}
		}
	}
}
