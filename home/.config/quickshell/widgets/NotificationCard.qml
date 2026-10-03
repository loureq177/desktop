// Shared notification card component: used in both NotificationToasts (floating toasts)
// and NotificationCenter (history drawer). Displays urgency indicator, picture/icon,
// app name, timestamp, summary, body, inline reply field, and action buttons.
import ".."
import "."
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Rectangle {
	id: root

	property var notif: null
	property bool isSelected: false
	property bool isToast: false
	property bool showTime: true

	readonly property bool critical: !!(notif && notif.urgency === NotificationUrgency.Critical)
	readonly property var liveNotif: notif ? Notifications.liveById(notif.id) : null
	readonly property bool canReply: !!(liveNotif && liveNotif.hasInlineReply)
	readonly property var actionEntries: notif ? (isToast ? Notifications.entriesFromActions(notif.id, notif.actions) : Notifications.historyActionEntries(notif)) : []

	signal activated()
	signal dismissed()
	signal replyFocusGained()
	signal replyFocusLost()

	width: parent ? parent.width : Theme.notifWidth
	implicitHeight: Math.max(bodyCol.implicitHeight + Theme.notifPadV * 2, notifPic.size + Theme.notifPadV * 2)
	color: hoverArea.containsMouse ? Theme.bgHover : (isToast ? Theme.bgCard : Theme.bgMain)
	border.color: critical ? Theme.critical : (isSelected ? Theme.selectionBorder : (hoverArea.containsMouse ? Theme.textDim : Theme.border))
	border.width: isToast ? Theme.borderSize : 1
	radius: Theme.roundingElement
	clip: true

	Behavior on color { ColorAnimation { duration: 100 } }
	Behavior on border.color { ColorAnimation { duration: 100 } }

	// Selection highlight overlay for keyboard navigation in center list
	Rectangle {
		anchors.fill: parent
		visible: root.isSelected && !root.isToast
		color: Theme.selectionBg
		radius: Theme.roundingElement
		z: 0
	}

	// Body click activates default action (or dismisses if no action)
	MouseArea {
		id: hoverArea
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		acceptedButtons: Qt.LeftButton
		onClicked: root.activated()
	}

	// Notification picture / icon
	NotificationPicture {
		id: notifPic
		anchors.left: parent.left
		anchors.leftMargin: Theme.notifPadH
		anchors.verticalCenter: parent.verticalCenter
		size: 64
		image: root.notif ? (root.notif.image || "") : ""
		appIcon: root.notif ? (root.notif.appIcon || "") : ""
		appName: root.notif ? (root.notif.appName || "") : ""
		z: 1
	}

	// Main content column
	ColumnLayout {
		id: bodyCol
		z: 2
		anchors.left: notifPic.right
		anchors.leftMargin: 12
		anchors.right: closeBtn.left
		anchors.rightMargin: 8
		anchors.verticalCenter: parent.verticalCenter
		spacing: 3

		// Header: App name + time
		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			Text {
				Layout.fillWidth: true
				text: root.notif ? (root.notif.appName || "") : ""
				font.family: Theme.fontMono
				font.pointSize: Theme.fontSizeSmall - 2
				font.bold: true
				color: Theme.textDim
				elide: Text.ElideRight
				visible: text !== ""
			}

			Text {
				text: {
					if (!root.showTime || !root.notif || !root.notif.time)
						return "";
					return Qt.formatTime(new Date(root.notif.time), "hh:mm");
				}
				font.family: Theme.fontMono
				font.pointSize: Theme.fontSizeSmall - 3
				color: Theme.textMuted
				visible: text !== ""
			}
		}

		// Summary
		Text {
			Layout.fillWidth: true
			text: root.notif ? (root.notif.summary || "") : ""
			font.family: Theme.fontFamily
			font.pointSize: Theme.fontSizeSmall - 1
			font.bold: true
			color: Theme.textMain
			elide: Text.ElideRight
			visible: text !== ""
		}

		// Body text
		Text {
			Layout.fillWidth: true
			text: root.notif ? (root.notif.body || "") : ""
			font.family: Theme.fontFamily
			font.pointSize: Theme.fontSizeSmall - 2
			color: Theme.textDim
			wrapMode: Text.Wrap
			maximumLineCount: 3
			elide: Text.ElideRight
			visible: text !== ""
		}

		// Inline reply field
		NotificationReplyField {
			Layout.fillWidth: true
			Layout.topMargin: 4
			visible: root.canReply
			notif: root.liveNotif
			placeholder: root.notif?.inlineReplyPlaceholder || "Reply…"
			onFocusGained: root.replyFocusGained()
			onFocusLost: root.replyFocusLost()
			onReplied: root.dismissed()
		}

		// Action buttons
		RowLayout {
			Layout.fillWidth: true
			Layout.topMargin: 4
			spacing: 6
			visible: root.actionEntries.length > 0

			Repeater {
				model: root.actionEntries
				delegate: NotificationActionButton {
					Layout.fillWidth: true
					notifId: modelData.notifId ?? root.notif.id
					identifier: modelData.identifier
					label: modelData.text || modelData.label || ""
				}
			}
		}
	}

	// Close / Dismiss button
	CloseButton {
		id: closeBtn
		anchors.top: parent.top
		anchors.right: parent.right
		anchors.margins: 6
		size: 24
		z: 3
		onClicked: root.dismissed()
	}
}
