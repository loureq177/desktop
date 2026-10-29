pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// At most one panel on screen; a click outside, another bar module or a key that
// moves focus elsewhere puts it away.
Singleton {
	id: root

	// "launcher", "actions", "notifications", "weather", or "" with nothing open.
	property string active: ""
	// What it was opened on: the launcher's list, the page of Actions.
	property string mode: ""

	// Where the panels, the OSD and the toasts show: the focused monitor.
	readonly property var screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

	// Also emitted for the panel already open, when it is opened on a new mode.
	signal opened(string name, string mode)

	function open(name: string, newMode): void {
		root.mode = newMode || "";
		root.active = name;
		root.opened(name, root.mode);
		pointerRefresh.restart();
	}

	// Without a name, whatever is open. The arguments that may be left out are
	// untyped: a missing `string` argument arrives as "undefined".
	function close(name): void {
		if (!name || name === root.active)
			root.active = "";
	}

	function toggle(name: string, newMode): void {
		if (root.active === name && (!newMode || newMode === root.mode))
			root.close();
		else
			root.open(name, newMode);
	}

	// A panel taking the keyboard takes the pointer off the bar: the next click there
	// would only bring it back.
	Timer {
		id: pointerRefresh
		interval: 100
		onTriggered: Hypr.refreshPointer()
	}

	// The window Hyprland last reported focused. A layer taking the keyboard
	// reports none, which is not a move elsewhere.
	property string focusedWindow: ""

	Connections {
		target: Hyprland
		function onRawEvent(ev) {
			if (ev.name === "activewindowv2") {
				var addr = String(ev.data ?? "");
				if (addr === "" || addr === ",")
					return;
				var moved = root.focusedWindow !== "" && addr !== root.focusedWindow;
				root.focusedWindow = addr;
				if (moved)
					root.close();
			} else if (ev.name === "workspacev2" || ev.name === "activespecial" || ev.name === "focusedmon") {
				root.close();
			}
		}
	}

	IpcHandler {
		target: "shell"

		function toggle(name: string, mode: string): void {
			root.toggle(name, mode);
		}
	}
}
