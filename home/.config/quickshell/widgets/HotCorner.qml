import ".."
import QtQuick

// The pointer stops in a corner of the screen, so it takes no aim: reaching it is the toggle.
// A panel opening or closing takes the pointer off for a moment: only a real leave re-arms it.
MouseArea {
	id: root

	required property string panel
	property string mode: ""
	property bool armed: true

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
			Panels.toggle(panel, mode);
		}
	}

	Timer {
		id: away
		interval: 150
		onTriggered: root.armed = true
	}
}
