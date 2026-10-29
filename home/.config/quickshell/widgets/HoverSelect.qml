import "Pointer.js" as Pointer
import QtQuick

// Hovering selects, as the keyboard does: only real pointer moves or a wheel scroll
// count, not contents moving under a resting pointer.
HoverHandler {
	id: root

	signal selected()

	onPointChanged: {
		if (!hovered)
			return;
		// The event's own window position: one mapped from a gliding row looks moved.
		var p = point.scenePosition;
		if (Pointer.moved(p.x, p.y) || Pointer.scrolling)
			Pointer.pick(() => root.selected());
	}
}
