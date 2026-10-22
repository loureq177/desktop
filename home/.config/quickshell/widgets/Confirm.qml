import QtQuick

// What goes ahead only on a second press: the first one arms its key for a
// few seconds (reboot, forgetting a network, wiping the clipboard).
Timer {
	id: root

	property string armed: ""

	// Whether `key` was armed already, so the caller goes ahead; else arms it.
	function ask(key: string): bool {
		if (armed === key) {
			reset();
			return true;
		}
		armed = key;
		restart();
		return false;
	}

	function reset(): void {
		stop();
		armed = "";
	}

	interval: 3000
	onTriggered: armed = ""
}
