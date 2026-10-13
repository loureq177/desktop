pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
	id: root

	property bool panelOpen: false
	property string subView: "main"
	property bool instantHide: false
	property bool handoff: false

	onPanelOpenChanged: {
		if (root.panelOpen)
			Notifications.hideToasts();
	}

	signal refreshRequested()

	function refresh(): void {
		refreshRequested();
	}

	function toggle(): void {
		if (root.panelOpen)
			root.close();
		else
			root.open();
	}

	function open(view): void {
		Notifications.handOffCenter();
		root.instantHide = false;
		root.handoff = false;
		root.subView = (view && view !== "") ? view : "main";
		root.panelOpen = true;
	}

	function openWifi(): void {
		root.open("wifi");
	}

	function openBluetooth(): void {
		root.open("bluetooth");
	}

	function openCapture(): void {
		root.open("capture");
	}

	function close(): void {
		root.instantHide = false;
		root.handoff = false;
		root.panelOpen = false;
	}

	// The notification center opens in this panel's place.
	function handOff(): void {
		root.instantHide = false;
		root.handoff = root.panelOpen;
		root.panelOpen = false;
	}

	function closeInstant(): void {
		if (root.panelOpen)
			root.instantHide = true;
		root.panelOpen = false;
	}

	IpcHandler {
		target: "quicksettings"

		function toggle(): void {
			root.toggle();
		}
		function refresh(): void {
			root.refresh();
		}
	}
}
