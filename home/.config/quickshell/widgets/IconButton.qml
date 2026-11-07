import ".."
import QtQuick

// A square line-icon button, outlined or bare; `danger` turns it red under the pointer.
Rectangle {
	id: button

	property string icon: ""
	property int iconSize: 16
	property bool outlined: true
	property bool danger: false
	readonly property bool hovered: area.containsMouse
	property color iconColor: Theme.textDim

	signal clicked()

	implicitWidth: 32
	implicitHeight: 32
	radius: Theme.roundingSubtle
	color: hovered ? Theme.hoverBg : "transparent"
	border.color: !outlined ? "transparent" : hovered ? Theme.tileBorderHover : Theme.tileBorder
	border.width: 1

	Behavior on color { ColorAnimation { duration: Theme.animFast } }

	Press {
		id: press
		target: button
	}

	Lit {
		anchors.centerIn: parent
		lit: button.hovered
		rest: button.iconColor
		towards: button.danger ? Theme.critical : Theme.textMain

		LineIcon {
			name: button.icon
			size: button.iconSize
			color: button.iconColor
		}
	}

	MouseArea {
		id: area
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onPressed: press.restart()
		onClicked: button.clicked()
	}
}
