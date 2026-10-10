.pragma library

function step(event, count, current) {
	var key = event.key;
	if (key === Qt.Key_J || key === Qt.Key_Down)
		return count > 0 ? Math.min(count - 1, current + 1) : current;
	if (key === Qt.Key_K || key === Qt.Key_Up)
		return count > 0 ? Math.max(0, current - 1) : current;
	if (key === Qt.Key_G)
		return (event.modifiers & Qt.ShiftModifier) ? Math.max(0, count - 1) : 0;
	return -1;
}
