pragma Singleton
import Quickshell
import QtQuick

Singleton {
	property var windows: []

	function add(win: QtObject): void {
		windows = windows.concat([win]);
	}

	function remove(win: QtObject): void {
		windows = windows.filter(w => w !== win);
	}
}
