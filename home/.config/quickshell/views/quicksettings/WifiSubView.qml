import "../.."
import "../../widgets"
import "."
import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

DeviceList {
	id: root

	readonly property var wifiDevice: SystemStatus.wifiDevice
	// The network the password form is open for.
	property var promptItem: null
	property bool showPassword: false

	title: "Wi-Fi"
	subtitle: !radioOn ? "Off" : (scanning ? "Scanning…" : items.length + " networks found")
	noun: "Wi-Fi"
	things: "networks"
	offIcon: "wifi-off"
	emptyTitle: "No networks found"
	emptyHint: "Press [r] to rescan"
	timeoutMessage: "Connection timed out"
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
			var strength = net.signalStrength > 1.0 ? net.signalStrength : net.signalStrength * 100;
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
				detail: net.known ? "Saved" : Math.round(strength) + "% signal",
				dim: strength < 50,
				secured: net.security !== WifiSecurityType.Open && net.security !== WifiSecurityType.Unknown,
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
		Quickshell.execDetached(["nmcli", "connection", "delete", item.name]);
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

				Text {
					Layout.fillWidth: true
					text: "Enter password for \"" + (root.promptItem?.name ?? "") + "\""
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSizeSmall
					font.bold: true
					color: Theme.textMain
					elide: Text.ElideRight
				}

				CloseButton {
					size: 22
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

						Text {
							text: "Wi-Fi password…"
							font.family: Theme.fontMono
							font.pixelSize: Theme.fontSizeSmall
							color: Theme.textMuted
							visible: !passInput.text && !passInput.activeFocus
							anchors.verticalCenter: parent.verticalCenter
						}
					}

					Rectangle {
						Layout.preferredWidth: 26
						Layout.preferredHeight: 26
						radius: Theme.roundingSubtle
						color: eyeArea.containsMouse ? Theme.bgHover : "transparent"

						LineIcon {
							anchors.centerIn: parent
							name: root.showPassword ? "eye-off" : "eye"
							size: 16
							color: eyeArea.containsMouse ? Theme.textMain : Theme.textDim
						}

						MouseArea {
							id: eyeArea
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: root.showPassword = !root.showPassword
						}
					}
				}
			}

			Text {
				readonly property bool connecting: root.isPending(root.promptItem)
				visible: root.errorMessage !== "" || connecting
				Layout.fillWidth: true
				text: root.errorMessage !== "" ? root.errorMessage : root.pendingStatus
				font.family: Theme.fontMono
				font.pixelSize: Theme.fontSizeTiny
				color: root.errorMessage !== "" ? Theme.critical : Theme.warning
			}

			RowLayout {
				Layout.fillWidth: true
				spacing: 8

				Item { Layout.fillWidth: true }

				Rectangle {
					implicitWidth: cancelLabel.implicitWidth + 18
					implicitHeight: 30
					radius: Theme.roundingSubtle
					color: cancelArea.containsMouse ? Theme.bgHover : "transparent"
					border.color: Theme.border
					border.width: 1

					Text {
						id: cancelLabel
						anchors.centerIn: parent
						text: "Cancel (Esc)"
						font.family: Theme.fontFamily
						font.pixelSize: Theme.fontSizeTiny
						color: Theme.textDim
					}

					MouseArea {
						id: cancelArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: root.closePrompt()
					}
				}

				Rectangle {
					readonly property bool connecting: root.isPending(root.promptItem)
					implicitWidth: connectLabel.implicitWidth + 20
					implicitHeight: 30
					radius: Theme.roundingSubtle
					opacity: connecting ? 0.6 : 1.0
					color: connectArea.containsMouse ? Qt.lighter(Theme.accentBlue, 1.15) : Theme.accentBlue

					Text {
						id: connectLabel
						anchors.centerIn: parent
						text: parent.connecting ? "Connecting…" : "Connect (Enter)"
						font.family: Theme.fontFamily
						font.pixelSize: Theme.fontSizeTiny
						font.bold: true
						color: Theme.bgMain
					}

					MouseArea {
						id: connectArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: root.submitPassword()
					}
				}
			}
		}
	}
}
