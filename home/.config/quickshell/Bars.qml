pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton {
	// The screen the OSD is up on: it takes the middle of that bar.
	property string osdScreen: ""
	// The screen whose bar is back over a fullscreen window (hyprland/binds.lua), until left.
	property string peekScreen: ""

	GlobalShortcut {
		appid: "shell"
		name: "bar-peek"
		onPressed: peekScreen = Hyprland.focusedMonitor?.name ?? ""
	}
}
