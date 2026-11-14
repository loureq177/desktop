import "Pointer.js" as Pointer
import QtQuick

// Hovering selects, as the keyboard does: only real pointer moves count, not contents
// moving under a resting pointer, and none while a list scrolls.
HoverHandler {
	id: root

	signal selected()

	onPointChanged: {
		if (!hovered)
			return;
		// The event's own window position: one mapped from a gliding row looks moved.
		var p = point.scenePosition;
		// Called while scrolling too: the next real move is measured from here.
		var moved = Pointer.moved(p.x, p.y);
		if (moved && !Pointer.scrolling)
			Pointer.pick(() => root.selected());
	}
}
