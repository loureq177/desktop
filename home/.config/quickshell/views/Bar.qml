import ".."
import "../widgets"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

PanelWindow {
	id: bar

	required property var modelData
	readonly property string screenName: modelData?.name ?? ""

	screen: modelData
	color: "transparent"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell"

	// Quickshell's own id of the focused one is right, and at once.
	readonly property int activeWorkspaceId: Hyprland.monitorFor(modelData)?.activeWorkspace?.id ?? -1
	visible: !Hypr.fullscreenOn(modelData)

	anchors {
		top: true
		left: true
		right: true
	}

	// Screen wide for its corners; only the strip and the corners take input.
	implicitHeight: Theme.barMarginY + Theme.barHeight
	mask: Region {
		item: strip

		Region {
			item: launcherCorner
		}
		Region {
			item: actionsCorner
		}
	}
	exclusionMode: ExclusionMode.Normal
	exclusiveZone: Theme.barMarginY + Theme.barHeight - Theme.barGapTrim

	Component.onCompleted: Bars.add(bar)
	Component.onDestruction: Bars.remove(bar)

	// Hyprland only reports the visible special through events; the monitor
	// snapshot covers the time before the first one arrives.
	property var specialEvent: null
	readonly property string visibleSpecial: String(specialEvent ?? Hyprland.monitorFor(modelData)?.lastIpcObject?.specialWorkspace?.name ?? "").replace(/^special:/, "")
	// Joined first so the list only changes when the set of specials does.
	readonly property string specialsKey: Hypr.specials
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

	// A click on a module puts the open panel away, unless it is the module's own
	// (`except`).
	function leavePanels(except: string): void {
		if (Panels.active !== "" && Panels.active !== except)
			Panels.close();
	}

	function playerFor(special: string): var {
		return Mpris.players.values.find(p => ((p?.desktopEntry ?? "") + " " + (p?.identity ?? "")).toLowerCase().includes(special)) ?? null;
	}

	Leaving {
		id: workspaceDots
		values: Hypr.workspaces.filter(w => w.monitor === bar.screenName).map(w => w.id)
	}

	Leaving {
		id: specialIcons
		values: bar.specialsKey !== "" ? bar.specialsKey.split("\n") : []
	}

	// The name of the special under the pointer, beside the row: said in the row, it would
	// push the next icon from under the pointer.
	property string specialHint: ""
	property string lastSpecialHint: ""
	onSpecialHintChanged: {
		if (specialHint !== "")
			lastSpecialHint = specialHint;
	}

	// Colours: blue is on screen or wants attention, green running, dim off; readouts
	// are textMain, the workspaces textDim.

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
		// A readout only: no hover, no clicks.
		property bool interactive: true
		// Hover says more, but a click does nothing.
		property bool clickable: true
		// On the bar; it opens up and closes in place.
		property bool shown: true
		// Lit for a moment: something happened.
		property real flash: 0
		// For a mark that shows the date.
		property int iconDay: 0
		readonly property bool hovered: pillArea.containsMouse
		readonly property real mouseX: pillArea.mouseX
		readonly property bool wanted: shown && (text !== "" || icon !== "" || value !== "" || custom)
		property real revealed: 0
		default property alias content: pillRow.data
		signal activated()
		signal rightClicked()
		// On the button's release: while it is held, Hyprland keeps the focus on the bar.
		signal released()

		Layout.alignment: Qt.AlignVCenter
		implicitHeight: Theme.barHeight
		implicitWidth: (pillRow.implicitWidth + 14) * revealed
		visible: revealed > 0
		opacity: revealed
		clip: revealed < 1
		color: isActive ? Theme.alpha(Theme.accentBlue, 0.16) : (hovered && clickable ? bar.hoverColor : "transparent")
		radius: Theme.roundingElement

		Component.onCompleted: revealed = Qt.binding(() => wanted ? 1 : 0)

		Behavior on revealed {
			NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
		}
		Behavior on color {
			ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
		}

		Press {
			id: pillPress
			target: pillFace
		}

		Lit {
			id: pillFace
			anchors.centerIn: parent
			halo: true
			lit: pill.hovered
			rest: pill.textColor
			flash: pill.flash

		Row {
			id: pillRow
			spacing: pill.custom ? 10 : 6

			LineIcon {
				anchors.verticalCenter: parent.verticalCenter
				name: pill.icon
				day: pill.iconDay
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
				font.pixelSize: Theme.fontSizeBar
				font.bold: true
				color: pill.textColor
			}
		}
		}

		MouseArea {
			id: pillArea
			anchors.fill: parent
			enabled: pill.interactive
			hoverEnabled: true
			cursorShape: pill.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
			acceptedButtons: Qt.LeftButton | Qt.RightButton
			onPressed: mouse => {
				if (pill.clickable)
					pillPress.restart();
				if (pill.panel === "" || mouse.button !== Qt.LeftButton)
					bar.leavePanels(pill.panel);
				if (mouse.button === Qt.RightButton)
					pill.rightClicked();
				else
					pill.activated();
			}
			onClicked: mouse => {
				if (mouse.button === Qt.LeftButton)
					pill.released();
			}
		}
	}

	TrayMenu {
		id: trayMenu
	}

	BarTip {
		target: system
		shown: system.hovered && !system.overBt && Battery.present && Panels.active !== "actions"
		text: Battery.percent + "%"
	}

	BarTip {
		target: btIcon
		gap: (Theme.barHeight - btIcon.height) / 2 + 6
		shown: system.overBt && Panels.active !== "actions"
		text: Bt.connected.map(d => Bt.name(d) + (d.batteryAvailable ? "  " + Math.round(d.battery * 100) + "%" : "")).join("\n")
	}

	HotCorner {
		id: launcherCorner
		panel: "launcher"
		mode: "apps"
	}

	HotCorner {
		id: actionsCorner
		x: parent.width - width
		panel: "actions"
	}

	Item {
		id: strip
		x: Theme.barMarginX
		y: Theme.barMarginY
		width: parent.width - Theme.barMarginX * 2
		height: Theme.barHeight

		MouseArea {
			anchors.fill: parent
			z: -1
			enabled: Panels.active !== "" || bar.visibleSpecial !== ""
			// Panels first; with none open, the click puts the special away.
			property bool hides: false
			onPressed: {
				hides = Panels.active === "";
				Panels.close();
			}
			onReleased: {
				if (hides && bar.visibleSpecial !== "")
					Hypr.toggleSpecial(bar.visibleSpecial);
			}
		}

		RowLayout {
			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			spacing: 6

			Pill {
				icon: "search"
				textColor: isActive ? Theme.accentBlue : Theme.textMain
				isActive: Panels.active === "launcher"
				panel: "launcher"
				onActivated: Panels.toggle("launcher", "apps")
				onRightClicked: Panels.toggle("launcher", "windows")
			}

			Row {
				Layout.alignment: Qt.AlignVCenter
				height: Theme.barHeight
				layer.enabled: true
				layer.effect: Halo {}

				Repeater {
					model: ScriptModel {
						values: workspaceDots.shown
					}

					delegate: Item {
						id: wsButton
						required property int modelData
						readonly property bool active: bar.activeWorkspaceId === modelData
						readonly property bool wanted: workspaceDots.values.includes(modelData)
						property real revealed: 0

						height: Theme.barHeight
						width: (wsDot.width + 10) * revealed
						opacity: revealed

						Component.onCompleted: revealed = Qt.binding(() => wanted ? 1 : 0)

						Behavior on revealed {
							NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
						}

						Rectangle {
							id: wsDot
							anchors.centerIn: parent
							width: wsButton.active ? 26 : 8
							height: 8
							radius: 4
							color: wsButton.active ? Theme.accentBlue : (wsArea.containsMouse ? Theme.textMain : Theme.textDim)

							Behavior on width {
								NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
							}
							Behavior on color {
								ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
							}
						}

						Press {
							id: wsPress
							target: wsDot
						}

						MouseArea {
							id: wsArea
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onPressed: wsPress.restart()
							onClicked: {
								bar.leavePanels("");
								Hypr.focusWorkspace(wsButton.modelData);
							}
						}
					}
				}
			}

			// The activity special, with the memory's number once it is high; the other open
			// specials follow it, side by side. Actions always has the number.
			Row {
				Layout.alignment: Qt.AlignVCenter

				Pill {
					readonly property bool high: Memory.percent > 70

					shown: high || Hypr.specials.includes("activity")
					interactive: Specials.find("activity") !== null
					icon: "memory-stick"
					value: high ? Memory.percent + "%" : ""
					isActive: bar.visibleSpecial === "activity"
					textColor: Memory.percent >= 90 ? Theme.critical
						: Memory.percent >= 75 ? Theme.warning
						: isActive ? Theme.accentBlue : Theme.textDim
					onReleased: Hypr.toggleSpecial("activity")
					onRightClicked: Hypr.closeSpecial("activity")
				}

				// The app's mark (LineIcons.brands), as the tray shows its apps:
				// blue while it is on screen, green while it plays something.
				Repeater {
					model: ScriptModel {
						values: specialIcons.shown
					}

					delegate: Pill {
						id: specialPill
						required property string modelData
						readonly property var special: Specials.find(modelData)
						readonly property var player: special?.player ? bar.playerFor(special.player) : null

						// An app of your own has no mark: its theme icon, in the bar's colour.
						readonly property string themeIcon: icon === "" && special?.appIcon !== "web-browser" ? Quickshell.iconPath(special?.appIcon ?? "", true) : ""

						icon: special?.icon ?? ""
						iconDay: clock.now.getDate()
						custom: themeIcon !== ""
						shown: specialIcons.values.includes(modelData)
						value: icon === "" && themeIcon === "" ? modelData.charAt(0).toUpperCase() : ""
						isActive: modelData === bar.visibleSpecial
						textColor: isActive ? Theme.accentBlue : (player?.isPlaying ? Theme.accentGreen : Theme.textDim)
						// What it plays, or what it is.
						readonly property string hint: player?.trackTitle ? [player.trackArtist, player.trackTitle].filter(t => t).join(" – ") : special?.title ?? modelData
						// Leaving one comes after entering the next: only its own name goes.
						onHoveredChanged: {
							if (hovered)
								bar.specialHint = hint;
							else if (bar.specialHint === hint)
								bar.specialHint = "";
						}
						onHintChanged: {
							if (hovered)
								bar.specialHint = hint;
						}
						Component.onDestruction: {
							if (bar.specialHint === hint)
								bar.specialHint = "";
						}
						onReleased: Hypr.toggleSpecial(modelData)
						onRightClicked: Hypr.closeSpecial(modelData)

						IconImage {
							anchors.verticalCenter: parent.verticalCenter
							visible: specialPill.themeIcon !== ""
							implicitSize: 16
							source: specialPill.themeIcon
							layer.enabled: true
							layer.effect: MultiEffect {
								saturation: -1.0
								colorization: 1.0
								colorizationColor: specialPill.textColor
							}
						}
					}
				}
			}

			StyledText {
				id: hintText
				Layout.alignment: Qt.AlignVCenter
				Layout.leftMargin: 2
				Layout.maximumWidth: 360
				visible: opacity > 0
				text: bar.lastSpecialHint
				font.pixelSize: Theme.fontSizeBar
				font.bold: true
				color: Theme.textMain
				elide: Text.ElideRight
				opacity: bar.specialHint !== "" ? 1 : 0
				layer.enabled: true
				layer.effect: Halo {}
				transform: Translate {
					x: (hintText.opacity - 1) * 6
				}

				Behavior on opacity {
					NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
				}
			}
		}

		// What comes and goes stands first: the row grows to the left, so the rest stays put.
		RowLayout {
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			spacing: 0

			// The tray apps that have something to show (Discord, Steam), in the bar's colour;
			// click as the app does, right-click for its menu. Not LocalSend: always there.
			Repeater {
				model: ScriptModel {
					values: SystemTray.items.values.filter(i => i.status !== Status.Passive && !i.title.includes("localsend"))
				}

				delegate: Pill {
					id: trayPill
					required property SystemTrayItem modelData

					custom: true
					onActivated: modelData.onlyMenu ? showMenu() : modelData.activate()
					onRightClicked: modelData.hasMenu ? showMenu() : modelData.secondaryActivate()

					function showMenu(): void {
						trayMenu.open(trayPill, modelData.menu);
					}

					IconImage {
						readonly property bool colored: trayPill.hovered || trayPill.modelData.status === Status.NeedsAttention

						anchors.verticalCenter: parent.verticalCenter
						implicitSize: 16
						source: trayPill.modelData.icon
						layer.enabled: !colored
						layer.effect: MultiEffect {
							saturation: -1.0
							brightness: 0.7
							colorization: 1.0
							colorizationColor: Theme.textMain
						}
					}
				}
			}

			Pill {
				id: dictationPill
				// Only while listening: the transcription takes a moment, so stopping closes it.
				shown: Modes.dictation === "recording"
				custom: true
				textColor: Theme.critical
				isActive: true
				onActivated: Commands.script("dictation stop")

				// The microphone grows a little with the voice, and stays put in a quiet room.
				LineIcon {
					anchors.verticalCenter: parent.verticalCenter
					name: "mic"
					color: Theme.critical
					scale: 1 + 0.3 * Audio.micLevel

					Behavior on scale {
						NumberAnimation { duration: 60 }
					}
				}
			}

			Pill {
				shown: Modes.recording
				text: "●"
				value: "REC"
				textColor: Theme.critical
				isActive: true
				onActivated: Commands.run("record")
			}

			Pill {
				shown: Modes.screencasts > 0 && !Modes.listingWindows
				interactive: false
				icon: "screen-share"
				textColor: Theme.accentPurple
				isActive: true
			}

			Pill {
				shown: Weather.current !== null
				icon: Weather.current?.icon ?? ""
				value: Weather.current ? Weather.current.tempNum + "°" : ""
				isActive: Panels.active === "weather"
				panel: "weather"
				onActivated: Panels.toggle("weather")
			}

			Pill {
				id: system
				// The pill's MouseArea takes the hover: up to halfway into the gap after the icon.
				readonly property bool overBt: hovered && btIcon.visible
					&& mouseX < btIcon.mapToItem(system, btIcon.width + 5, 0).x

				custom: true
				isActive: Panels.active === "actions"
				panel: "actions"
				onActivated: Panels.toggle("actions")

				// Only with a device: on or off says nothing worth the room.
				LineIcon {
					id: btIcon
					anchors.verticalCenter: parent.verticalCenter
					visible: Bt.connected.length > 0
					name: Bt.icon
					color: Theme.textMain
				}

				// Only when down; online, only with no battery to open Actions by.
				LineIcon {
					anchors.verticalCenter: parent.verticalCenter
					visible: !Net.online || !Battery.present
					name: Net.icon
					color: Modes.awake ? Theme.accentBlue : Net.online ? Theme.textMain : Theme.textDim
				}

				BatteryIcon {
					anchors.verticalCenter: parent.verticalCenter
					// One colour at a time: running low comes first, then keep awake.
					color: Modes.awake && !Battery.low ? Theme.accentBlue : Battery.color
				}
			}

			// The date and the time, and the notifications behind a click, as on a Mac. A dot at
			// the time's corner: blue for notifications kept, yellow for do not disturb, as its tile.
			Pill {
				id: clock
				property date now: new Date()
				readonly property int count: Notifications.history.count
				property int seen: 0

				custom: true
				isActive: Panels.active === "notifications"
				panel: "notifications"
				onActivated: Panels.toggle("notifications")
				onCountChanged: {
					if (count > seen && !Notifications.dnd)
						arrived.restart();
					seen = count;
				}
				Component.onCompleted: seen = count

				StyledText {
					anchors.verticalCenter: parent.verticalCenter
					text: clock.now.toLocaleDateString(Qt.locale("en_GB"), "d MMM")
					font.bold: true
					font.pixelSize: Theme.fontSizeBar
				}

				StyledText {
					id: time
					anchors.verticalCenter: parent.verticalCenter
					text: Qt.formatDateTime(clock.now, "hh:mm")
					mono: true
					font.bold: true
					font.pixelSize: Theme.fontSizeBar
				}

				// In the pill's margin, out of the row: the time keeps its place at the bar's end.
				// Not lit with the row, whose light is cut to what the row holds.
				Rectangle {
					id: mark
					readonly property bool kept: clock.count > 0

					parent: clock
					x: clock.width - 2
					y: (clock.height - time.implicitHeight) / 2 + 3
					width: 6
					height: 6
					radius: 3
					visible: kept || Notifications.dnd
					color: !kept ? "transparent" : Notifications.dnd ? Theme.warning : Theme.accentBlue
					border.width: kept ? 0 : 1.5
					border.color: Theme.warning

					// Pops once as one comes in.
					SequentialAnimation {
						id: arrived
						NumberAnimation { target: mark; property: "scale"; to: 1.8; duration: Theme.animFast; easing.type: Easing.OutCubic }
						NumberAnimation { target: mark; property: "scale"; to: 1; duration: Theme.animNormal; easing.type: Easing.InOutSine }
					}
				}

				// Not SystemClock, which spins in the hour a DST change repeats; a second's tick
				// is at most a second stale after resume.
				Timer {
					running: true
					repeat: true
					onTriggered: clock.now = new Date()
				}
			}
		}
	}
}
