import ".."
import "ListNav.js" as ListNav
import QtQuick
import QtQuick.Controls

// A list the keyboard and the pointer pick from, with one highlight for both:
// J / K and the arrows, g / G, Enter or a click for `activated`. Its rows are
// ListRow. With `wrap`, step() goes round at the ends (ListNav.wrap).
ListView {
	id: list

	property bool wrap: false
	// A thin bar while the rows overflow; rows leave room for it.
	property bool scrollBar: false
	readonly property int rowWidth: width - (scrollBar && ScrollBar.vertical.visible ? 10 : 0)

	signal activated(int index)

	function step(delta: int): void {
		if (count === 0)
			return;
		var next = currentIndex + delta;
		currentIndex = wrap ? ListNav.wrap(currentIndex, delta, count) : Math.max(0, Math.min(count - 1, next));
	}

	function activate(): void {
		if (count > 0)
			activated(currentIndex);
	}

	clip: true
	highlightFollowsCurrentItem: false
	keyNavigationEnabled: false
	onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
	onCountChanged: {
		if (currentIndex >= count)
			currentIndex = Math.max(0, count - 1);
	}

	Keys.onPressed: event => {
		var next = ListNav.step(event, count, currentIndex);
		if (next >= 0) {
			currentIndex = next;
		} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
			if (!event.isAutoRepeat)
				list.activate();
		} else {
			return;
		}
		event.accepted = true;
	}

	ScrollBar.vertical: ThinScrollBar {
		visible: list.scrollBar && size < 1.0
	}

	WheelScroll {
		flickable: list
	}
}
