import ".."
import "."
import Quickshell.Services.Notifications
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
	required property bool hasInlineReply
	required property string replyPlaceholder
	required property var actions
	required property double time

	property bool isSelected: false
	property bool isToast: false

	readonly property bool critical: urgency === NotificationUrgency.Critical
	// A closed notification can no longer take a reply.
	readonly property bool canReply: hasInlineReply && Notifications.live(nid) !== null

	signal activated()
	signal dismissed()
	signal replyFocused(bool focused)

	implicitHeight: Math.max(bodyCol.implicitHeight, notifPic.size) + Theme.notifPadV * 2
	// A toast lights up under the pointer; in the center the pointer moves the
	// selection instead (HoverSelect there).
	color: isToast ? (hoverArea.containsMouse ? Theme.bgHover : Theme.panel(Theme.bgCard)) : Theme.inset(Theme.bgMain)
	border.color: critical ? Theme.critical
		: isToast ? Theme.border
		: isSelected ? Theme.selectionBorder
		: Theme.tileBorder
	border.width: isToast ? Theme.borderSize : 1
	radius: Theme.roundingElement
	clip: true

	Behavior on color { ColorAnimation { duration: 100 } }
	Behavior on border.color { ColorAnimation { duration: 100 } }

	Rectangle {
		anchors.fill: parent
		visible: root.isSelected && !root.isToast
		color: Theme.selectionBg
		radius: Theme.roundingElement
	}

	MouseArea {
		id: hoverArea
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: root.activated()
	}

	NotificationPicture {
		id: notifPic
		anchors.left: parent.left
		anchors.leftMargin: Theme.notifPadH
		anchors.verticalCenter: parent.verticalCenter
		size: 64
		image: root.image
		appIcon: root.appIcon
		appName: root.appName
	}

	ColumnLayout {
		id: bodyCol
		anchors.left: notifPic.right
		anchors.leftMargin: 12
		anchors.right: closeBtn.left
		anchors.rightMargin: 8
		anchors.verticalCenter: parent.verticalCenter
		spacing: 3

		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			Text {
				Layout.fillWidth: true
				text: root.appName
				font.family: Theme.fontMono
				font.pixelSize: Theme.fontSizeSmall + 2
				font.bold: true
				color: Theme.textDim
				elide: Text.ElideRight
				visible: text !== ""
			}

			Text {
				visible: !root.isToast
				text: Qt.formatTime(new Date(root.time), "hh:mm")
				font.family: Theme.fontMono
				font.pixelSize: Theme.fontSizeSmall + 1
				color: Theme.textMuted
			}
		}

		Text {
			Layout.fillWidth: true
			text: root.summary
			font.family: Theme.fontFamily
			font.pixelSize: Theme.fontSize
			font.bold: true
			color: Theme.textMain
			elide: Text.ElideRight
			visible: text !== ""
		}

		Text {
			Layout.fillWidth: true
			text: root.body
			font.family: Theme.fontFamily
			font.pixelSize: Theme.fontSizeSmall + 2
			color: Theme.textDim
			wrapMode: Text.Wrap
			maximumLineCount: 3
			elide: Text.ElideRight
			visible: text !== ""
		}

		Rectangle {
			Layout.fillWidth: true
			Layout.topMargin: 4
			visible: root.canReply
			implicitHeight: 30
			color: Theme.inset(Theme.bgMain)
			border.color: replyField.activeFocus ? Theme.selectionBorder : Theme.border
			border.width: 1
			radius: Theme.roundingElement

			TextInput {
				id: replyField
				anchors.fill: parent
				anchors.leftMargin: 8
				anchors.rightMargin: 8
				verticalAlignment: TextInput.AlignVCenter
				font.family: Theme.fontMono
				font.pixelSize: Theme.fontSizeSmall + 2
				color: Theme.textMain
				clip: true
				selectByMouse: true
				wrapMode: TextInput.Wrap
				activeFocusOnPress: true

				onAccepted: {
					var n = Notifications.live(root.nid);
					if (text.trim() !== "" && n && n.sendInlineReply(text)) {
						text = "";
						focus = false;
						root.dismissed();
					}
				}
				onActiveFocusChanged: root.replyFocused(activeFocus)
				Keys.onEscapePressed: focus = false
			}

			Text {
				visible: replyField.text === "" && !replyField.activeFocus
				anchors.fill: parent
				anchors.leftMargin: 8
				anchors.rightMargin: 8
				verticalAlignment: Text.AlignVCenter
				elide: Text.ElideRight
				text: root.replyPlaceholder || "Reply…"
				font.family: Theme.fontMono
				font.pixelSize: Theme.fontSizeSmall + 2
				color: Theme.textMuted
			}
		}

		RowLayout {
			Layout.fillWidth: true
			Layout.topMargin: 4
			spacing: 6
			visible: root.actions.count > 0

			Repeater {
				model: root.actions

				delegate: Rectangle {
					id: actionButton
					required property string identifier
					required property string text

					Layout.fillWidth: true
					implicitHeight: 28
					color: buttonArea.containsMouse ? Theme.border : Theme.bgHover
					border.color: buttonArea.containsMouse ? Theme.tileBorderHover : Theme.tileBorder
					border.width: 1
					radius: Theme.roundingElement

					Behavior on color { ColorAnimation { duration: 120 } }

					Text {
						anchors.fill: parent
						anchors.leftMargin: 10
						anchors.rightMargin: 10
						horizontalAlignment: Text.AlignHCenter
						verticalAlignment: Text.AlignVCenter
						elide: Text.ElideRight
						text: actionButton.text
						font.family: Theme.fontMono
						font.pixelSize: Theme.fontSizeSmall + 2
						color: Theme.textMain
					}

					MouseArea {
						id: buttonArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: Notifications.invoke(root.nid, actionButton.identifier)
					}
				}
			}
		}
	}

	CloseButton {
		id: closeBtn
		anchors.top: parent.top
		anchors.right: parent.right
		anchors.margins: 6
		size: 24
		onClicked: root.dismissed()
	}
}
