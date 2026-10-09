// Shared close/dismiss button: icon-only button used across headers,
// cards, and notification toasts. Uses the theme's Nerd Font close icon (󰅖)
// with precise optical centering and consistent hover feedback.
import ".."
import QtQuick

Rectangle {
	id: root

	signal clicked()

	property int size: 28
	property bool bordered: true
	property int iconSize: size >= 26 ? 14 : 11
	property color idleColor: "transparent"
	property color hoverColor: Theme.bgHover
	property color idleBorderColor: Theme.border
	property color hoverBorderColor: Theme.textDim
	property color idleTextColor: size >= 26 ? Theme.textDim : Theme.textMuted
	property color hoverTextColor: Theme.critical

	implicitWidth: size
	implicitHeight: size
	radius: size >= 24 ? Theme.roundingElement : Theme.roundingSubtle
	color: mouseArea.containsMouse ? hoverColor : idleColor
	border.color: bordered ? (mouseArea.containsMouse ? hoverBorderColor : idleBorderColor) : "transparent"
	border.width: bordered ? 1 : 0

	Behavior on color { ColorAnimation { duration: 120 } }
	Behavior on border.color { ColorAnimation { duration: 120 } }

	Text {
		anchors.centerIn: parent
		anchors.horizontalCenterOffset: 1
		anchors.verticalCenterOffset: 1
		text: "󰅖"
		font.family: Theme.fontFamily
		font.pixelSize: root.iconSize
		color: mouseArea.containsMouse ? root.hoverTextColor : root.idleTextColor

		Behavior on color { ColorAnimation { duration: 120 } }
	}

	MouseArea {
		id: mouseArea
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: mouse => {
			mouse.accepted = true;
			root.clicked();
		}
	}
}
