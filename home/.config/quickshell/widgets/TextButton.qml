import ".."
import QtQuick

// A button that says what it does: outlined, or filled with the accent for
// the one a form is there for (`primary`). An `icon` goes before the text.
Rectangle {
	id: root

	property string text: ""
	property string icon: ""
	property bool primary: false
	readonly property bool hovered: area.containsMouse

	signal clicked()

	implicitWidth: row.implicitWidth + 20
	implicitHeight: 30
	radius: Theme.roundingSubtle
	color: primary ? (hovered ? Qt.lighter(Theme.accentBlue, 1.15) : Theme.accentBlue)
		: (hovered ? Theme.bgHover : "transparent")
	border.color: hovered ? Theme.tileBorderHover : Theme.tileBorder
	border.width: primary ? 0 : 1

	Behavior on color { ColorAnimation { duration: Theme.animFast } }

	Row {
		id: row
		anchors.centerIn: parent
		spacing: 5

		LineIcon {
			anchors.verticalCenter: parent.verticalCenter
			name: root.icon
			size: 14
			color: label.color
		}

		StyledText {
			id: label
			anchors.verticalCenter: parent.verticalCenter
			text: root.text
			font.pixelSize: Theme.fontSizeSmall
			font.bold: root.primary
			color: root.primary ? Theme.bgMain : (root.hovered ? Theme.textMain : Theme.textDim)
		}
	}

	MouseArea {
		id: area
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: root.clicked()
	}
}
