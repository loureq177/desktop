import ".."
import "../widgets"
import "../Specials.js" as Specials
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Networking
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

	readonly property var batteryDevice: SystemStatus.batteryDevice
	readonly property var wifiDevice: SystemStatus.wifiDevice
	readonly property var wiredDevice: SystemStatus.wiredDevice

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

	// "A · B" of the parts that are not empty.
	function hint(first, second) {
		return [first, second].filter(p => p).join("  ·  ");
	}

	function toggleSpecial(name: string): void {
		Quickshell.execDetached([
			"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('" + name + "')"
		]);
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

	function cycleSpecial(delta: int): void {
		if (specials.length === 0 || cycleThrottle.running)
			return;
		var count = specials.length;
		var index = specials.indexOf(visibleSpecial);
		var target = specials[index < 0 ? (delta > 0 ? 0 : count - 1) : (index + delta + count) % count];
		if (target === visibleSpecial)
			return;
		cycleThrottle.start();
		toggleSpecial(target);
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

	Timer {
		id: cycleThrottle
		interval: 200
	}

	// Colour rule: at rest the workspace group on the left is textDim and the
	// readouts (clock, weather, status) are textMain. Blue marks what is on
	// screen or wants attention, green what is running (playback, charging), dim
	// what is switched off; warning and critical speak for themselves.

	// The bar has no background of its own, so hover is a tint rather than a solid fill.
	readonly property color hoverColor: Theme.alpha(Theme.textMain, 0.1)

	property Item tooltipTarget: null
	property string tooltipText: ""
	// A dimmer line under the text: what else the module does, and its keys.
	property string tooltipHint: ""
	property bool tooltipVisible: false

	function showTooltip(item: Item, text: string, hint: string): void {
		if (!text) {
			hideTooltip(item);
			return;
		}
		hideTimer.stop();
		tooltipTarget = item;
		tooltipText = text;
		tooltipHint = hint ?? "";
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

	function updateTooltip(item: Item, text: string, hint: string): void {
		if (tooltipTarget === item) {
			tooltipText = text;
			tooltipHint = hint ?? "";
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
			implicitWidth: tipColumn.implicitWidth + 20
			implicitHeight: tipColumn.implicitHeight + 10
			color: Theme.alpha(Theme.bgCard, 0.96)
			border.color: Theme.border
			border.width: 1
			radius: Theme.roundingElement

			Column {
				id: tipColumn
				anchors.centerIn: parent
				spacing: 3

				Text {
					text: bar.tooltipText
					color: Theme.textMain
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSizeSmall
					font.bold: false
				}

				Text {
					visible: bar.tooltipHint !== ""
					text: bar.tooltipHint
					color: Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSizeSmall - 1
				}
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
		property string tooltipHint: ""
		property bool custom: false
		default property alias content: pillRow.data
		property alias containsMouse: pillArea.containsMouse
		signal activated()
		signal middleClicked()
		signal rightClicked()

		onTooltipTextChanged: {
			if (pillArea.containsMouse && pill.tooltipText !== "")
				bar.updateTooltip(pill, pill.tooltipText, pill.tooltipHint);
		}

		Layout.alignment: Qt.AlignVCenter
		implicitHeight: Theme.barHeight
		implicitWidth: (text !== "" || icon !== "" || value !== "" || custom) ? pillRow.implicitWidth + 14 : 0
		visible: text !== "" || icon !== "" || value !== "" || custom
		color: isActive ? Theme.alpha(Theme.accent, 0.16) : (pillArea.containsMouse ? bar.hoverColor : "transparent")
		border.width: 0
		radius: Theme.roundingElement

		Behavior on color {
			ColorAnimation { duration: 120 }
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
					bar.showTooltip(pill, pill.tooltipText, pill.tooltipHint);
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
			enabled: Panels.active !== "" || bar.visibleSpecial !== ""
			onPressed: {
				// Panels first; with none open, the click puts the special away.
				if (Panels.active !== "")
					Panels.close();
				else
					bar.toggleSpecial(bar.visibleSpecial);
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
				tooltipText: "Apps and actions"
				tooltipHint: Keybinds.chord("Launcher")
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
								Behavior on color { ColorAnimation { duration: 120 } }
							}

							MouseArea {
								id: wsArea
								anchors.fill: parent
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onEntered: bar.showTooltip(wsButton, "Workspace " + wsButton.modelData.name, Keybinds.chord("Switch to workspace " + wsButton.modelData.name))
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
						else if (w.angleDelta.y < 0)
							Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({workspace='-1'})"]);
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
						tooltipHint: bar.hint("Click: Activity Monitor", Keybinds.chord("Show Activity Monitor"))
						onActivated: bar.toggleSpecial("btop")
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
							readonly property string tipHint: bar.hint("Right-click: close", special ? Keybinds.chord(Specials.bindName(special)) : "")

							onTipChanged: bar.updateTooltip(sp, tip, tipHint)

							height: Theme.barHeight
							width: 30

							Rectangle {
								anchors.fill: parent
								color: spArea.containsMouse ? bar.hoverColor : (sp.shown ? Theme.alpha(Theme.accent, 0.18) : "transparent")
								radius: Theme.roundingElement

								Behavior on color { ColorAnimation { duration: 120 } }
							}

							LineIcon {
								anchors.centerIn: parent
								name: sp.icon
								color: sp.tint
							}

							Text {
								anchors.centerIn: parent
								visible: sp.icon === ""
								text: sp.modelData.charAt(0).toUpperCase()
								font.family: Theme.fontMono
								font.pixelSize: Theme.fontSizeBar
								font.bold: true
								color: sp.tint
							}

							MouseArea {
								id: spArea
								anchors.fill: parent
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								acceptedButtons: Qt.LeftButton | Qt.RightButton
								onEntered: bar.showTooltip(sp, sp.tip, sp.tipHint)
								onExited: bar.hideTooltip(sp)
								onPressed: mouse => {
									bar.hideTooltipNow();
									if (mouse.button === Qt.RightButton)
										bar.closeSpecial(sp.modelData);
									else
										bar.toggleSpecial(sp.modelData);
								}
							}
						}
					}
				}

				MouseArea {
					anchors.fill: parent
					acceptedButtons: Qt.NoButton
					onWheel: w => {
						if (w.angleDelta.y !== 0)
							bar.cycleSpecial(w.angleDelta.y > 0 ? -1 : 1);
					}
				}
			}

			Pill {
				visible: SystemStatus.powerSaveActive
				icon: "leaf"
				textColor: Theme.textMain
				tooltipText: "Battery saver: On (60 Hz)"
				tooltipHint: "Click: turn off"
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
				tooltipHint: bar.hint("Click: Calendar", Keybinds.chord("Show Calendar"))
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
				visible: Weather.current !== null
				icon: Weather.current?.icon ?? ""
				value: Weather.current ? Weather.current.tempNum + "°" : ""
				textColor: Theme.textMain
				isActive: Panels.active === "weather"
				tooltipText: Weather.tooltipText
				tooltipHint: bar.hint("Middle-click: refresh", Keybinds.chord("Weather"))
				onActivated: Panels.toggle("weather")
				onMiddleClicked: Weather.refresh()
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
				icon: "screen-share"
				textColor: Theme.accentPurple
				isActive: true
				tooltipText: "Screen sharing active (" + SystemStatus.screencasts + (SystemStatus.screencasts === 1 ? " stream)" : " streams)")
			}

			Pill {
				visible: SystemStatus.awakeActive
				icon: "coffee"
				textColor: Theme.textMain
				tooltipText: "Keep awake: On"
				tooltipHint: "Click: turn off"
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
						// Reported as a 0..1 fraction.
						var strength = wifiNetwork?.signalStrength ?? 0;
						var signal = Math.round(strength > 1.0 ? strength : strength * 100);
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
				isActive: Panels.active === "quicksettings"
				tooltipText: [btInfo, netInfo, batteryInfo].filter(s => s !== "").join("\n")
				tooltipHint: bar.hint("Right-click: energy use", Keybinds.chord("Quick actions"))
				onActivated: Panels.toggle("quicksettings")
				onRightClicked: Quickshell.execDetached([
					"hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('jolt')"
				])

				LineIcon {
					anchors.verticalCenter: parent.verticalCenter
					name: !statusPill.adapter?.enabled ? "bluetooth-off" : (statusPill.btConnected.length > 0 ? "bluetooth-connected" : "bluetooth")
					color: statusPill.adapter?.enabled ? Theme.textMain : Theme.textDim
				}

				LineIcon {
					anchors.verticalCenter: parent.verticalCenter
					name: statusPill.wifiUp ? "wifi" : (statusPill.wiredUp ? "ethernet-port" : "wifi-off")
					color: (statusPill.wifiUp || statusPill.wiredUp) ? Theme.textMain : Theme.textDim
				}

				Text {
					anchors.verticalCenter: parent.verticalCenter
					visible: statusPill.battery !== null
					text: statusPill.pct + "%"
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeBar
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
						return "Notifications: Do not disturb";
					if (historyCount > 0)
						return "Notifications: " + historyCount + (historyCount === 1 ? " notification" : " notifications");
					return "Notifications: None";
				}
				tooltipHint: Keybinds.chord("Toggle notification center")
				onActivated: Panels.toggle("notifications")
			}
		}
	}
}
