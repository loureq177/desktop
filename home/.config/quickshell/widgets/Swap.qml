import ".."
import QtQuick

// What is here at rest, and `alt` in the bar's figures in its place while `swapped`: the room
// is the wider one's, so nothing beside it moves.
Item {
	id: root

	property bool swapped: false
	property string alt: ""
	property color altColor: Theme.textMain
	default property alias rest: restItem.data

	width: Math.max(restItem.childrenRect.width, altText.implicitWidth)
	height: Math.max(restItem.childrenRect.height, altText.implicitHeight)

	Item {
		id: restItem
		anchors.centerIn: parent
		width: childrenRect.width
		height: childrenRect.height
		opacity: root.swapped ? 0 : 1

		Behavior on opacity {
			NumberAnimation { duration: Theme.animFast }
		}
	}

	StyledText {
		id: altText
		anchors.centerIn: parent
		text: root.alt
		mono: true
		font.bold: true
		font.pixelSize: Theme.fontSizeBar
		color: root.altColor
		opacity: root.swapped ? 1 : 0

		Behavior on opacity {
			NumberAnimation { duration: Theme.animFast }
		}
	}
}
