import "../.."
import "../../widgets"
import "."
import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

DeviceList {
	id: root

	readonly property var wifiDevice: Net.wifi
	// The network the password form is open for.
	property var promptItem: null
	property bool showPassword: false

	title: "Wi-Fi"
	subtitle: !radioOn ? "Off" : (scanning ? "Scanning…" : items.length + " networks found")
	offIcon: "wifi-off"
	radioKey: Qt.Key_W
	radioOn: Networking.wifiEnabled
	prompting: promptItem !== null
	extraHeight: prompting ? passwordCard.implicitHeight + 12 : 0

	// One row per name: the connected access point, else the strongest.
	items: {
		var byName = {};
		for (const net of root.wifiDevice?.networks?.values ?? []) {
			if (!net || !net.name || net.name.trim() === "")
				continue;
			var strength = Net.signalPercent(net);
			var best = byName[net.name];
			if (best && (best.connected || (!net.connected && best.strength >= strength)))
				continue;
			byName[net.name] = {
				key: net.name,
				name: net.name,
				net: net,
				strength: strength,
				icon: root.signalIcon(strength),
				connected: net.connected,
				saved: net.known,
				detail: net.known ? "Saved" : "",
				dim: strength < 50,
				secured: net.security !== WifiSecurityType.Open && net.security !== WifiSecurityType.Unknown,
				open: net.security === WifiSecurityType.Open,
				battery: -1
			};
		}
		return Object.values(byName).sort((a, b) => {
			if (a.connected !== b.connected)
				return a.connected ? -1 : 1;
			if (a.saved !== b.saved)
				return a.saved ? -1 : 1;
			return b.strength - a.strength;
		});
	}

	onItemsChanged: {
		var connected = items.find(i => i.connected);
		if (connected && connected.key === pendingKey)
			clearPending();
		if (connected && promptItem && connected.key === promptItem.key)
			closePrompt();
	}

	function signalIcon(strength) {
		if (strength >= 75) return "wifi";
		if (strength >= 50) return "wifi-high";
		if (strength >= 25) return "wifi-low";
		if (strength > 0) return "wifi-zero";
		return "wifi-off";
	}

	function connect(item): void {
		if (promptItem && promptItem.key !== item.key)
			closePrompt();
		startPending(item.key, "Connecting…");
		item.net.connect();
	}

	function openPrompt(item): void {
		clearPending();
		errorMessage = "";
		showPassword = false;
		passInput.text = "";
		promptItem = item;
		passInput.forceActiveFocus();
	}

	function closePrompt(): void {
		promptItem = null;
		errorMessage = "";
		clearPending();
		passInput.text = "";
		root.forceActiveFocus();
	}

	function submitPassword(): void {
		if (!promptItem || isPending(promptItem))
			return;
		if (passInput.text.trim() === "") {
			passInput.forceActiveFocus();
			return;
		}
		startPending(promptItem.key, "Connecting…");
		promptItem.net.connectWithPsk(passInput.text);
		passInput.forceActiveFocus();
	}

	function rescan(): void {
		scanning = true;
		if (wifiDevice)
			wifiDevice.scannerEnabled = true;
		// Now rather than at the scanner's next round: Quickshell has no call for it.
		Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]);
		scanTimer.restart();
	}

	onScanRequested: rescan()
	onRadioToggled: {
		Networking.wifiEnabled = !Networking.wifiEnabled;
		if (Networking.wifiEnabled)
			rescan();
	}
	onActivated: item => {
		if (item.saved || !item.secured)
			connect(item);
		else
			openPrompt(item);
	}
	onDisconnectRequested: item => {
		if (promptItem && promptItem.key === item.key)
			closePrompt();
		clearPending();
		item.net.disconnect();
	}
	onForgetConfirmed: item => {
		if (promptItem && promptItem.key === item.key)
			closePrompt();
		item.net.forget();
	}
	onTimedOut: {
		if (prompting)
			passInput.forceActiveFocus();
	}
	onPromptKeyPressed: event => {
		if (event.key === Qt.Key_Escape) {
			closePrompt();
		} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
			submitPassword();
		} else if (event.key !== Qt.Key_J && event.key !== Qt.Key_K && event.key !== Qt.Key_Down && event.key !== Qt.Key_Up) {
			return;
		}
		event.accepted = true;
	}
	onVisibleChanged: {
		if (!visible && prompting)
			closePrompt();
	}

	Timer {
		id: scanTimer
		interval: 3000
		onTriggered: root.scanning = false
	}

	Rectangle {
		id: passwordCard
		Layout.fillWidth: true
		visible: root.prompting
		radius: Theme.roundingElement
		color: Theme.glass(Theme.bgMain)
		border.color: Theme.accentBlue
		border.width: 1
		implicitHeight: passCol.implicitHeight + 20

		ColumnLayout {
			id: passCol
			anchors.fill: parent
			anchors.margins: 12
			spacing: 10

			RowLayout {
				Layout.fillWidth: true
				spacing: 8

				StyledText {
					Layout.fillWidth: true
					text: "Enter password for \"" + (root.promptItem?.name ?? "") + "\""
					font.pixelSize: Theme.fontSizeSmall
					font.bold: true
					elide: Text.ElideRight
				}

				CloseButton {
					onClicked: root.closePrompt()
				}
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 36
				radius: Theme.roundingSubtle
				color: Theme.glass(Theme.bgCard)
				border.color: passInput.activeFocus ? Theme.accentBlue : Theme.border
				border.width: 1

				RowLayout {
					anchors.fill: parent
					anchors.leftMargin: 10
					anchors.rightMargin: 8
					spacing: 6

					TextInput {
						id: passInput
						Layout.fillWidth: true
						echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
						font.family: Theme.fontMono
						font.pixelSize: Theme.fontSizeSmall
						color: Theme.textMain
						clip: true
						onAccepted: root.submitPassword()

						StyledText {
							text: "Wi-Fi password…"
							mono: true
							font.pixelSize: Theme.fontSizeSmall
							color: Theme.textMuted
							visible: !passInput.text && !passInput.activeFocus
							anchors.verticalCenter: parent.verticalCenter
						}
					}

					IconButton {
						Layout.preferredWidth: 26
						Layout.preferredHeight: 26
						icon: root.showPassword ? "eye-off" : "eye"
						outlined: false
						onClicked: root.showPassword = !root.showPassword
					}
				}
			}

			StyledText {
				readonly property bool connecting: root.isPending(root.promptItem)
				visible: root.errorMessage !== "" || connecting
				Layout.fillWidth: true
				text: root.errorMessage !== "" ? root.errorMessage : root.pendingStatus
				mono: true
				font.pixelSize: Theme.fontSizeTiny
				color: root.errorMessage !== "" ? Theme.critical : Theme.warning
			}

			RowLayout {
				Layout.fillWidth: true
				spacing: 8

				Item { Layout.fillWidth: true }

				TextButton {
					text: "Cancel (Esc)"
					onClicked: root.closePrompt()
				}

				TextButton {
					readonly property bool connecting: root.isPending(root.promptItem)
					primary: true
					opacity: connecting ? 0.6 : 1.0
					text: connecting ? "Connecting…" : "Connect (Enter)"
					onClicked: root.submitPassword()
				}
			}
		}
	}
}
