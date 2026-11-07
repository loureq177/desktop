pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton {
	property var windows: []
	// The screen the OSD is up on: it takes the middle of that bar.
	property string osdScreen: ""
	// The screen whose bar is back over a fullscreen window (hyprland/binds.lua), until left.
	property string peekScreen: ""

	GlobalShortcut {
		appid: "shell"
		name: "bar-peek"
		onPressed: peekScreen = Hyprland.focusedMonitor?.name ?? ""
	}

	function add(win: QtObject): void {
		windows = windows.concat([win]);
	}

	function remove(win: QtObject): void {
		windows = windows.filter(w => w !== win);
	}
}
