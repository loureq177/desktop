import ".."
import "ListNav.js" as ListNav
import QtQuick
import QtQuick.Controls

// A list the keyboard and the pointer pick from, with one highlight for both:
// J / K and the arrows, g / G, Enter or a click for `activated`. Its rows are
// ListRow. With `wrap`, step() goes round at the ends on a fresh press
// (ListNav.wrap).
ListView {
	id: list

	property bool wrap: false
	// A thin bar while the rows overflow; rows leave room for it.
	property bool scrollBar: false
	// The highlight over the rows: for rows that paint a background of their own.
	property alias highlightOver: highlight.over
	// One highlight sliding from row to row; off for rows that light up on
	// their own (FadeHighlight), as the notification cards do.
	property bool slidingHighlight: true
	readonly property int rowWidth: width - (scrollBar && ScrollBar.vertical.visible ? 10 : 0)

	signal activated(int index)

	function step(delta: int, repeat: bool): void {
		if (count === 0)
			return;
		var next = currentIndex + delta;
		currentIndex = wrap ? ListNav.wrap(currentIndex, delta, count, repeat) : Math.max(0, Math.min(count - 1, next));
	}

	function activate(): void {
		if (count > 0)
			activated(currentIndex);
	}

	clip: true
	highlightFollowsCurrentItem: false
	keyNavigationEnabled: false
	onCurrentIndexChanged: scrolling.reveal(currentIndex)
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

	ListHighlight {
		id: highlight
		view: list
		item: list.slidingHighlight ? list.currentItem : null
	}

	WheelScroll {
		id: scrolling
		flickable: list
	}
}
