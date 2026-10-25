import "../.."
import "."
import QtQuick

DeviceList {
	id: root

	readonly property var btAdapter: Bt.adapter

	title: "Bluetooth"
	subtitle: !radioOn ? "Off" : (scanning ? "Scanning for nearby devices…" : items.filter(i => i.saved).length + " paired devices")
	offIcon: "bluetooth-off"
	radioKey: Qt.Key_B
	radioOn: btAdapter?.enabled ?? false
	scanning: btAdapter?.discovering ?? false

	// Paired devices first, the connected ones on top; then the nearby ones
	// that have a name. Their own: without one, BlueZ makes the address the
	// alias, which is `name`.
	items: {
		var paired = [];
		var nearby = [];
		for (const d of root.btAdapter?.devices?.values ?? []) {
			var isPaired = d.paired || d.connected;
			if (!isPaired && !d.deviceName)
				continue;
			(isPaired ? paired : nearby).push({
				key: d.address,
				name: Bt.name(d),
				device: d,
				icon: root.deviceIcon(d),
				connected: d.connected,
				saved: isPaired,
				detail: isPaired ? "" : "Ready to pair",
				dim: !isPaired,
				open: false,
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

	// The line icon for a device: by the icon BlueZ gives it, else by words
	// in its name. The first rule that matches wins.
	readonly property var iconRules: [
		{ icon: "headphones", bluez: /head/, name: /airpods|px8|headphone|buds/ },
		{ icon: "speaker", bluez: /audio/, name: /charge|speaker|sound|jbl/ },
		{ icon: "mouse", bluez: /mouse/, name: /mouse/ },
		{ icon: "keyboard", bluez: /keyboard/, name: /keyboard/ },
		{ icon: "smartphone", bluez: /phone/, name: /phone/ },
		{ icon: "gamepad-2", bluez: /gamepad/, name: /controller/ }
	]

	function deviceIcon(d) {
		var bluez = (d.icon || "").toLowerCase();
		var name = (d.name || d.deviceName || "").toLowerCase();
		return iconRules.find(r => r.bluez.test(bluez) || r.name.test(name))?.icon ?? "bluetooth";
	}

	onScanRequested: {
		if (!btAdapter || !radioOn)
			return;
		btAdapter.discovering = true;
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
		item.device.forget();
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
