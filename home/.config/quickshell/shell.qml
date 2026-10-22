import Quickshell
import QtQuick
import "views"
import "views/launcher"

// Windows created later stack above earlier ones on the same layer.
ShellRoot {
	WallpaperView {
	}

	Variants {
		model: Quickshell.screens
		Bar {
		}
	}

	DrawerWindow {
	}

	Launcher {
	}

	NotificationToasts {
	}

	Osd {
	}

	PolkitDialog {
	}

	LockScreen {
	}
}
