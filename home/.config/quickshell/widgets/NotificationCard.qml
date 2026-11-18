import ".."
import "."
import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// A delegate for Notifications.history and .toasts: the properties are the
// rows' roles (see Notifications.row()).
Rectangle {
	id: root

	required property int nid
	required property string appName
	required property string summary
	required property string body
	required property int urgency
	required property string image
	required property string appIcon
	required property string desktopEntry
	required property var actions
	required property double time

	property bool isSelected: false
	property bool isToast: false

	readonly property bool critical: urgency === NotificationUrgency.Critical

	readonly property bool hovered: hover.hovered
	// A wide picture (a screenshot) whole under the text, not a square crop beside it.
	readonly property bool widePicture: notifPic.hasPicture && notifPic.aspect >= 1.2

	signal activated()
	signal dismissed()

	implicitHeight: Math.max(bodyCol.implicitHeight, notifPic.implicitHeight) + Theme.notifPadV * 2
	// A toast lights up under the pointer; in the center the pointer moves the
	// selection instead (HoverSelect there).
	color: isToast ? (hoverArea.containsMouse ? Theme.glass(Theme.bgHover) : Theme.glass(Theme.bgCard)) : Theme.glass(Theme.bgMain)
	// A hairline: a heavy edge round a toast looked pasted on.
	border.color: critical ? Theme.critical : isToast ? Theme.tileBorderHover : Theme.tileBorder
	border.width: 1
	// A toast is a card of its own on the screen, as the panels are.
	radius: isToast ? Theme.roundingWindow : Theme.roundingElement
	clip: true

	Behavior on color { ColorAnimation { duration: Theme.animFast } }
	Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

	FadeHighlight {
		selected: root.isSelected && !root.isToast
	}

	// Unlike hoverArea, it also holds over the buttons on the card.
	HoverHandler {
		id: hover
	}

	MouseArea {
		id: hoverArea
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: root.activated()
	}

	// The picture by the first line of text; text shorter than the picture is
	// centred on it.
	NotificationPicture {
		id: notifPic
		anchors.left: parent.left
		anchors.leftMargin: Theme.notifPadH
		anchors.top: parent.top
		anchors.topMargin: Theme.notifPadV
		image: root.image
		appIcon: root.appIcon
		size: root.widePicture ? 0 : 64
	}

	ColumnLayout {
		id: bodyCol
		anchors.left: notifPic.hasPicture && !root.widePicture ? notifPic.right : parent.left
		anchors.leftMargin: notifPic.hasPicture && !root.widePicture ? 12 : Theme.notifPadH
		anchors.right: closeBtn.left
		anchors.rightMargin: 8
		anchors.top: parent.top
		anchors.topMargin: Theme.notifPadV + Math.max(0, (notifPic.implicitHeight - implicitHeight) / 2)
		spacing: 3

		// A toast says whose it is; in the center the group's heading does, and the time is here.
		RowLayout {
			Layout.fillWidth: true
			spacing: 6
			visible: root.isToast && root.appName !== ""

			IconImage {
				readonly property string path: Notifications.appIconFor(root.desktopEntry, root.appName, root.appIcon)
				visible: path !== ""
				implicitSize: 16
				source: path
				asynchronous: true
			}

			StyledText {
				Layout.fillWidth: true
				text: root.appName
				mono: true
				font.bold: true
				color: Theme.textDim
				elide: Text.ElideRight
			}
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 8
			visible: root.summary !== "" || !root.isToast

			StyledText {
				Layout.fillWidth: true
				text: root.summary
				font.bold: true
				elide: Text.ElideRight
			}

			StyledText {
				visible: !root.isToast
				text: Qt.formatTime(new Date(root.time), "hh:mm")
				mono: true
				font.pixelSize: Theme.fontSizeSmall
				color: Theme.textDim
			}
		}

		StyledText {
			Layout.fillWidth: true
			// Browsers put the site and an empty line before the message.
			text: root.body.replace(/\n\s*\n/g, "\n")
			color: Theme.textDim
			wrapMode: Text.Wrap
			maximumLineCount: 3
			elide: Text.ElideRight
			visible: text !== ""
		}

		ClippingRectangle {
			visible: root.widePicture
			// Past the close button's column, to the card's padding: even on both sides.
			Layout.preferredWidth: root.width - Theme.notifPadH * 2
			Layout.topMargin: 6
			Layout.preferredHeight: Math.min(220, width / notifPic.aspect)
			radius: Theme.roundingElement
			color: Theme.bgMain

			Image {
				anchors.fill: parent
				source: root.widePicture ? notifPic.source : ""
				sourceSize.width: 800
				fillMode: Image.PreserveAspectCrop
				asynchronous: true
				cache: false
				mipmap: true
			}
		}

		RowLayout {
			Layout.fillWidth: true
			Layout.topMargin: 4
			spacing: 6
			visible: root.actions.count > 0

			Repeater {
				model: root.actions

				delegate: TextButton {
					required property string identifier
					required text

					Layout.fillWidth: true
					onClicked: Notifications.invoke(root.nid, identifier)
				}
			}
		}
	}

	CloseButton {
		id: closeBtn
		anchors.top: parent.top
		anchors.right: parent.right
		anchors.margins: 6
		implicitWidth: 24
		implicitHeight: 24
		onClicked: root.dismissed()
	}
}
