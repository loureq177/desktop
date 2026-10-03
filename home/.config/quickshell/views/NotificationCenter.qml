// Notification center: slide-in drawer from top-right.
// Displays notification history, live action triggers, DND toggle,
// and individual / bulk dismissal.
// Toggle via IPC: `qs ipc call notifications toggle` (SUPER + CTRL + comma).
// ESC or clicking outside dismisses the panel.
import ".."
import "../widgets"
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

SideDrawer {
	id: win

	shown: Notifications.centerOpen
	cardHeight: Math.min(680, win.height - Theme.notifTopMargin - 20)
	property int currentIndex: 0

	onOpened: {
		QuickSettings.close();
		Weather.close();
		win.currentIndex = 0;
		centerList.forceActiveFocus();
	}
	onDismissed: Notifications.closeCenter()

	Connections {
		target: Notifications
		function onHistoryChanged() {
			if (win.currentIndex >= Notifications.history.length)
				win.currentIndex = Math.max(0, Notifications.history.length - 1);
		}
	}

	ColumnLayout {
		anchors.fill: parent
		spacing: 12

			// ─── Header Bar ─────────────────────────────────────────────
			RowLayout {
				Layout.fillWidth: true
				Layout.preferredHeight: 32
				spacing: 10

				// Title + badge
				RowLayout {
					Layout.fillWidth: true
					spacing: 8

					Text {
						text: "Notifications"
						font.family: Theme.fontFamily
						font.pixelSize: Theme.fontSize + 1
						font.bold: true
						color: Theme.textMain
					}

					Rectangle {
						visible: Notifications.history.length > 0
						implicitWidth: countLabel.implicitWidth + 12
						implicitHeight: 20
						radius: height / 2
						color: Theme.selectionBg
						border.color: Theme.selectionBorder
						border.width: 1

						Text {
							id: countLabel
							anchors.centerIn: parent
							text: String(Notifications.history.length)
							font.family: Theme.fontMono
							font.pixelSize: Theme.fontSizeSmall - 1
							font.bold: true
							color: Theme.accentBlue
						}
					}
				}

				// Clear all button
				Rectangle {
					visible: Notifications.history.length > 0
					implicitWidth: clearRow.implicitWidth + 16
					implicitHeight: 28
					radius: Theme.roundingElement
					color: clearArea.containsMouse ? Theme.bgHover : "transparent"
					border.color: clearArea.containsMouse ? Theme.textDim : Theme.border
					border.width: 1

					Behavior on color { ColorAnimation { duration: 120 } }

					RowLayout {
						id: clearRow
						anchors.centerIn: parent
						spacing: 5

						Text {
							text: "󰎟"
							font.family: Theme.fontFamily
							font.pixelSize: 14
							color: clearArea.containsMouse ? Theme.textMain : Theme.textDim
						}

						Text {
							text: "Clear all"
							font.family: Theme.fontMono
							font.pixelSize: Theme.fontSizeSmall
							color: clearArea.containsMouse ? Theme.textMain : Theme.textDim
						}
					}

					MouseArea {
						id: clearArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: Notifications.clear()
					}
				}

				// Close (✕) button
				CloseButton {
					onClicked: Notifications.closeCenter()
				}
			}

			// Subtle 1px separator
			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 1
				color: Theme.border
			}

			// ─── Notification List ──────────────────────────────────────
			ListView {
				id: centerList
				visible: Notifications.history.length > 0
				Layout.fillWidth: true
				Layout.fillHeight: true
				clip: true
				boundsBehavior: Flickable.DragAndOvershootBounds
				flickDeceleration: Theme.flickDecel
				maximumFlickVelocity: Theme.maxFlickVel
				spacing: 8
				model: Notifications.history
				currentIndex: win.currentIndex
				highlightFollowsCurrentItem: true
				highlightMoveDuration: 0
				focus: true

				Keys.onPressed: event => {
					var count = Notifications.history.length;
					if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
						if (count > 0) {
							win.currentIndex = Math.min(count - 1, win.currentIndex + 1);
							centerList.positionViewAtIndex(win.currentIndex, ListView.Visible);
						}
						event.accepted = true;
					} else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
						if (count > 0) {
							win.currentIndex = Math.max(0, win.currentIndex - 1);
							centerList.positionViewAtIndex(win.currentIndex, ListView.Visible);
						}
						event.accepted = true;
					} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
						if (count > 0 && win.currentIndex >= 0 && win.currentIndex < count) {
							Notifications.activate(Notifications.history[win.currentIndex].id);
						}
						event.accepted = true;
					} else if (event.key === Qt.Key_X) {
						if (count > 0 && win.currentIndex >= 0 && win.currentIndex < count) {
							var idToDismiss = Notifications.history[win.currentIndex].id;
							Notifications.dismissEntry(idToDismiss);
							if (win.currentIndex >= count - 1) {
								win.currentIndex = Math.max(0, count - 2);
							}
						}
						event.accepted = true;
					} else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
						Notifications.closeCenter();
						event.accepted = true;
					}
				}

				ScrollBar.vertical: ScrollBar {
					id: vScrollBar
					visible: size < 1.0
					active: size < 1.0
					policy: ScrollBar.AsNeeded
					contentItem: Rectangle {
						implicitWidth: 4
						radius: Theme.roundingSubtle
						color: parent.hovered || parent.pressed ? Theme.textDim : Theme.border
					}
				}

				delegate: Item {
					id: entryWrap
					required property var modelData
					required property int index
					property bool dismissing: false

					width: ListView.view.width
					implicitHeight: dismissing ? 0 : card.implicitHeight
					clip: true

					Behavior on implicitHeight {
						enabled: entryWrap.dismissing
						NumberAnimation {
							duration: 200
							easing.type: Easing.OutCubic
							onRunningChanged: {
								if (!running && entryWrap.dismissing) {
									Notifications.dismissEntry(modelData.id);
								}
							}
						}
					}

					NotificationCard {
						id: card
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.rightMargin: (centerList.ScrollBar.vertical && centerList.ScrollBar.vertical.visible) ? 10 : 0
						anchors.top: parent.top
						notif: modelData
						isSelected: index === win.currentIndex
						isToast: false
						showTime: true

						opacity: entryWrap.dismissing ? 0.0 : 1.0
						transform: Translate {
							x: entryWrap.dismissing ? 60 : 0
							Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
						}
						Behavior on opacity {
							enabled: entryWrap.dismissing
							NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
						}

						onActivated: {
							win.currentIndex = index;
							Notifications.activate(modelData.id);
						}
						onDismissed: {
							entryWrap.dismissing = true;
						}
					}
				}
			}

			// ─── Empty State ────────────────────────────────────────────
			Item {
				visible: Notifications.history.length === 0
				Layout.fillWidth: true
				Layout.fillHeight: true

				ColumnLayout {
					anchors.centerIn: parent
					spacing: 10

					Text {
						Layout.alignment: Qt.AlignHCenter
						text: "󰂜"
						font.family: Theme.fontFamily
						font.pixelSize: 44
						color: Theme.textMuted
					}

					Text {
						Layout.alignment: Qt.AlignHCenter
						text: "No notifications"
						font.family: Theme.fontFamily
						font.pixelSize: Theme.fontSize
						font.bold: true
						color: Theme.textDim
					}
				}
			}
	}
}
