pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
	id: root

	property bool panelOpen: false
	property string subView: "main"
	property bool instantHide: false

	onPanelOpenChanged: {
		if (root.panelOpen)
			Notifications.hideToasts();
	}

	signal refreshRequested()

	function refresh(): void {
		refreshRequested();
	}

	function toggle(view): void {
		if (root.panelOpen) {
			if (view && view !== "" && root.subView !== view) {
				Notifications.closeCenter();
				root.subView = view;
			} else
				root.close();
		} else {
			root.open(view);
		}
	}

	function toggleWifi(): void {
		root.toggle("wifi");
	}

	function toggleBluetooth(): void {
		root.toggle("bluetooth");
	}

	function toggleCapture(): void {
		root.toggle("capture");
	}

	function open(view): void {
		Notifications.closeCenter();
		root.instantHide = false;
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
		function toggleView(view: string): void {
			root.toggle(view);
		}
		function toggleWifi(): void {
			root.toggleWifi();
		}
		function toggleBluetooth(): void {
			root.toggleBluetooth();
		}
		function toggleCapture(): void {
			root.toggleCapture();
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
		function openCapture(): void {
			root.openCapture();
		}
		function close(): void {
			root.close();
		}
		function closeInstant(): void {
			root.closeInstant();
		}
		function refresh(): void {
			root.refresh();
		}
	}
}
