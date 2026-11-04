import "../.."
import "../../widgets"
import QtQuick

// The screens as they stand on the desk, in logical pixels: arrows move the chosen one to the
// next edge or alignment of the others, Tab chooses, a drag snaps to edges. Only a draft
// until Settings.arrange takes it.
Item {
	id: root

	// { name, output, label, x, y, w, h }, the parked panel left out.
	property var draft: []
	property int selected: 0
	property bool dirty: false

	readonly property var box: {
		if (draft.length === 0)
			return { x: 0, y: 0, w: 1, h: 1 };
		var x0 = Math.min(...draft.map(d => d.x)), y0 = Math.min(...draft.map(d => d.y));
		var x1 = Math.max(...draft.map(d => d.x + d.w)), y1 = Math.max(...draft.map(d => d.y + d.h));
		return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
	}
	readonly property real zoom: Math.min((width - 48) / box.w, (height - 72) / box.h)
	readonly property real originX: (width - box.w * zoom) / 2 - box.x * zoom
	readonly property real originY: (height - 24 - box.h * zoom) / 2 - box.y * zoom
	// A screen touching none of the others: the pointer could not reach it.
	readonly property bool apart: draft.some((d, i) => draft.length > 1 && !draft.some((o, j) => j !== i && touching(d, o)))

	function load(): void {
		var list = Settings.monitors.filter(m => m.x > -10000).map(m => {
			var turned = m.transform % 2 === 1;
			return {
				name: m.name,
				output: Settings.displayOutput(m),
				label: m.description || m.name,
				x: m.x,
				y: m.y,
				w: Math.round((turned ? m.height : m.width) / m.scale),
				h: Math.round((turned ? m.width : m.height) / m.scale),
				focused: m.focused
			};
		});
		draft = list;
		selected = Math.max(0, list.findIndex(d => d.focused));
		dirty = false;
	}

	function overlaps(a: var, b: var): bool {
		return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
	}

	function touching(a: var, b: var): bool {
		var side = (a.x + a.w === b.x || b.x + b.w === a.x) && a.y < b.y + b.h && b.y < a.y + a.h;
		var stacked = (a.y + a.h === b.y || b.y + b.h === a.y) && a.x < b.x + b.w && b.x < a.x + a.w;
		return side || stacked;
	}

	function place(i: int, x: int, y: int): bool {
		var moved = Object.assign({}, draft[i], { x: x, y: y });
		if (draft.some((o, j) => j !== i && overlaps(moved, o)))
			return false;
		var next = draft.slice();
		next[i] = moved;
		draft = next;
		dirty = true;
		return true;
	}

	// The next place along one axis: beside another screen, or level with its edges.
	function move(dx: int, dy: int): void {
		var s = draft[selected];
		if (!s || draft.length < 2)
			return;
		var horizontal = dx !== 0;
		var dir = horizontal ? dx : dy;
		var at = horizontal ? s.x : s.y;
		var size = horizontal ? s.w : s.h;
		var stops = [];
		for (const o of draft) {
			if (o === s)
				continue;
			var start = horizontal ? o.x : o.y, length = horizontal ? o.w : o.h;
			stops.push(start - size, start, start + length - size, start + length);
		}
		stops = stops.filter(v => dir > 0 ? v > at : v < at).sort((a, b) => dir > 0 ? a - b : b - a);
		for (const v of stops) {
			if (place(selected, horizontal ? v : s.x, horizontal ? s.y : v))
				return;
		}
	}

	function choose(delta: int): void {
		if (draft.length > 0)
			selected = (selected + delta + draft.length) % draft.length;
	}

	// Within this many screen pixels a dragged edge meets another's.
	readonly property int snap: 14

	function snapped(i: int, x: real, y: real): var {
		var s = draft[i], reach = snap / zoom, bestX = null, bestY = null;
		for (const o of draft) {
			if (o === s)
				continue;
			for (const v of [o.x - s.w, o.x, o.x + o.w - s.w, o.x + o.w])
				if (Math.abs(v - x) < reach && (bestX === null || Math.abs(v - x) < Math.abs(bestX - x)))
					bestX = v;
			for (const v of [o.y - s.h, o.y, o.y + o.h - s.h, o.y + o.h])
				if (Math.abs(v - y) < reach && (bestY === null || Math.abs(v - y) < Math.abs(bestY - y)))
					bestY = v;
		}
		return { x: Math.round(bestX ?? x), y: Math.round(bestY ?? y) };
	}

	Repeater {
		model: root.draft

		delegate: Rectangle {
			id: screen
			required property var modelData
			required property int index
			readonly property bool chosen: index === root.selected
			property bool dragging: false

			function follow(): void {
				x = Qt.binding(() => root.originX + screen.modelData.x * root.zoom);
				y = Qt.binding(() => root.originY + screen.modelData.y * root.zoom);
			}

			Component.onCompleted: follow()
			width: modelData.w * root.zoom
			height: modelData.h * root.zoom
			radius: Theme.roundingElement
			color: chosen ? Theme.alpha(Theme.accentBlue, 0.14) : Theme.bgHover
			border.width: chosen ? 2 : 1
			border.color: chosen ? Theme.accentBlue : Theme.border
			z: dragging ? 2 : chosen ? 1 : 0

			Column {
				anchors.left: parent.left
				anchors.top: parent.top
				anchors.margins: 10
				width: parent.width - 20
				spacing: 2

				StyledText {
					width: parent.width
					text: screen.modelData.name
					font.bold: true
					color: screen.chosen ? Theme.accentBlue : Theme.textMain
					elide: Text.ElideRight
				}

				StyledText {
					width: parent.width
					visible: screen.modelData.label !== screen.modelData.name
					text: screen.modelData.label
					font.pixelSize: Theme.fontSizeTiny
					color: Theme.textDim
					elide: Text.ElideRight
				}
			}

			StyledText {
				anchors.left: parent.left
				anchors.bottom: parent.bottom
				anchors.margins: 10
				text: screen.modelData.w + "×" + screen.modelData.h + " at " + screen.modelData.x + ", " + screen.modelData.y
				mono: true
				font.pixelSize: Theme.fontSizeTiny
				color: Theme.textDim
			}

			MouseArea {
				anchors.fill: parent
				cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
				drag.target: screen
				drag.threshold: 4
				onPressed: root.selected = screen.index
				drag.onActiveChanged: {
					if (drag.active) {
						screen.dragging = true;
						return;
					}
					var p = root.snapped(screen.index, (screen.x - root.originX) / root.zoom, (screen.y - root.originY) / root.zoom);
					screen.dragging = false;
					root.place(screen.index, p.x, p.y);
					screen.follow();
				}
			}
		}
	}

	StyledText {
		anchors.horizontalCenter: parent.horizontalCenter
		anchors.bottom: parent.bottom
		text: root.draft.length < 2 ? "One screen: nothing to arrange"
			: root.apart ? "A screen touches none of the others: the pointer cannot reach it"
			: "←↑↓→ move  ·  Tab next screen  ·  drag with the mouse  ·  Enter applies  ·  Esc leaves it as it was"
		font.pixelSize: Theme.fontSizeTiny
		color: root.apart ? Theme.warning : Theme.textDim
	}
}
