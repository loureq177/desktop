.pragma library

// The row a vim-style key moves to among `count` rows from `current`: J / K
// and the arrows by one, g to the top, G to the bottom; -1 for any other key.
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

// A move by `delta` that goes round at the ends: up from the first row to the
// last, down from the last to the first; elsewhere it stops at the end.
function wrap(current, delta, count) {
	if (count === 0)
		return 0;
	if (delta < 0 && current === 0)
		return count - 1;
	if (delta > 0 && current === count - 1)
		return 0;
	return Math.max(0, Math.min(count - 1, current + delta));
}
