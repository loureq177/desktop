import "Pointer.js" as Pointer
import QtQuick

// Hovering an item selects it, as the keyboard does, so there is one
// highlight for both. Only a real movement of the pointer counts, never
// contents moving under it, so it does not take the keyboard's selection.
HoverHandler {
	id: root

	signal selected()

	onPointChanged: {
		if (!hovered)
			return;
		var p = parent.mapToItem(null, point.position.x, point.position.y);
		if (Pointer.moved(p.x, p.y))
			root.selected();
	}
}
