import ".."
import "../widgets"
import "../Specials.js" as Specials
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
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

	readonly property bool hasFullscreen: Hyprland.workspaces.values.find(w => w.monitor?.name === bar.screenName && w.active)?.hasFullscreen ?? false
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
	readonly property string visibleSpecial: String(specialEvent ?? Hyprland.monitorFor(modelData)?.lastIpcObject?.specialWorkspace?.name ?? "").replace(/^special:/, "")
	// Joined first so the list only changes when the set of specials does.
	readonly property string specialsKey: Hyprland.workspaces.values
		.map(w => String(w.name))
		.filter(n => n.startsWith("special:"))
		.map(n => n.slice(8))
		.filter(n => Specials.find(n)?.inBar !== false)
		.sort()
		.join("\n")

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
		for (const win of Hyprland.toplevels.values.filter(t => t?.workspace?.name === "special:" + name))
			Hypr.closeWindow(String(win.address ?? ""));
	}

	function playerFor(special: string): var {
		return Mpris.players.values.find(p => ((p?.desktopEntry ?? "") + " " + (p?.identity ?? "")).toLowerCase().includes(special)) ?? null;
	}

	// Colour rule: at rest the workspace group on the left is textDim and the
	// readouts (clock, weather, status) are textMain. Blue marks what is on
	// screen or wants attention, green what is running (playback, charging), dim
	// what is switched off; warning and critical speak for themselves.

	// The bar has no background of its own, so hover is a tint rather than a solid fill.
	readonly property color hoverColor: Theme.alpha(Theme.textMain, 0.1)

	component Pill: Rectangle {
		id: pill

		property string text: ""
		property string icon: ""
		property string value: ""
		property color textColor: Theme.textMain
		property bool isActive: false
		// The panel this module opens, if any.
		property string panel: ""
		property bool custom: false
		default property alias content: pillRow.data
		signal activated()
		signal rightClicked()

		Layout.alignment: Qt.AlignVCenter
		implicitHeight: Theme.barHeight
		implicitWidth: pillRow.implicitWidth + 14
		visible: text !== "" || icon !== "" || value !== "" || custom
		color: isActive ? Theme.alpha(Theme.accent, 0.16) : (pillArea.containsMouse ? bar.hoverColor : "transparent")
		radius: Theme.roundingElement

		Behavior on color {
			ColorAnimation { duration: Theme.animFast }
		}

		Row {
			id: pillRow
			anchors.centerIn: parent
			spacing: pill.custom ? 10 : 6

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
			onPressed: mouse => {
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
					Hypr.toggleSpecial(bar.visibleSpecial);
			}
		}

		RowLayout {
			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			spacing: 6

			Pill {
				icon: "layout-grid"
				textColor: isActive ? Theme.accentBlue : Theme.textDim
				isActive: Panels.active === "launcher"
				panel: "launcher"
				onActivated: Panels.toggle("launcher", "apps")
			}

			Row {
				Layout.alignment: Qt.AlignVCenter
				height: Theme.barHeight

				Repeater {
					model: Hyprland.workspaces.values
						.filter(w => w.monitor?.name === bar.screenName && !String(w.name).startsWith("special:"))
						.sort((a, b) => a.id - b.id)

					delegate: Item {
						id: wsButton
						required property var modelData

						height: Theme.barHeight
						width: wsDot.width + 10

						Rectangle {
							id: wsDot
							anchors.centerIn: parent
							width: wsButton.modelData.active ? 26 : 8
							height: 8
							radius: 4
							color: wsButton.modelData.active ? Theme.accentBlue : (wsArea.containsMouse ? Theme.textMain : Theme.textDim)

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
								Hypr.focusWorkspace(wsButton.modelData.id);
							}
						}
					}
				}
			}

			// Memory doubles as the btop special; the other open specials follow
			// it, side by side.
			Row {
				Layout.alignment: Qt.AlignVCenter

				Pill {
					visible: Memory.percent >= 0
					icon: "memory-stick"
					value: Memory.percent + "%"
					isActive: bar.visibleSpecial === "btop"
					textColor: Memory.percent >= 90 ? Theme.critical
						: Memory.percent >= 75 ? Theme.warning
						: isActive ? Theme.accentBlue : Theme.textDim
					onActivated: Hypr.toggleSpecial("btop")
					onRightClicked: bar.closeSpecial("btop")
				}

				// Blue while it is on screen, green while it plays something.
				Repeater {
					model: bar.specialsKey !== "" ? bar.specialsKey.split("\n") : []

					delegate: Pill {
						required property string modelData
						readonly property var special: Specials.find(modelData)
						readonly property var player: bar.playerFor(modelData)

						icon: special?.icon ?? ""
						value: icon === "" ? modelData.charAt(0).toUpperCase() : ""
						isActive: modelData === bar.visibleSpecial
						textColor: isActive ? Theme.accentBlue : (player?.isPlaying ? Theme.accentGreen : Theme.textDim)
						onActivated: Hypr.toggleSpecial(modelData)
						onRightClicked: bar.closeSpecial(modelData)
					}
				}
			}

			Pill {
				visible: Modes.powerSave
				icon: "leaf"
				onActivated: Commands.run("powersave")
			}
		}

		RowLayout {
			anchors.centerIn: parent
			spacing: 4

			Pill {
				readonly property bool valid: !isNaN(clockSource.date?.getTime?.() ?? NaN)
				readonly property date now: valid ? clockSource.date : new Date()
				value: Qt.formatDateTime(now, "hh:mm")
				onActivated: Hypr.toggleSpecial("calendar")

				SystemClock {
					id: clockSource
					// Seconds, not Minutes: the minute timer runs on the monotonic
					// clock, which stops in suspend, so after resume it kept the
					// pre-sleep time for up to a minute.
					precision: SystemClock.Seconds
				}
			}

			Pill {
				visible: Weather.current !== null
				icon: Weather.current?.icon ?? ""
				value: Weather.current ? Weather.current.tempNum + "°" : ""
				isActive: Panels.active === "weather"
				panel: "weather"
				onActivated: Panels.toggle("weather")
			}
		}

		RowLayout {
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			spacing: 6

			Pill {
				readonly property bool transcribing: Modes.dictation === "transcribing"
				visible: Modes.dictation !== ""
				text: transcribing ? "…" : "●"
				textColor: transcribing ? Theme.warning : Theme.critical
				isActive: true
				onActivated: Commands.script("dictation stop")
			}

			Pill {
				visible: Modes.recording
				text: "●"
				value: "REC"
				textColor: Theme.critical
				isActive: true
				onActivated: Commands.run("record")
			}

			Pill {
				visible: Modes.screencasts > 0
				icon: "screen-share"
				textColor: Theme.accentPurple
				isActive: true
			}

			Pill {
				visible: Modes.awake
				icon: "coffee"
				onActivated: Commands.run("awake")
			}

			Pill {
				custom: true
				isActive: Panels.active === "actions"
				panel: "actions"
				onActivated: Panels.toggle("actions")

				LineIcon {
					anchors.verticalCenter: parent.verticalCenter
					name: Bt.icon
					color: Bt.enabled ? Theme.textMain : Theme.textDim
				}

				LineIcon {
					anchors.verticalCenter: parent.verticalCenter
					name: Net.icon
					color: Net.online ? Theme.textMain : Theme.textDim
				}

				BatteryText {
					anchors.verticalCenter: parent.verticalCenter
					font.pixelSize: Theme.fontSizeSmall
				}
			}

			Pill {
				readonly property int count: Notifications.history.count
				readonly property bool isOpen: Panels.active === "notifications"

				icon: Notifications.dnd ? "bell-off" : (count > 0 ? "bell-dot" : "bell")
				textColor: Notifications.dnd ? Theme.warning : (count > 0 || isOpen ? Theme.accentBlue : Theme.textMain)
				isActive: isOpen
				panel: "notifications"
				onActivated: Panels.toggle("notifications")
			}
		}
	}
}
