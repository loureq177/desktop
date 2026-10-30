.pragma library

// Where the pointer was last seen on screen, shared by every HoverSelect.
var last = null;
// The wheel or the touchpad is moving a list under the pointer (WheelScroll):
// what passes under it is what the pointer picks, though it rests.
var scrolling = false;
// Within pick(): the selection is the pointer's, made on what it can see.
var picking = false;
// Until then (ms since the epoch) a move picks nothing: a panel opens under it.
var heldUntil = 0;

// Whether the pointer itself moved to (x, y). Rows sliding or a panel
// animating under a resting pointer also send hover events, at the same place.
function moved(x, y) {
	var m = last !== null && (Math.abs(x - last.x) > 0.5 || Math.abs(y - last.y) > 0.5);
	last = { x: x, y: y };
	return m && Date.now() >= heldUntil;
}

// A panel opening: the pointer picks only once it moves after `ms`.
function hold(ms) {
	last = null;
	heldUntil = Date.now() + ms;
}

function setScrolling(on) {
	scrolling = on;
}

// Selects as the pointer: a list leaves the item where it is (WheelScroll.reveal).
function pick(select) {
	picking = true;
	try {
		select();
	} finally {
		picking = false;
	}
}
