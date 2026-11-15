import QtQuick

// What goes ahead only on a second press: the first one arms its key for a
// few seconds (reboot, forgetting a network, wiping the clipboard).
Timer {
	id: root

	property string armed: ""
	// Armed by a click, not a key: what to say is "Click again".
	property bool byPointer: false

	// Whether `key` was armed already, so the caller goes ahead; else arms it.
	function ask(key: string, pointer: bool): bool {
		if (armed === key) {
			reset();
			return true;
		}
		armed = key;
		byPointer = pointer === true;
		restart();
		return false;
	}

	function reset(): void {
		stop();
		armed = "";
	}

	interval: 4000
	onTriggered: armed = ""
}
