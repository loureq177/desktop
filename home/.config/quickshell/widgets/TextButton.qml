import ".."
import QtQuick

// A labelled button, outlined or filled (`primary`), with an optional `icon`;
// `danger` paints it red.
Rectangle {
	id: root

	property string text: ""
	property string icon: ""
	property bool primary: false
	property bool danger: false
	readonly property bool hovered: area.containsMouse

	signal clicked()

	// Of the label's own width, not the row's: the label narrows in a button
	// made narrower than it (a layout's fillWidth) and elides.
	implicitWidth: (icon !== "" ? 14 + row.spacing : 0) + label.implicitWidth + 20
	implicitHeight: 30
	radius: Theme.roundingSubtle
	color: primary ? (hovered ? Qt.lighter(Theme.accentBlue, 1.15) : Theme.accentBlue)
		: danger ? Theme.alpha(Theme.critical, hovered ? 0.22 : 0.14)
		: (hovered ? Theme.bgHover : "transparent")
	border.color: danger ? Theme.alpha(Theme.critical, 0.5) : (hovered ? Theme.tileBorderHover : Theme.tileBorder)
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
			width: Math.min(implicitWidth, root.width - root.implicitWidth + implicitWidth)
			elide: Text.ElideRight
			text: root.text
			font.pixelSize: Theme.fontSizeSmall
			font.bold: root.primary
			color: root.primary ? Theme.bgMain : root.danger ? Theme.critical : (root.hovered ? Theme.textMain : Theme.textDim)
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
