import Quickshell
import QtQuick
import "views"
import "views/launcher"

// Windows created later stack above earlier ones on the same layer.
ShellRoot {
	WallpaperView {}

	Variants {
		model: Quickshell.screens
		Bar {
		}
	}

	DrawerWindow {}

	Launcher {}

	NotificationToasts {}

	Osd {}

	// Stops with the main thread, and systemd then restarts the shell (WatchdogSec).
	Timer {
		interval: 5000
		running: true
		repeat: true
		onTriggered: Quickshell.execDetached(["systemd-notify", "WATCHDOG=1"])
	}
}
