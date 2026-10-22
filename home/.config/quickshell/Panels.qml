pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// The panel on screen, at most one: opening one closes the one before. Going
// anywhere else puts it away: a click outside it, on another module of the
// bar (Bar.leavePanels), or a key that changes the workspace, the special
// workspace, the window or the monitor (below).
Singleton {
	id: root

	// "launcher", "actions", "notifications", "weather", or "" with nothing open.
	property string active: ""
	// What it was opened on: the launcher's list, the page of Actions.
	property string mode: ""
	// The last close skips the exit animation (see closeInstant).
	property bool instant: false

	// Where the panels, the OSD and the toasts show: the focused monitor.
	readonly property var screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

	// Also emitted for the panel already open, when it is opened on a new mode.
	signal opened(string name, string mode)

	function open(name: string, newMode): void {
		root.instant = false;
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

	// Gone in the same frame: the screen it covered is about to be captured.
	function closeInstant(): void {
		root.instant = true;
		root.active = "";
	}

	function toggle(name: string, newMode): void {
		if (root.active === name && (!newMode || newMode === root.mode))
			root.close();
		else
			root.open(name, newMode);
	}

	// A panel that takes the keyboard takes the pointer off the bar with it,
	// and the next click would only bring it back: the click that should put
	// the panel away again. Moving the cursor to where it already is hands the
	// pointer back to whatever lies under it.
	Timer {
		id: pointerRefresh
		interval: 100
		onTriggered: Quickshell.execDetached(["sh", "-c", 'p=$(hyprctl cursorpos) && hyprctl dispatch "hl.dsp.cursor.move({ x = ${p%%,*}, y = ${p##*, } })"'])
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
