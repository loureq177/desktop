import "../.."
import "../../widgets"
import QtQuick
import QtQuick.Layouts

// One field of a FormCard; `secret` hides what is typed, with an eye to show it.
Rectangle {
	id: root

	property alias text: input.text
	property alias input: input
	property string placeholder: ""
	property bool secret: false
	property bool shown: false

	signal accepted()

	Layout.fillWidth: true
	Layout.preferredHeight: 36
	radius: Theme.roundingSubtle
	color: Theme.glass(Theme.bgCard)
	border.color: input.activeFocus ? Theme.accentBlue : Theme.border
	border.width: 1

	RowLayout {
		anchors.fill: parent
		anchors.leftMargin: 10
		anchors.rightMargin: 8
		spacing: 6

		TextInput {
			id: input
			Layout.fillWidth: true
			echoMode: root.secret && !root.shown ? TextInput.Password : TextInput.Normal
			font.family: Theme.fontMono
			font.pixelSize: Theme.fontSizeSmall
			color: Theme.textMain
			selectionColor: Theme.accentBlue
			clip: true
			onAccepted: root.accepted()

			StyledText {
				text: root.placeholder
				mono: true
				font.pixelSize: Theme.fontSizeSmall
				color: Theme.textMuted
				visible: !input.text && !input.activeFocus
				anchors.verticalCenter: parent.verticalCenter
			}
		}

		IconButton {
			visible: root.secret
			Layout.preferredWidth: 26
			Layout.preferredHeight: 26
			icon: root.shown ? "eye-off" : "eye"
			outlined: false
			onClicked: root.shown = !root.shown
		}
	}
}
