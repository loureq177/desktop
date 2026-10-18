import Quickshell
import QtQuick
import "views"

// Windows created later stack above earlier ones on the same layer.
ShellRoot {
	WallpaperView {
	}

	Variants {
		model: Quickshell.screens
		Bar {
		}
	}

	CenterBackdrop {
	}

	LauncherView {
	}

	NotificationToasts {
	}

	NotificationCenter {
	}

	ClipboardView {
	}

	QuickSettingsView {
	}

	WeatherView {
	}

	Osd {
	}

	PolkitDialog {
	}

	LockScreen {
	}
}
