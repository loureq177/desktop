pragma Singleton
import Quickshell
import QtQuick

Singleton {
	property var windows: []
	// The screen the OSD is up on: it takes the middle of that bar.
	property string osdScreen: ""

	function add(win: QtObject): void {
		windows = windows.concat([win]);
	}

	function remove(win: QtObject): void {
		windows = windows.filter(w => w !== win);
	}
}
