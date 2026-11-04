import ".."
import QtQuick

// The pointer stops in a corner of the screen, so it takes no aim: reaching it is the toggle.
// The bar holds the corners, an open drawer its own: the pointer resting there keeps it the keyboard.
MouseArea {
	id: root

	required property string panel
	property string mode: ""
	// Whether this window holds the corner now; shrinking is no leave.
	property bool present: true
	// Panels.qml's shortcut, which Hyprland presses only with the cursor really in the corner:
	// a panel opening hands this area a hover at 0,0 while the pointer is elsewhere.
	readonly property string shortcut: mode !== "" ? panel + "-" + mode : panel
	readonly property bool atRight: x > 0
	readonly property string corner: atRight ? "right" : "left"

	width: present ? 1 : 0
	height: present ? 1 : 0
	hoverEnabled: true
	acceptedButtons: Qt.NoButton
	onContainsMouseChanged: {
		if (!containsMouse) {
			if (present)
				Panels.leaveCorner(corner);
			return;
		}
		if (Panels.enterCorner(corner))
			Hypr.dispatch("function() local c, m = hl.get_cursor_pos(), hl.get_monitor_at_cursor() "
				+ "if c and m and c.y - m.y < 2 and " + (atRight ? "m.x + m.width / m.scale - c.x < 3" : "c.x - m.x < 2")
				+ " then hl.dispatch(hl.dsp.global(" + Hypr.quote("shell:" + shortcut) + ")) end end");
	}
}
