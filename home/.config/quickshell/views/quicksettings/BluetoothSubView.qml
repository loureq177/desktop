// Bluetooth sub-menu: replaces bluetui terminal app.
// Allows scanning, connecting, pairing, disconnecting, and forgetting devices.
// Displays battery readouts and device-specific icons.
// Full Vim key navigation (h/j/k/l, g/G, Enter connect/disconnect, Space toggles radio, r, b, x, Esc, q).
import "../.."
import "../../widgets"
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
	// Two-step forget confirm: first X arms, second X within 3s executes.
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

		// Clear a pending action once its outcome is visible (native
		// Quickshell.Bluetooth path has no Process.onExited to do it).
		// Also clears a stale status when the device vanished (e.g. BT off).
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

	// Delayed refresh after forget/remove: bluetoothctl is async and an
	// immediate refresh re-shows the just-removed device (race).
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
		// NOTE: devices needing a PIN/passkey have no agent UI here yet —
		// confirm the pairing on the device itself if it stays on Pairing….
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
		// Two-step: first call arms, second call within 3s executes.
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
		// Don't refresh immediately — the daemon hasn't processed the
		// remove yet and the device would flicker back. The timer +
		// autoRefresh will converge shortly.
		forgetRefreshTimer.restart();
	}

	function selectItem(index): void {
		if (index < 0 || index >= allItems.length)
			return;
		var item = allItems[index];
		if (!item || item.isHeader)
			return;

		// Same rule as Wi-Fi: clicking the connected row must NOT
		// disconnect. Use the explicit Disconnect button or Enter key
		// instead — full-row clicks disconnect far too easily.
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

	// ─── Vim Key Navigation ──────────────────────────────────────────
	Keys.onPressed: event => {
		if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
			if (allItems.length > 0) {
				currentIndex = Math.min(allItems.length - 1, currentIndex + 1);
				listView.positionViewAtIndex(currentIndex, ListView.Contain);
			}
			event.accepted = true;
		} else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
			if (allItems.length > 0) {
				currentIndex = Math.max(0, currentIndex - 1);
				listView.positionViewAtIndex(currentIndex, ListView.Contain);
			}
			event.accepted = true;
		} else if (event.key === Qt.Key_G && !(event.modifiers & Qt.ShiftModifier)) {
			currentIndex = 0;
			listView.positionViewAtIndex(0, ListView.Contain);
			event.accepted = true;
		} else if (event.key === Qt.Key_G && (event.modifiers & Qt.ShiftModifier)) {
			currentIndex = Math.max(0, allItems.length - 1);
			listView.positionViewAtIndex(currentIndex, ListView.Contain);
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

		// ─── Header ───────────────────────────────────────────────────
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

		// Divider
		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: 1
			color: Theme.border
		}

		// Inline error banner (timeouts, cli failures). Previously BT had
		// no error surface at all — failed pair/connect just stuck on
		// "Connecting…" until the 15s timeout silently cleared it.
		// NOTE: Theme.critical is a string, so .r/.g/.b needs Qt.color().
		Rectangle {
			Layout.fillWidth: true
			visible: root.errorMessage !== "" && root.btEnabled
			radius: Theme.roundingElement
			color: Qt.rgba(Qt.color(Theme.critical).r, Qt.color(Theme.critical).g, Qt.color(Theme.critical).b, 0.10)
			border.color: Qt.rgba(Qt.color(Theme.critical).r, Qt.color(Theme.critical).g, Qt.color(Theme.critical).b, 0.40)
			border.width: 1
			implicitHeight: btErrRow.implicitHeight + 16

			RowLayout {
				id: btErrRow
				anchors.fill: parent
				anchors.margins: 8
				spacing: 8

				Text {
					text: "⚠"
					font.pixelSize: Theme.fontSizeSmall
					color: Theme.critical
				}
				Text {
					Layout.fillWidth: true
					text: root.errorMessage
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeSmall - 1
					color: Theme.critical
					elide: Text.ElideRight
				}
			}
		}

		// ─── Off-state Placeholder ─────────────────────────────────────
		SubViewOffPlaceholder {
			visible: !root.btEnabled
			icon: "󰂲"
			title: "Bluetooth is turned off"
			subtitle: "Turn on Bluetooth to scan and connect to devices"
			buttonText: "Turn On Bluetooth"
			hintText: "Press [space] to turn on"
			onEnableClicked: root.toggleBluetooth()
		}

		// ─── Device List ───────────────────────────────────────────────
		Item {
			Layout.fillWidth: true
			Layout.fillHeight: true
			visible: root.btEnabled

			ListView {
				id: listView
				anchors.fill: parent
				clip: true
				spacing: 6
				model: root.allItems
				boundsBehavior: Flickable.DragAndOvershootBounds
				flickDeceleration: Theme.flickDecel
				maximumFlickVelocity: Theme.maxFlickVel

				ScrollBar.vertical: ScrollBar {
					id: vScrollBar
					visible: size < 1.0
					active: size < 1.0
					policy: ScrollBar.AsNeeded
					contentItem: Rectangle {
						implicitWidth: 4
						radius: Theme.roundingSubtle
						color: parent.hovered || parent.pressed ? Theme.textDim : Theme.border
					}
				}

				delegate: Rectangle {
					id: delegateRoot
					width: listView.width - ((listView.ScrollBar.vertical && listView.ScrollBar.vertical.visible) ? 10 : 0)
					height: 50
					radius: Theme.roundingElement

					readonly property bool isSelected: index === root.currentIndex
					readonly property bool isConnected: modelData.connected
					readonly property bool isTarget: root.targetDeviceAddress === modelData.address && root.actionStatus !== ""

					color: delegateArea.containsMouse
						? Theme.bgHover
						: (isConnected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08) : Theme.bgMain)

					border.color: isConnected
						? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40)
						: (delegateArea.containsMouse ? Theme.textDim : Theme.border)
					border.width: 1

					Behavior on color { ColorAnimation { duration: 100 } }
					Behavior on border.color { ColorAnimation { duration: 100 } }

					Rectangle {
						anchors.fill: parent
						radius: parent.radius
						color: isConnected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20) : Theme.selectionBg
						border.color: Theme.selectionBorder
						border.width: 1
						opacity: isSelected ? 1.0 : 0.0
						visible: opacity > 0.0
						z: 0

						Behavior on opacity {
							NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
						}
					}

					MouseArea {
						id: delegateArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						z: 1
						onClicked: mouse => {
							mouse.accepted = true;
							root.currentIndex = index;
							root.selectItem(index);
						}
					}

					RowLayout {
						anchors.fill: parent
						anchors.leftMargin: 12
						anchors.rightMargin: 12
						spacing: 10
						// Must sit above delegateArea, otherwise the full-row
						// MouseArea swallows clicks meant for the buttons.
						z: 2

						// Device Type Icon
						Text {
							Layout.preferredWidth: 24
							horizontalAlignment: Text.AlignHCenter
							text: modelData.icon
							font.family: Theme.fontFamily
							font.pixelSize: 20
							color: isConnected ? Theme.accentBlue : (modelData.paired ? Theme.textMain : Theme.textDim)
						}

						// Name & Status
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

						// Right Action Buttons
						RowLayout {
							spacing: 6

							// Disconnect button for connected device
							Rectangle {
								visible: isConnected
								implicitWidth: disLabel.implicitWidth + 14
								implicitHeight: 26
								radius: Theme.roundingSubtle
								color: disArea.containsMouse ? Theme.bgCard : "transparent"
								border.color: disArea.containsMouse ? Theme.textDim : Theme.border
								border.width: 1

								Text {
									id: disLabel
									anchors.centerIn: parent
									text: "Disconnect"
									font.family: Theme.fontFamily
									font.pixelSize: Theme.fontSizeSmall - 2
									color: Theme.textMain
								}

								MouseArea {
									id: disArea
									anchors.fill: parent
									hoverEnabled: true
									cursorShape: Qt.PointingHandCursor
									onClicked: mouse => {
										mouse.accepted = true;
										root.disconnectDevice(modelData);
									}
								}
							}

							// Forget/Remove button for paired/connected
							Rectangle {
								visible: modelData.paired || isConnected
								implicitWidth: 26
								implicitHeight: 26
								radius: Theme.roundingSubtle
								color: fArea.containsMouse ? Theme.bgCard : "transparent"
								border.color: fArea.containsMouse ? Theme.critical : "transparent"
								border.width: 1

								Text {
									anchors.centerIn: parent
									text: "󰆴"
									font.family: Theme.fontFamily
									font.pixelSize: 14
									color: fArea.containsMouse ? Theme.critical : Theme.textDim
								}

								MouseArea {
									id: fArea
									anchors.fill: parent
									hoverEnabled: true
									cursorShape: Qt.PointingHandCursor
									onClicked: mouse => {
										mouse.accepted = true;
										root.forgetDevice(modelData);
									}
								}
							}

							// Chevron for connectable / unparied
							Text {
								visible: !isConnected && !isTarget
								text: "›"
								font.family: Theme.fontFamily
								font.pixelSize: 18
								color: isSelected ? Theme.accentBlue : Theme.textMuted
							}
						}
					}
				}
			}

			// Empty devices placeholder
			Item {
				anchors.fill: parent
				visible: root.allItems.length === 0 && !root.discovering

				ColumnLayout {
					anchors.centerIn: parent
					spacing: 8

					Text {
						Layout.alignment: Qt.AlignHCenter
						text: "No Bluetooth devices found"
						font.family: Theme.fontFamily
						font.pixelSize: Theme.fontSizeSmall
						color: Theme.textDim
					}

					Text {
						Layout.alignment: Qt.AlignHCenter
						text: "Press [r] to scan for devices"
						font.family: Theme.fontMono
						font.pixelSize: Theme.fontSizeSmall - 2
						color: Theme.textMuted
					}
				}
			}
		}
	}
}
