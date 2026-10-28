import "Pointer.js" as Pointer
import QtQuick

// Hovering an item selects it, as the keyboard does, so there is one
// highlight for both. A real movement of the pointer counts, and a list the
// wheel or the touchpad scrolls under it; never contents the keyboard or an
// animation moves, so it does not take the keyboard's selection.
HoverHandler {
	id: root

	signal selected()

	onPointChanged: {
		if (!hovered)
			return;
		var p = parent.mapToItem(null, point.position.x, point.position.y);
		if (Pointer.moved(p.x, p.y) || Pointer.scrolling)
			Pointer.pick(() => root.selected());
	}
}
