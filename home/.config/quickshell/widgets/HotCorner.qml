import ".."
import QtQuick

// The pointer stops in a corner of the screen, so it takes no aim: reaching it is the toggle.
// A panel opening or closing takes the pointer off for a moment: only a real leave re-arms it.
MouseArea {
	id: root

	required property string panel
	property string mode: ""
	property bool armed: true
	// Panels.qml's shortcut, which Hyprland presses only with the cursor really in the corner:
	// a panel opening hands this area a hover at 0,0 while the pointer is elsewhere.
	readonly property string shortcut: mode !== "" ? panel + "-" + mode : panel
	readonly property bool atRight: x > 0

	width: 1
	height: 1
	hoverEnabled: true
	onContainsMouseChanged: {
		if (!containsMouse) {
			away.restart();
			return;
		}
		away.stop();
		if (armed) {
			armed = false;
			Hypr.dispatch("function() local c, m = hl.get_cursor_pos(), hl.get_monitor_at_cursor() "
				+ "if c and m and c.y - m.y < 2 and " + (atRight ? "m.x + m.width / m.scale - c.x < 3" : "c.x - m.x < 2")
				+ " then hl.dispatch(hl.dsp.global(" + Hypr.quote("shell:" + shortcut) + ")) end end");
		}
	}

	Timer {
		id: away
		interval: 150
		onTriggered: root.armed = true
	}
}
