import "../.."
import "../../widgets"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
	id: card

	property bool isSelected: false
	property bool isConnected: false
	signal clicked()

	default property alias content: row.data

	width: ListView.view.width - ((ListView.view.ScrollBar.vertical && ListView.view.ScrollBar.vertical.visible) ? 10 : 0)
	height: 50
	radius: Theme.roundingElement

	color: area.containsMouse
		? Theme.bgHover
		: (isConnected ? Theme.alpha(Theme.accent, 0.08) : Theme.bgMain)

	border.color: isConnected
		? Theme.alpha(Theme.accent, 0.40)
		: (area.containsMouse ? Theme.textDim : Theme.border)
	border.width: 1

	Behavior on color { ColorAnimation { duration: 100 } }
	Behavior on border.color { ColorAnimation { duration: 100 } }

	SelectionHighlight {
		selected: card.isSelected
		color: card.isConnected ? Theme.alpha(Theme.accent, 0.20) : Theme.selectionBg
	}

	MouseArea {
		id: area
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		z: 1
		onClicked: mouse => {
			mouse.accepted = true;
			card.clicked();
		}
	}

	RowLayout {
		id: row
		anchors.fill: parent
		anchors.leftMargin: 12
		anchors.rightMargin: 12
		spacing: 10
		z: 2
	}
}
