import ".."
import Quickshell
import QtQuick

Rectangle {
	id: root

	property var notif: null
	property string placeholder: ""
	signal replied()
	signal focusGained()
	signal focusLost()
	property string submittedText: ""

	implicitHeight: visible ? 30 : 0
	color: Theme.bgMain
	border.color: replyField.activeFocus ? Theme.selectionBorder : Theme.border
	border.width: 1
	radius: Theme.roundingElement

	TextInput {
		id: replyField
		anchors.fill: parent
		anchors.leftMargin: 8
		anchors.rightMargin: 8
		anchors.verticalCenter: parent.verticalCenter
		verticalAlignment: TextInput.AlignVCenter
		font.family: Theme.fontMono
		font.pointSize: Theme.fontSizeSmall - 2
		color: Theme.textMain
		clip: true
		selectByMouse: true
		wrapMode: TextInput.Wrap
		activeFocusOnPress: true
		enabled: root.notif !== null

		onAccepted: {
			if (text.trim() === "")
				return;
			if (root.notif.sendInlineReply(text)) {
				root.submittedText = text;
				text = "";
				root.replied();
			}
		}

		onActiveFocusChanged: {
			if (activeFocus)
				root.focusGained();
			else
				root.focusLost();
		}

		Keys.onEscapePressed: focus = false
	}

	Text {
		visible: replyField.text === "" && !replyField.activeFocus && root.placeholder !== ""
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.verticalCenter: parent.verticalCenter
		anchors.leftMargin: 8
		anchors.rightMargin: 8
		elide: Text.ElideRight
		text: root.placeholder
		font.family: Theme.fontMono
		font.pointSize: Theme.fontSizeSmall - 2
		color: Theme.textMuted
	}
}
