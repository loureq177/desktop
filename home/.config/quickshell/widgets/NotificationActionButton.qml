// Shared notification action button: full-width action row button used by
// both toasts and the control center. Actions travel as plain data (id +
// identifier) and the click resolves the live action through the singleton:
// nested Repeater delegates receive the outer Repeater's `modelData`, so
// everything the click needs must arrive via this component's properties.
import ".."
import Quickshell
import QtQuick

Rectangle {
	id: root

	required property int notifId
	required property string identifier
	required property string label

	implicitHeight: 28
	color: buttonArea.containsMouse ? Theme.border : Theme.bgHover
	border.color: Theme.border
	border.width: 1
	radius: Theme.roundingElement

	Behavior on color {
		ColorAnimation { duration: 120 }
	}

	Text {
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.verticalCenter: parent.verticalCenter
		anchors.leftMargin: 10
		anchors.rightMargin: 10
		horizontalAlignment: Text.AlignHCenter
		elide: Text.ElideRight
		text: root.label
		font.family: Theme.fontMono
		font.pointSize: Theme.fontSizeSmall
		color: Theme.textMain
	}

	MouseArea {
		id: buttonArea
		anchors.fill: parent
		hoverEnabled: true
		onClicked: Notifications.invokeByIdentifier(root.notifId, root.identifier)
	}
}
