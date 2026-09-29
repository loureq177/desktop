// Quick settings state: owns the top-right OneUI/GNOME-style panel with
// volume/brightness sliders and toggle tiles.
// Control via IPC: `qs ipc call quicksettings <toggle|open|close>`
// (SUPER + A).
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
	id: root

	property bool panelOpen: false

	// Emitted when an external writer (volume.sh, brightness.sh,
	// power-save.sh) changed audio/backlight/marker state behind the
	// panel's back. QuickSettingsView refreshes its polled readouts on it
	// instead of lagging up to one poll interval behind the OSD.
	signal refreshRequested()

	function refresh(): void {
		refreshRequested();
	}

	function toggle(): void {
		root.panelOpen = !root.panelOpen;
	}

	function open(): void {
		root.panelOpen = true;
	}

	function close(): void {
		root.panelOpen = false;
	}

	IpcHandler {
		target: "quicksettings"

		function toggle(): void {
			root.toggle();
		}
		function open(): void {
			root.open();
		}
		function close(): void {
			root.close();
		}
		function refresh(): void {
			root.refresh();
		}
	}
}
