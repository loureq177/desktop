import ".."
import QtQuick

// A row of a SelectList (or the cell of a GridView): lit while it is the
// current one, which the pointer moves as well; a click activates it.
// `topInset` leaves room above the row for a heading of its own.
Rectangle {
	id: row

	required property int index
	readonly property var view: ListView.view ?? GridView.view
	readonly property bool selected: ListView.isCurrentItem || GridView.isCurrentItem
	property int topInset: 0
	// Room around the highlight on every side (the cells of a grid).
	property int inset: 0

	width: view?.rowWidth ?? view?.width ?? 0
	radius: Theme.roundingElement
	color: "transparent"

	Item {
		id: area
		anchors.fill: parent
		anchors.margins: row.inset
		anchors.topMargin: row.topInset + row.inset

		SelectionHighlight {
			radius: row.radius
			selected: row.selected
		}

		HoverSelect {
			enabled: !row.view.moving
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
