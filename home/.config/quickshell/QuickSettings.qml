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
	property string subView: "main" // "main" | "wifi" | "bluetooth"

	// Emitted when an external writer (volume, brightness,
	// power-save) changed audio/backlight/marker state behind the
	// panel's back. QuickSettingsView refreshes its polled readouts on it
	// instead of lagging up to one poll interval behind the OSD.
	signal refreshRequested()

	function refresh(): void {
		refreshRequested();
	}

	readonly property bool nightLightAuto: {
		var h = new Date().getHours();
		return h >= 20 || h < 6;
	}
	property bool nightLightManualOverride: false
	property bool nightLightManual: false
	property bool nightLight: nightLightManualOverride ? nightLightManual : nightLightAuto

	function toggleNightLight(): void {
		root.nightLightManual = !root.nightLight;
		root.nightLightManualOverride = true;
		if (root.nightLight)
			Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", "4500"]);
		else
			Quickshell.execDetached(["hyprctl", "hyprsunset", "identity"]);
	}

	function resetNightLightToAuto(): void {
		root.nightLightManualOverride = false;
	}

	function toggle(view): void {
		if (root.panelOpen) {
			if (view && view !== "" && root.subView !== view)
				root.subView = view;
			else
				root.close();
		} else {
			root.open(view);
		}
	}

	function open(view): void {
		root.subView = (view && view !== "") ? view : "main";
		root.panelOpen = true;
	}

	function openWifi(): void {
		root.open("wifi");
	}

	function openBluetooth(): void {
		root.open("bluetooth");
	}

	function close(): void {
		root.panelOpen = false;
		root.subView = "main";
		Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap('reset')"]);
	}

	IpcHandler {
		target: "quicksettings"

		function toggle(): void {
			root.toggle();
		}
		function toggleView(view: string): void {
			root.toggle(view);
		}
		function open(): void {
			root.open();
		}
		function openView(view: string): void {
			root.open(view);
		}
		function openWifi(): void {
			root.openWifi();
		}
		function openBluetooth(): void {
			root.openBluetooth();
		}
		function close(): void {
			root.close();
		}
		function refresh(): void {
			root.refresh();
		}
		function toggleNightLight(): void {
			root.toggleNightLight();
		}
		function resetNightLightToAuto(): void {
			root.resetNightLightToAuto();
		}
	}
}
