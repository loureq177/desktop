import "../.."
import "../../widgets"
import "."
import QtQuick
import QtQuick.Layouts

DeviceList {
	id: root

	readonly property var btAdapter: Bt.adapter
	// The device the name form is open for.
	property var renaming: null

	title: "Bluetooth"
	readonly property int pairedCount: items.filter(i => i.saved).length
	subtitle: !radioOn ? "Off" : (scanning ? "Scanning for nearby devices…" : pairedCount + (pairedCount === 1 ? " paired device" : " paired devices"))
	offIcon: "bluetooth-off"
	radioKey: Qt.Key_B
	radioOn: btAdapter?.enabled ?? false
	scanning: btAdapter?.discovering ?? false
	renameable: true
	// Ahead of the page only with nothing connected: discovery can make headphones stutter.
	looking: radioOn && (visible || (panelOpen && Bt.connected.length === 0))
	prompting: renaming !== null
	extraHeight: prompting ? nameCard.implicitHeight + 12 : 0

	// Paired devices first, connected on top, then nearby ones with a name of their own
	// (BlueZ uses the address otherwise).
	// Only while shown: a device nearby coming or going would remake the hidden list.
	items: {
		if (!visible)
			return [];
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

	function openRename(item): void {
		renaming = item;
		nameInput.text = Bt.name(item.device);
		nameInput.selectAll();
		nameInput.forceActiveFocus();
	}

	function closeRename(): void {
		renaming = null;
		focusList();
	}

	// An empty one gives the device's own name back (BlueZ's alias).
	function saveRename(): void {
		renaming.device.name = nameInput.text.trim();
		closeRename();
	}

	onLookingChanged: {
		if (btAdapter)
			btAdapter.discovering = looking;
	}
	Component.onDestruction: {
		if (looking && btAdapter)
			btAdapter.discovering = false;
	}
	onRadioToggled: {
		if (btAdapter)
			btAdapter.enabled = !btAdapter.enabled;
	}
	onRenameRequested: item => openRename(item)
	onVisibleChanged: {
		if (!visible && prompting)
			closeRename();
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

	FormCard {
		id: nameCard
		visible: root.prompting
		title: "New name for \"" + (root.renaming?.name ?? "") + "\""
		acceptText: "Save (Enter)"
		onAccepted: root.saveRename()
		onCancelled: root.closeRename()

		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: 36
			radius: Theme.roundingSubtle
			color: Theme.glass(Theme.bgCard)
			border.color: nameInput.activeFocus ? Theme.accentBlue : Theme.border
			border.width: 1

			TextInput {
				id: nameInput
				anchors.fill: parent
				anchors.leftMargin: 10
				anchors.rightMargin: 10
				verticalAlignment: TextInput.AlignVCenter
				font.family: Theme.fontMono
				font.pixelSize: Theme.fontSizeSmall
				color: Theme.textMain
				selectionColor: Theme.accentBlue
				clip: true
				Keys.onEscapePressed: root.closeRename()
				onAccepted: root.saveRename()
			}
		}
	}
}
