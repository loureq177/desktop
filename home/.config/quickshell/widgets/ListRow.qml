import ".."
import QtQuick

// A row of a SelectList (or a GridView cell), lit over `highlightArea`; `topInset`
// leaves room for a heading.
Rectangle {
	id: row

	required property int index
	readonly property var view: ListView.view ?? GridView.view
	readonly property bool selected: ListView.isCurrentItem || GridView.isCurrentItem
	property int topInset: 0
	// Room around the highlight on every side (the cells of a grid).
	property int inset: 0
	readonly property Item highlightArea: area

	width: view?.rowWidth ?? view?.width ?? 0
	radius: Theme.roundingElement
	color: "transparent"

	Item {
		id: area
		anchors.fill: parent
		anchors.margins: row.inset
		anchors.topMargin: row.topInset + row.inset

		HoverSelect {
			enabled: !row.view.dragging
			onSelected: row.view.currentIndex = row.index
		}

		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor
			onClicked: {
				row.view.currentIndex = row.index;
				row.view.activated(row.index);
			}
		}
	}
}
