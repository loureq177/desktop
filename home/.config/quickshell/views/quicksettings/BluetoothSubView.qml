import "../.."
import "."
import Quickshell
import Quickshell.Bluetooth
import QtQuick

DeviceList {
	id: root

	readonly property var btAdapter: Bluetooth.defaultAdapter

	title: "Bluetooth"
	subtitle: !radioOn ? "Off" : (scanning ? "Scanning for nearby devices…" : items.filter(i => i.saved).length + " paired devices")
	noun: "Bluetooth"
	things: "devices"
	offIcon: "bluetooth-off"
	emptyTitle: "No Bluetooth devices found"
	emptyHint: "Press [r] to scan for devices"
	forgetVerb: "unpair"
	timeoutMessage: "Action timed out — device didn't respond"
	radioKey: Qt.Key_B
	radioOn: btAdapter?.enabled ?? false
	scanning: btAdapter?.discovering ?? false

	// Paired devices first, the connected ones on top; then the nearby ones
	// that have a name.
	items: {
		var paired = [];
		var nearby = [];
		for (const d of root.btAdapter?.devices?.values ?? []) {
			var isPaired = d.paired || d.connected;
			var name = d.name || d.deviceName;
			if (!isPaired && !name)
				continue;
			(isPaired ? paired : nearby).push({
				key: d.address,
				name: name || d.address,
				device: d,
				icon: root.deviceIcon(d),
				connected: d.connected,
				saved: isPaired,
				detail: isPaired ? "Paired" : "Ready to pair",
				dim: !isPaired,
				secured: false,
				battery: d.batteryAvailable && d.battery >= 0 ? d.battery : -1
			});
		}
		paired.sort((a, b) => a.connected !== b.connected ? (a.connected ? -1 : 1) : a.name.localeCompare(b.name));
		nearby.sort((a, b) => a.name.localeCompare(b.name));
		return paired.concat(nearby);
	}

	// The action under way is over once the device is where it was headed.
	// Paired is the whole job of pairing: not every device connects right after.
	onItemsChanged: {
		if (pendingKey === "")
			return;
		var target = items.find(i => i.key === pendingKey);
		if (!target
			|| (pendingStatus.indexOf("Pairing") === 0 && target.saved)
			|| (pendingStatus === "Connecting…" && target.connected)
			|| (pendingStatus === "Disconnecting…" && !target.connected)) {
			clearPending();
		}
	}

	function deviceIcon(d) {
		var iconName = (d.icon || "").toLowerCase();
		var name = (d.name || d.deviceName || "").toLowerCase();
		if (iconName.indexOf("head") !== -1 || name.indexOf("airpods") !== -1 || name.indexOf("px8") !== -1 || name.indexOf("headphone") !== -1 || name.indexOf("buds") !== -1)
			return "headphones";
		if (iconName.indexOf("audio") !== -1 || name.indexOf("charge") !== -1 || name.indexOf("speaker") !== -1 || name.indexOf("sound") !== -1 || name.indexOf("jbl") !== -1)
			return "speaker";
		if (iconName.indexOf("mouse") !== -1 || name.indexOf("mouse") !== -1)
			return "mouse";
		if (iconName.indexOf("keyboard") !== -1 || name.indexOf("keyboard") !== -1)
			return "keyboard";
		if (iconName.indexOf("phone") !== -1 || name.indexOf("phone") !== -1)
			return "smartphone";
		if (iconName.indexOf("gamepad") !== -1 || name.indexOf("controller") !== -1)
			return "gamepad-2";
		return "bluetooth";
	}

	onScanRequested: {
		if (!btAdapter || !radioOn)
			return;
		btAdapter.discovering = true;
		Quickshell.execDetached(["bluetoothctl", "--timeout", "15", "scan", "on"]);
		scanTimer.restart();
	}
	onRadioToggled: {
		if (!btAdapter)
			return;
		btAdapter.enabled = !btAdapter.enabled;
		if (btAdapter.enabled)
			scanRequested();
	}
	onActivated: item => {
		if (item.saved) {
			startPending(item.key, "Connecting…");
			item.device.connect();
		} else {
			startPending(item.key, "Pairing… confirm on device");
			item.device.pair();
		}
	}
	onDisconnectRequested: item => {
		startPending(item.key, "Disconnecting…");
		item.device.disconnect();
	}
	onForgetConfirmed: item => {
		item.device.unpair();
		Quickshell.execDetached(["bluetoothctl", "remove", item.key]);
	}

	Timer {
		id: scanTimer
		interval: 15000
		onTriggered: {
			if (root.btAdapter)
				root.btAdapter.discovering = false;
		}
	}
}
