import "../.."
import "../../widgets"
import "../../widgets/ListNav.js" as ListNav
import "."
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
	id: root

	signal backRequested()
	signal closeRequested()

	readonly property var btAdapter: Bluetooth.defaultAdapter
	readonly property bool btEnabled: btAdapter?.enabled ?? false
	readonly property bool discovering: btAdapter?.discovering ?? false

	property var pairedList: []
	property var availableList: []
	property var allItems: []
	property int currentIndex: 0

	readonly property int preferredHeight: {
		if (!btEnabled)
			return 260;
		var itemsCount = allItems.length;
		if (itemsCount === 0)
			return 220;
		var listHeight = itemsCount * 56 - 6;
		return Math.min(620, Math.max(260, 81 + listHeight));
	}
	readonly property string actionStatus: pending.status
	readonly property string targetDeviceAddress: pending.target
	property string errorMessage: ""
	property string pendingForgetAddr: ""

	function clearAction(): void {
		pending.clear();
	}

	Timer {
		id: forgetConfirmTimer
		interval: 3000
		onTriggered: {
			root.pendingForgetAddr = "";
			if (root.errorMessage.indexOf("Press X again") === 0)
				root.errorMessage = "";
		}
	}

	PendingAction {
		id: pending
		onTimedOut: expired => {
			if (expired !== "") {
				root.errorMessage = "Action timed out — device didn't respond";
				root.refreshDevices();
			}
		}
	}

	onBtEnabledChanged: {
		if (!btEnabled) {
			root.clearAction();
			root.errorMessage = "";
		}
	}

	function getDeviceIcon(d) {
		var iconName = (d.icon || "").toLowerCase();
		var name = (d.name || d.deviceName || "").toLowerCase();
		if (iconName.indexOf("head") !== -1 || name.indexOf("airpods") !== -1 || name.indexOf("px8") !== -1 || name.indexOf("headphone") !== -1 || name.indexOf("buds") !== -1)
			return "󰋋";
		if (iconName.indexOf("audio") !== -1 || name.indexOf("charge") !== -1 || name.indexOf("speaker") !== -1 || name.indexOf("sound") !== -1 || name.indexOf("jbl") !== -1)
			return "󰓃";
		if (iconName.indexOf("mouse") !== -1 || name.indexOf("mouse") !== -1)
			return "󰍽";
		if (iconName.indexOf("keyboard") !== -1 || name.indexOf("keyboard") !== -1)
			return "󰌌";
		if (iconName.indexOf("phone") !== -1 || name.indexOf("phone") !== -1)
			return "󰏲";
		if (iconName.indexOf("gamepad") !== -1 || name.indexOf("controller") !== -1)
			return "󰊴";
		return "󰂯";
	}

	function refreshDevices(): void {
		if (!btAdapter || !btAdapter.devices || !btAdapter.devices.values) {
			pairedList = [];
			availableList = [];
			allItems = [];
			if (targetDeviceAddress !== "")
				clearAction();
			return;
		}

		var raw = btAdapter.devices.values || [];
		var paired = [];
		var available = [];

		for (var i = 0; i < raw.length; i++) {
			var d = raw[i];
			if (!d)
				continue;
			var displayName = d.name || d.deviceName || d.address;
			if (!displayName)
				continue;

			var isPaired = d.paired || d.connected;
			var item = {
				device: d,
				name: displayName,
				address: d.address,
				connected: d.connected,
				paired: isPaired,
				pairing: d.pairing,
				battery: d.battery,
				batteryAvailable: d.batteryAvailable,
				icon: getDeviceIcon(d),
				isHeader: false
			};

			if (isPaired) {
				paired.push(item);
			} else if (d.name || d.deviceName) {
				available.push(item);
			}
		}

		paired.sort(function(a, b) {
			if (a.connected !== b.connected) return a.connected ? -1 : 1;
			return a.name.localeCompare(b.name);
		});

		available.sort(function(a, b) {
			return a.name.localeCompare(b.name);
		});

		pairedList = paired;
		availableList = available;

		var all = [];
		for (var p = 0; p < paired.length; p++)
			all.push(paired[p]);
		for (var a = 0; a < available.length; a++)
			all.push(available[a]);

		var curAddr = (currentIndex >= 0 && currentIndex < allItems.length && allItems[currentIndex]) ? allItems[currentIndex].address : "";
		allItems = all;
		if (curAddr !== "") {
			for (var s = 0; s < all.length; s++) {
				if (all[s].address === curAddr) {
					currentIndex = s;
					break;
				}
			}
		}
		if (currentIndex >= all.length)
			currentIndex = Math.max(0, all.length - 1);

		if (targetDeviceAddress !== "" && actionStatus !== "") {
			var target = null;
			for (var t = 0; t < all.length; t++) {
				if (all[t].address === targetDeviceAddress) {
					target = all[t];
					break;
				}
			}
			if (!target) {
				clearAction();
			} else if ((actionStatus === "Connecting…" || actionStatus.indexOf("Pairing") === 0) && target.connected) {
				clearAction();
				errorMessage = "";
			} else if (actionStatus === "Disconnecting…" && !target.connected) {
				clearAction();
				errorMessage = "";
			}
		}
	}

	function toggleBluetooth(): void {
		if (btAdapter) {
			btAdapter.enabled = !btAdapter.enabled;
			if (btAdapter.enabled)
				startScan();
			else
				clearAction();
		} else {
			clearAction();
		}
	}

	function startScan(): void {
		if (!btAdapter || !btEnabled)
			return;
		try {
			btAdapter.discovering = true;
		} catch (e) {}
		Quickshell.execDetached(["bluetoothctl", "--timeout", "15", "scan", "on"]);
		scanTimer.restart();
	}

	Timer {
		id: forgetRefreshTimer
		interval: 600
		onTriggered: root.refreshDevices()
	}

	Timer {
		id: scanTimer
		interval: 15000
		onTriggered: {
			if (root.btAdapter) {
				try {
					root.btAdapter.discovering = false;
				} catch (e) {}
			}
			root.refreshDevices();
		}
	}

	Timer {
		id: autoRefresh
		interval: 3000
		repeat: true
		running: root.visible && root.btEnabled
		onTriggered: root.refreshDevices()
	}

	function connectDevice(item): void {
		if (!item || !item.address)
			return;
		if (pending.target === item.address && pending.status !== "")
			return;
		errorMessage = "";
		pending.start(item.address, "Connecting…");
		try {
			item.device.connect();
		} catch (e) {
			errorMessage = "Connect failed";
			pending.clear();
		}
	}

	function disconnectDevice(item): void {
		if (!item || !item.address)
			return;
		errorMessage = "";
		pending.start(item.address, "Disconnecting…");
		try {
			item.device.disconnect();
		} catch (e) {
			errorMessage = "Disconnect failed";
			pending.clear();
		}
	}

	function pairDevice(item): void {
		if (!item || !item.address)
			return;
		if (pending.target === item.address && pending.status !== "")
			return;
		errorMessage = "";
		pending.start(item.address, "Pairing… confirm on device");
		try {
			item.device.pair();
		} catch (e) {
			errorMessage = "Pairing failed";
			pending.clear();
		}
	}

	function forgetDevice(item): void {
		if (!item || !item.address)
			return;
		if (root.pendingForgetAddr !== item.address) {
			root.pendingForgetAddr = item.address;
			root.errorMessage = "Press X again to unpair \"" + item.name + "\"";
			forgetConfirmTimer.restart();
			return;
		}
		forgetConfirmTimer.stop();
		root.pendingForgetAddr = "";
		errorMessage = "";
		if (pending.target === item.address)
			pending.clear();
		if (item.device) {
			try { item.device.unpair(); } catch (e) {}
		}
		Quickshell.execDetached(["bluetoothctl", "remove", item.address]);
		forgetRefreshTimer.restart();
	}

	function selectItem(index): void {
		if (index < 0 || index >= allItems.length)
			return;
		var item = allItems[index];
		if (!item || item.isHeader)
			return;

		if (item.connected)
			return;
		if (pending.target === item.address && pending.status !== "")
			return;
		if (item.paired) {
			connectDevice(item);
		} else {
			pairDevice(item);
		}
	}

	function toggleConnection(index): void {
		if (index < 0 || index >= allItems.length)
			return;
		var item = allItems[index];
		if (!item || item.isHeader)
			return;

		if (pending.target === item.address && pending.status !== "")
			return;
		if (item.connected) {
			disconnectDevice(item);
			return;
		}
		if (item.paired) {
			connectDevice(item);
		} else {
			pairDevice(item);
		}
	}

	onVisibleChanged: {
		if (visible) {
			errorMessage = "";
			refreshDevices();
			if (btEnabled)
				startScan();
			currentIndex = 0;
			root.forceActiveFocus();
		} else {
			clearAction();
		}
	}

	Keys.onPressed: event => {
		var next = ListNav.step(event, allItems.length, currentIndex);
		if (next >= 0) {
			currentIndex = next;
			listView.positionViewAtIndex(next, ListView.Contain);
			event.accepted = true;
		} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
			if (!event.isAutoRepeat && root.btEnabled)
				toggleConnection(currentIndex);
			event.accepted = true;
		} else if (event.key === Qt.Key_Space) {
			if (!event.isAutoRepeat)
				toggleBluetooth();
			event.accepted = true;
		} else if (event.key === Qt.Key_X || event.key === Qt.Key_Delete) {
			if (!event.isAutoRepeat && currentIndex >= 0 && currentIndex < allItems.length)
				forgetDevice(allItems[currentIndex]);
			event.accepted = true;
		} else if (event.key === Qt.Key_R) {
			startScan();
			event.accepted = true;
		} else if (event.key === Qt.Key_B) {
			toggleBluetooth();
			event.accepted = true;
		} else if (event.key === Qt.Key_H || event.key === Qt.Key_Left || event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
			backRequested();
			event.accepted = true;
		}
	}

	ColumnLayout {
		anchors.fill: parent
		spacing: 12

		SubViewHeader {
			Layout.fillWidth: true
			title: "Bluetooth"
			subtitle: !root.btEnabled
				? "Off"
				: (root.discovering ? "Scanning for nearby devices…" : (root.pairedList.length + " paired devices"))
			enabledState: root.btEnabled
			isScanning: root.discovering
			onBackClicked: root.backRequested()
			onScanClicked: root.startScan()
			onToggleClicked: root.toggleBluetooth()
		}

		SubViewHeaderRule {}

		ErrorBanner {
			visible: root.errorMessage !== "" && root.btEnabled
			message: root.errorMessage
		}

		SubViewOffPlaceholder {
			visible: !root.btEnabled
			icon: "󰂲"
			title: "Bluetooth is turned off"
			subtitle: "Turn on Bluetooth to scan and connect to devices"
			buttonText: "Turn On Bluetooth"
			hintText: "Press [space] to turn on"
			onEnableClicked: root.toggleBluetooth()
		}

		Item {
			Layout.fillWidth: true
			Layout.fillHeight: true
			visible: root.btEnabled

			StyledListView {
				id: listView
				model: root.allItems

				delegate: ListRowCard {
					id: delegateRoot

					readonly property bool isTarget: root.targetDeviceAddress === modelData.address && root.actionStatus !== ""

					isSelected: index === root.currentIndex
					isConnected: modelData.connected
					onClicked: {
						root.currentIndex = index;
						root.selectItem(index);
					}

					Text {
						Layout.preferredWidth: 24
						horizontalAlignment: Text.AlignHCenter
						text: modelData.icon
						font.family: Theme.fontFamily
						font.pixelSize: 20
						color: isConnected ? Theme.accentBlue : (modelData.paired ? Theme.textMain : Theme.textDim)
					}

					ColumnLayout {
						Layout.fillWidth: true
						spacing: 1

						Text {
							Layout.fillWidth: true
							text: modelData.name
							font.family: Theme.fontFamily
							font.pixelSize: Theme.fontSizeSmall + 1
							font.bold: isConnected || isSelected
							color: isConnected ? Theme.accentBlue : Theme.textMain
							elide: Text.ElideRight
						}

						RowLayout {
							Layout.fillWidth: true
							spacing: 6

							Text {
								text: isTarget
									? root.actionStatus
									: (isConnected
										? "Connected"
										: (modelData.paired ? "Paired" : "Ready to pair"))
								font.family: Theme.fontMono
								font.pixelSize: Theme.fontSizeSmall - 2
								color: isTarget ? Theme.warning : (isConnected ? Theme.accentBlue : Theme.textDim)
							}

							Text {
								visible: modelData.batteryAvailable && modelData.battery >= 0
								text: "·  󰥉 " + Math.round(modelData.battery * 100) + "%"
								font.family: Theme.fontMono
								font.pixelSize: Theme.fontSizeSmall - 2
								color: modelData.battery <= 0.20 ? Theme.critical : (modelData.battery <= 0.40 ? Theme.warning : Theme.accentGreen)
							}
						}
					}

					ListRowActions {
						isConnected: delegateRoot.isConnected
						isSelected: delegateRoot.isSelected
						canForget: modelData.paired
						busy: delegateRoot.isTarget
						onDisconnectClicked: root.disconnectDevice(modelData)
						onForgetClicked: root.forgetDevice(modelData)
					}
				}
			}

			EmptyListHint {
				anchors.fill: parent
				visible: root.allItems.length === 0 && !root.discovering
				title: "No Bluetooth devices found"
				hint: "Press [r] to scan for devices"
			}
		}
	}
}
