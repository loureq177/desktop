.pragma library

// Where the pointer was last seen on screen, shared by every HoverSelect.
var last = null;

// Whether the pointer itself moved to (x, y). Rows sliding or a panel
// animating under a resting pointer also send hover events, at the same place.
function moved(x, y) {
	var m = last !== null && (Math.abs(x - last.x) > 0.5 || Math.abs(y - last.y) > 0.5);
	last = { x: x, y: y };
	return m;
}
