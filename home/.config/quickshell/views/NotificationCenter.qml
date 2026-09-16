// Notification center: replaces the SwayNC control center.
// Same panel size and placement (500px, top-right below the bar); the panel
// slides in from the right screen edge like the toasts. Toggle with
// `qs ipc call notifications toggle` (SUPER + CTRL + comma). ESC closes it;
// clicking anywhere outside the panel just closes it (toasts stay);
// the per-card ✕ dismisses a single notification (live or history entry).
import ".."
import "../widgets"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
	id: win

	// Shown while the center is open; unmap is deferred until the
	// slide-out animation finishes.
	property bool shown: Notifications.centerOpen
	// 0 = on screen; width + margin = fully off the right edge.
	property int slide: Theme.notifWidth + Theme.notifRightMargin

	visible: shown || slideOut.running
	color: "transparent"
	exclusiveZone: 0

	onShownChanged: {
		if (shown) {
			slideOut.stop();
			slideIn.restart();
		} else {
			slideIn.stop();
			slideOut.restart();
		}
	}

	SequentialAnimation {
		id: slideIn

		NumberAnimation {
			target: win
			property: "slide"
			to: 0
			duration: 300
			easing.type: Easing.OutCubic
		}
	}

	SequentialAnimation {
		id: slideOut

		NumberAnimation {
			target: win
			property: "slide"
			to: Theme.notifWidth + Theme.notifRightMargin
			duration: 300
			easing.type: Easing.OutCubic
		}
	}

	WlrLayershell.layer: WlrLayer.Overlay
	// Exclusive keyboard focus while open so ESC reaches the center.
	WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell"

	screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	// ESC dismisses the center (keyboard arrives via the layershell focus).
	Shortcut {
		sequences: ["Esc"]
		enabled: win.visible
		onActivated: Notifications.closeCenter()
	}

	// Clicking anywhere outside the panel closes the center
	// (and dismisses the toasts with it).
	MouseArea {
		anchors.fill: parent
		onClicked: Notifications.closeCenter()
	}

	Rectangle {
		id: card

		x: parent.width - width - Theme.notifRightMargin + win.slide
		y: Theme.notifTopMargin
		width: Theme.notifWidth
		height: 600
		color: Theme.bgMain
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingWindow

		// Absorb clicks inside the panel so they don't close the center.
		MouseArea {
			anchors.fill: parent
		}

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: Theme.paddingCard
			spacing: Theme.paddingItem

			RowLayout {
				Layout.fillWidth: true
				spacing: Theme.paddingItem

				Text {
					Layout.fillWidth: true
					text: "Notifications"
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSize + 1
					font.bold: true
					color: Theme.accentBlue
				}

				Text {
					text: "DND"
					font.family: Theme.fontMono
					font.pointSize: Theme.fontSizeSmall
					color: Notifications.dnd ? Theme.accentGreen : Theme.textDim
				}
				Rectangle {
					id: dndSwitch
					implicitWidth: 44
					implicitHeight: 24
					radius: Theme.roundingElement
					color: Notifications.dnd ? Theme.accentGreen : Theme.bgCard
					border.color: Theme.border
					border.width: 1
					Rectangle {
						anchors.verticalCenter: parent.verticalCenter
						x: Notifications.dnd ? parent.width - width - 3 : 3
						width: 18
						height: 18
						radius: Theme.roundingElement
						color: Theme.textMain
					}
					MouseArea {
						anchors.fill: parent
						onClicked: Notifications.toggleDnd()
					}
				}

				Rectangle {
					implicitWidth: clearLabel.implicitWidth + 20
					implicitHeight: 28
					color: Theme.bgCard
					border.color: Theme.border
					border.width: 1
					radius: Theme.roundingElement
					Text {
						id: clearLabel
						anchors.centerIn: parent
						text: "Clear"
						font.family: Theme.fontMono
						font.pointSize: Theme.fontSizeSmall
						color: Theme.textDim
					}
					MouseArea {
						anchors.fill: parent
						onClicked: Notifications.clear()
					}
				}

				Text {
					text: "✕"
					font.pixelSize: 14
					color: Theme.textDim
					MouseArea {
						anchors.fill: parent
						onClicked: Notifications.toggle()
					}
				}
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 1
				color: Theme.border
			}

			ListView {
				id: centerList
				visible: Notifications.history.length > 0
				Layout.fillWidth: true
				Layout.fillHeight: true
				clip: true
				spacing: 8
				model: Notifications.history

			delegate: Rectangle {
				id: entry
				required property var modelData
				property var snap: modelData
				property bool critical: snap.urgency === NotificationUrgency.Critical
				// Action buttons stay visible only while the live
				// notification still exists (history entries outlive it).
				// The "default" action is not a button: body clicks invoke it.
				readonly property var live: Notifications.liveById(snap.id)
				readonly property var actionEntries: {
					var t = entry.live;
					var out = [];
					if (!t || !t.actions)
						return out;
					for (var i = 0; i < t.actions.length; i++) {
						if (t.actions[i].identifier === "default")
							continue;
						out.push({
							identifier: t.actions[i].identifier || "",
							text: t.actions[i].text || "Action",
							snapId: snap.id
						});
					}
					return out;
				}

				width: ListView.view.width
				implicitHeight: Math.max(cardRow.implicitHeight, 40) + Theme.notifPadV * 2
				color: rowArea.containsMouse ? Theme.bgHover : Theme.bgCard
				border.color: entry.critical ? Theme.critical : Theme.border
				border.width: 1
				radius: Theme.roundingElement

				Behavior on color {
					ColorAnimation { duration: 120 }
				}

				// Clicking the body invokes the default action (SwayNC parity).
				MouseArea {
					id: rowArea
					anchors.fill: parent
					hoverEnabled: true
					enabled: entry.live
					onClicked: Notifications.activate(entry.snap.id)
				}

				Rectangle {
					visible: parent.critical
					anchors.top: parent.top
					anchors.bottom: parent.bottom
					anchors.left: parent.left
					anchors.leftMargin: Theme.borderSize
					width: 3
					color: Theme.critical
				}

				RowLayout {
					id: cardRow
					anchors.left: parent.left
					anchors.right: parent.right
					anchors.top: parent.top
					anchors.leftMargin: Theme.notifPadH
					anchors.rightMargin: Theme.notifPadH
					anchors.topMargin: Theme.notifPadV
					anchors.bottomMargin: Theme.notifPadV
					spacing: 12

					NotificationPicture {
						id: centerPic
						image: entry.snap.image || ""
						appIcon: entry.snap.appIcon || ""
						size: 48
						Layout.preferredWidth: centerPic.visible ? 48 : 0
						Layout.preferredHeight: centerPic.visible ? 48 : 0
						Layout.alignment: Qt.AlignTop
					}

					ColumnLayout {
						id: centerBody
						Layout.fillWidth: true
						spacing: 4

						RowLayout {
							Layout.fillWidth: true
							Text {
								Layout.fillWidth: true
								text: entry.snap.appName || ""
								font.family: Theme.fontMono
								font.pointSize: Theme.fontSizeSmall
								font.bold: true
								color: Theme.textDim
								elide: Text.ElideRight
								visible: text !== ""
							}
							Text {
								text: Qt.formatDateTime(new Date(entry.snap.time), "hh:mm")
								font.family: Theme.fontMono
								font.pointSize: Theme.fontSizeSmall
								color: Theme.textMuted
							}
						}
						Text {
							Layout.fillWidth: true
							text: entry.snap.summary || ""
							font.family: Theme.fontFamily
							font.pixelSize: Theme.fontSize
							font.bold: true
							color: Theme.textMain
							wrapMode: Text.WordWrap
							visible: text !== ""
						}
						Text {
							Layout.fillWidth: true
							text: entry.snap.body || ""
							font.family: Theme.fontFamily
							font.pixelSize: Theme.fontSizeSmall + 1
							color: Theme.textDim
							wrapMode: Text.WordWrap
							maximumLineCount: 6
							elide: Text.ElideRight
							textFormat: Text.PlainText
							visible: text !== ""
						}
						// Actions share one row instead of stacking, and
						// only while the live notification still exists.
						RowLayout {
							visible: entry.actionEntries.length > 0
							Layout.fillWidth: true
							spacing: 6
							Repeater {
								model: entry.actionEntries
								delegate: NotificationActionButton {
									required property var modelData
									Layout.fillWidth: true
									notifId: modelData.snapId
									identifier: modelData.identifier
									label: modelData.text
								}
							}
						}
					}

					// Per-card close: works on live notifications and
					// history-only entries alike.
					Text {
						Layout.alignment: Qt.AlignTop
						text: "✕"
						font.pixelSize: 16
						color: closeArea.containsMouse ? Theme.critical : Theme.textMuted

						MouseArea {
							id: closeArea
							anchors.fill: parent
							anchors.margins: -10
							hoverEnabled: true
							onClicked: Notifications.dismissEntry(entry.snap.id)
						}
					}
				}
			}
			}

			Text {
				visible: Notifications.history.length === 0
				Layout.fillWidth: true
				Layout.fillHeight: true
				horizontalAlignment: Text.AlignHCenter
				verticalAlignment: Text.AlignVCenter
				text: "󰂜\nNo notifications"
				font.family: Theme.fontMono
				font.pointSize: Theme.fontSizeBar
				color: Theme.textMuted
				lineHeight: 1.6
			}
		}
	}
}
