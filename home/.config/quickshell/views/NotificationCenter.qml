import ".."
import "../widgets"
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Every notification kept, by app (the app with the newest first), newest first in each:
// Enter does what a click on it does, X dismisses it, the group's X its app's all.
Drawer {
	id: win

	name: "notifications"
	// The header, its line and what the list has; the drawer's most is the rest.
	contentHeight: 32 + 1 + 2 * column.spacing + (list.count > 0 ? list.contentHeight : 140)

	onOpened: {
		list.currentIndex = 0;
		list.forceActiveFocus();
	}

	// What the notification leads to takes the place of the center.
	function activate(nid): void {
		Notifications.activate(nid);
		Panels.close("notifications");
	}

	ColumnLayout {
		id: column
		anchors.fill: parent
		spacing: 12

		RowLayout {
			Layout.fillWidth: true
			Layout.preferredHeight: 32
			spacing: 10

			StyledText {
				text: "Notifications"
				font.pixelSize: Theme.fontSizeLarge
				font.bold: true
			}

			Rectangle {
				visible: list.count > 0
				implicitWidth: countLabel.implicitWidth + 12
				implicitHeight: 20
				radius: height / 2
				color: Theme.tint()
				border.color: Theme.tintBorder()
				border.width: 1

				StyledText {
					id: countLabel
					anchors.centerIn: parent
					text: list.count
					mono: true
					font.pixelSize: Theme.fontSizeTiny
					font.bold: true
					color: Theme.accentBlue
				}
			}

			Item {
				Layout.fillWidth: true
			}

			TextButton {
				visible: list.count > 0
				icon: "list-x"
				text: "Clear all"
				onClicked: Notifications.clear()
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

		SelectList {
			id: list
			visible: count > 0
			focus: true
			Layout.fillWidth: true
			Layout.fillHeight: true
			slidingHighlight: false
			spacing: 8
			model: Notifications.history
			onActivated: index => win.activate(Notifications.history.get(index).nid)

			section.property: "appName"
			section.delegate: Item {
				id: group
				required property string section
				readonly property int count: { Notifications.history.count; return Notifications.countOf(section); }

				width: ListView.view.rowWidth
				height: 30

				RowLayout {
					anchors.fill: parent
					anchors.bottomMargin: 4
					spacing: 8

					IconImage {
						readonly property var first: { Notifications.history.count; return Notifications.firstOf(group.section); }
						readonly property string path: first ? Notifications.appIconFor(first.desktopEntry, first.appName, first.appIcon) : ""
						visible: path !== ""
						implicitSize: 16
						source: path
						asynchronous: true
					}

					StyledText {
						Layout.fillWidth: true
						text: group.section || "Other"
						mono: true
						font.bold: true
						color: Theme.textDim
						elide: Text.ElideRight
					}

					StyledText {
						visible: group.count > 1
						text: group.count
						mono: true
						font.pixelSize: Theme.fontSizeTiny
						color: Theme.textMuted
					}

					CloseButton {
						implicitWidth: 22
						implicitHeight: 22
						onClicked: Notifications.dismissApp(group.section)
					}
				}
			}

			Keys.onPressed: event => {
				if (event.key === Qt.Key_X && !event.isAutoRepeat && count > 0)
					Notifications.dismiss(Notifications.history.get(currentIndex).nid);
			}

			delegate: NotificationCard {
				required property int index
				width: ListView.view.rowWidth
				isSelected: ListView.isCurrentItem

				HoverSelect {
					enabled: !list.dragging
					onSelected: list.currentIndex = index
				}
				onActivated: {
					list.currentIndex = index;
					win.activate(nid);
				}
				onDismissed: Notifications.dismiss(nid)
			}

			remove: Transition {
				NumberAnimation { property: "opacity"; to: 0; duration: Theme.animNormal; easing.type: Easing.OutCubic }
			}
			displaced: Transition {
				NumberAnimation { property: "y"; duration: Theme.animNormal; easing.type: Easing.OutCubic }
			}
		}

		Item {
			visible: list.count === 0
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

				StyledText {
					Layout.alignment: Qt.AlignHCenter
					text: "No notifications"
					font.bold: true
					color: Theme.textDim
				}
			}
		}
	}
}
