pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The panel on screen, at most one: opening one closes the one before. Each
// view shows itself while `active` names it (OverlayWindow.panel).
Singleton {
	id: root

	// "launcher", "clipboard", "keybindings", "weather", "quicksettings",
	// "notifications", or "" with nothing open.
	property string active: ""
	// What it was opened on: the launcher's mode, the quick settings page.
	property string mode: ""
	// The last close skips the exit animation (see closeInstant).
	property bool instant: false

	// Also emitted for the panel already open, when it is opened on a new mode.
	signal opened(string name, string mode)

	function open(name, newMode): void {
		root.instant = false;
		root.mode = newMode || "";
		root.active = name;
		root.opened(name, root.mode);
	}

	// Without a name, whatever is open.
	function close(name): void {
		if (!name || name === root.active)
			root.active = "";
	}

	// Gone in the same frame: the screen it covered is about to be captured.
	function closeInstant(): void {
		root.instant = true;
		root.active = "";
	}

	function toggle(name, newMode): void {
		if (root.active === name && (!newMode || newMode === root.mode))
			root.close();
		else
			root.open(name, newMode);
	}

	IpcHandler {
		target: "shell"

		function toggle(name: string, mode: string): void {
			root.toggle(name, mode);
		}
	}
}
