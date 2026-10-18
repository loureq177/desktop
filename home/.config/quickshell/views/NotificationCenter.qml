import ".."
import "../widgets"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

SideDrawer {
	id: win

	panel: "notifications"
	cardHeight: Math.min(680, win.height - Theme.notifTopMargin - 20)
	property int currentIndex: 0

	onOpened: {
		win.currentIndex = 0;
		centerList.forceActiveFocus();
	}

	onCurrentIndexChanged: centerList.positionViewAtIndex(currentIndex, ListView.Contain)

	ColumnLayout {
		anchors.fill: parent
		spacing: 12

		RowLayout {
			Layout.fillWidth: true
			Layout.preferredHeight: 32
			spacing: 10

			Text {
				text: "Notifications"
				font.family: Theme.fontFamily
				font.pixelSize: Theme.fontSize + 1
				font.bold: true
				color: Theme.textMain
			}

			Rectangle {
				visible: Notifications.history.count > 0
				implicitWidth: countLabel.implicitWidth + 12
				implicitHeight: 20
				radius: height / 2
				color: Theme.selectionBg
				border.color: Theme.selectionBorder
				border.width: 1

				Text {
					id: countLabel
					anchors.centerIn: parent
					text: String(Notifications.history.count)
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeSmall - 1
					font.bold: true
					color: Theme.accentBlue
				}
			}

			Item {
				Layout.fillWidth: true
			}

			Rectangle {
				visible: Notifications.history.count > 0
				implicitWidth: clearRow.implicitWidth + 16
				implicitHeight: 28
				radius: Theme.roundingElement
				color: clearArea.containsMouse ? Theme.bgHover : "transparent"
				border.color: clearArea.containsMouse ? Theme.tileBorderHover : Theme.tileBorder
				border.width: 1

				Behavior on color { ColorAnimation { duration: 120 } }

				RowLayout {
					id: clearRow
					anchors.centerIn: parent
					spacing: 5

					LineIcon {
						name: "list-x"
						size: 14
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

			CloseButton {
				onClicked: Panels.close("notifications")
			}
		}

		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: 1
			color: Theme.border
		}

		ListView {
			id: centerList
			visible: count > 0
			Layout.fillWidth: true
			Layout.fillHeight: true
			clip: true
			boundsBehavior: Flickable.DragAndOvershootBounds
			flickDeceleration: Theme.flickDecel
			maximumFlickVelocity: Theme.maxFlickVel
			spacing: 8
			model: Notifications.history
			currentIndex: win.currentIndex
			focus: true

			onCountChanged: {
				if (win.currentIndex >= count)
					win.currentIndex = Math.max(0, count - 1);
			}

			Keys.onPressed: event => {
				var current = win.currentIndex < count ? Notifications.history.get(win.currentIndex).nid : -1;
				if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
					win.currentIndex = Math.min(count - 1, win.currentIndex + 1);
				} else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
					win.currentIndex = Math.max(0, win.currentIndex - 1);
				} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
					if (!event.isAutoRepeat && current !== -1)
						Notifications.activate(current);
				} else if (event.key === Qt.Key_X) {
					if (!event.isAutoRepeat && current !== -1)
						Notifications.dismiss(current);
				} else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
					Panels.close("notifications");
				} else {
					return;
				}
				event.accepted = true;
			}

			ScrollBar.vertical: ThinScrollBar {}

			WheelScroll {
				flickable: centerList
			}

			delegate: NotificationCard {
				required property int index

				width: ListView.view.width - (centerList.ScrollBar.vertical.visible ? 10 : 0)
				isSelected: index === win.currentIndex

				HoverSelect {
					enabled: !centerList.moving
					onSelected: win.currentIndex = index
				}
				onActivated: {
					win.currentIndex = index;
					Notifications.activate(nid);
				}
				onDismissed: Notifications.dismiss(nid)
			}

			remove: Transition {
				NumberAnimation { property: "opacity"; to: 0; duration: 180; easing.type: Easing.OutCubic }
			}
			displaced: Transition {
				NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic }
			}
		}

		Item {
			visible: centerList.count === 0
			Layout.fillWidth: true
			Layout.fillHeight: true

			ColumnLayout {
				anchors.centerIn: parent
				spacing: 10

				LineIcon {
					Layout.alignment: Qt.AlignHCenter
					name: "bell"
					size: 44
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
