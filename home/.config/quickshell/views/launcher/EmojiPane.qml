import "../.."
import "../../widgets"
import "../../widgets/ListNav.js" as ListNav
import Quickshell
import Quickshell.Io
import QtQuick

// The emoji, a grid of them; Enter types the one picked into the focused
// window. The footer names it.
Item {
	id: pane

	property string query: ""
	property var emojis: []

	readonly property string icon: "smile"
	readonly property string placeholder: "Search " + emojis.length + " emoji..."
	readonly property var items: {
		var needle = query.trim().toLowerCase();
		return emojis.filter(it => it?.e && String(it.k || "").toLowerCase().includes(needle));
	}
	readonly property int count: items.length
	readonly property int cell: 76
	readonly property int columns: Math.max(1, Math.floor(width / cell))
	readonly property int preferredHeight: count === 0 ? 72 : Math.ceil(count / columns) * cell
	readonly property var current: items[grid.currentIndex] ?? null
	readonly property string footer: current ? current.e + "  " + String(current.k || "").split(" ").slice(0, 3).join(" ")
		: emojis.length === 0 ? "Loading emojis..." : "No matching emojis"

	function step(delta: int): void {
		grid.currentIndex = ListNav.wrap(grid.currentIndex, delta * columns, count);
	}

	function stepColumn(delta: int): void {
		grid.currentIndex = ListNav.wrap(grid.currentIndex, delta, count);
	}

	function activate(): void {
		grid.activated(grid.currentIndex);
	}

	onQueryChanged: grid.currentIndex = 0

	FileView {
		path: Quickshell.shellDir + "/emojis.json"
		onLoaded: {
			try {
				pane.emojis = JSON.parse(text());
			} catch (e) {
				pane.emojis = [];
			}
		}
	}

	GridView {
		id: grid

		signal activated(int index)

		anchors.top: parent.top
		anchors.bottom: parent.bottom
		anchors.horizontalCenter: parent.horizontalCenter
		width: pane.columns * pane.cell
		clip: true
		cellWidth: pane.cell
		cellHeight: pane.cell
		model: pane.items
		highlightFollowsCurrentItem: false
		onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
		onActivated: index => {
			var emoji = pane.items[index]?.e;
			if (!emoji)
				return;
			Panels.close("launcher");
			Quickshell.execDetached([Commands.bin + "emoji-insert", emoji]);
		}

		WheelScroll {
			flickable: grid
		}

		delegate: ListRow {
			required property var modelData
			width: pane.cell
			height: pane.cell
			inset: 3

			Text {
				anchors.centerIn: parent
				text: parent.modelData.e
				font.pixelSize: 46
			}
		}
	}

	StyledText {
		visible: pane.count === 0
		anchors.centerIn: parent
		font.pixelSize: Theme.fontSizeSmall
		color: Theme.textDim
		text: pane.emojis.length === 0 ? "Loading emojis..." : "No matching emojis"
	}
}
