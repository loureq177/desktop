pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// The panel on screen, at most one: opening one closes the one before. Each
// view shows itself while `active` names it (OverlayWindow.panel). Going
// anywhere else puts it away: a click outside it (OverlayWindow), on another
// module of the bar (Bar.leavePanels), or a key that changes the workspace,
// the special workspace, the window or the monitor (below).
Singleton {
	id: root

	// "launcher", "clipboard", "weather", "quicksettings",
	// "notifications", or "" with nothing open.
	property string active: ""
	// What it was opened on: the launcher's mode, the quick settings page.
	property string mode: ""
	// The last close skips the exit animation (see closeInstant).
	property bool instant: false
	// The panel a newly opened panel replaced: the centred windows swap in
	// place when one replaces another.
	property string previous: ""

	// Where the panels, the OSD and the toasts show: the focused monitor.
	readonly property var screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

	// The windows in the middle of the screen that share size, place and one
	// dim (CenterModal, CenterBackdrop).
	readonly property var centered: ["launcher", "clipboard"]

	// Also emitted for the panel already open, when it is opened on a new mode.
	signal opened(string name, string mode)

	function open(name, newMode): void {
		root.instant = false;
		if (root.active !== name)
			root.previous = root.active;
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
