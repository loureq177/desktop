// Inline reply field for a notification advertising the inline-reply action.
// `notif` is the Quickshell live Notification object (null hides the row); the
// typed text is delivered on Enter via Notification.sendInlineReply(). Closing
// without sending (focus loss / Escape) just hides the field. The surface the
// field lives on closes via onReplied, so a non-resident notification does not
// linger as a zombie toast after replying.
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
	// Latest sent reply text (empty before the first send); available for
	// debugging and tests.
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
		font.pointSize: Theme.fontSizeSmall
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

		// Escape leaves the field without closing the toast / the center.
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
		font.pointSize: Theme.fontSizeSmall
		color: Theme.textMuted
	}
}
