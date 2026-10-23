pragma Singleton
import Quickshell
import Quickshell.Bluetooth
import QtQuick

// Bluetooth: the default adapter and the devices connected through it.
Singleton {
	id: root

	readonly property var adapter: Bluetooth.defaultAdapter
	readonly property bool enabled: adapter?.enabled ?? false
	readonly property var connected: (adapter?.devices?.values ?? []).filter(d => d.connected)
	readonly property string icon: !enabled ? "bluetooth-off" : connected.length > 0 ? "bluetooth-connected" : "bluetooth"
	readonly property string status: !adapter ? "No adapter"
		: connected.length > 1 ? connected.length + " connected"
		: connected.length === 1 ? name(connected[0])
		: enabled ? "On" : "Off"

	// What a device calls itself, falling back to its address.
	function name(d): string {
		return d.name || d.deviceName || d.address;
	}

	function toggle(): void {
		if (adapter)
			adapter.enabled = !enabled;
	}
}
