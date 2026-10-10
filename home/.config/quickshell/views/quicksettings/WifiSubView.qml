import "../.."
import "../../widgets"
import "."
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
	id: root

	signal backRequested()
	signal closeRequested()

	readonly property var wifiDevice: {
		var vals = Networking.devices.values;
		for (var i = 0; i < vals.length; i++) {
			if (vals[i].type === DeviceType.Wifi)
				return vals[i];
		}
		return null;
	}

	readonly property bool wifiEnabled: Networking.wifiEnabled
	property bool scanning: false
	property var networkList: []
	property int currentIndex: 0

	readonly property int preferredHeight: {
		if (!wifiEnabled)
			return 260;
		var itemsCount = networkList.length;
		if (itemsCount === 0)
			return 220;
		var listHeight = itemsCount * 56 - 6;
		if (promptSsid !== "")
			listHeight += passwordCard.implicitHeight + 12;
		return Math.min(620, Math.max(260, 81 + listHeight));
	}

	property string promptSsid: ""
	property var promptNet: null
	property string passwordInput: ""
	property bool showPassword: false
	property string errorMessage: ""
	property string pendingForgetSsid: ""
	readonly property string connectingSsid: pending.target

	Timer {
		id: forgetConfirmTimer
		interval: 3000
		onTriggered: {
			root.pendingForgetSsid = "";
			if (root.errorMessage.indexOf("Press X again") === 0)
				root.errorMessage = "";
		}
	}

	Timer {
		id: forgetRefreshTimer
		interval: 600
		onTriggered: root.refreshList()
	}

	PendingAction {
		id: pending
		onTimedOut: expired => {
			if (expired !== "") {
				root.errorMessage = "Connection timed out";
				root.refreshList();
				if (root.promptSsid !== "")
					passInput.forceActiveFocus();
			}
		}
	}

	onWifiEnabledChanged: {
		if (!wifiEnabled)
			pending.clear();
	}

	function getSignalIcon(strength) {
		var s = strength > 1.0 ? strength : strength * 100;
		if (s >= 75) return "󰤨";
		if (s >= 50) return "󰤥";
		if (s >= 25) return "󰤢";
		if (s > 0) return "󰤟";
		return "󰤯";
	}

	function isSecured(sec) {
		return sec !== WifiSecurityType.Open && sec !== WifiSecurityType.Unknown;
	}

	function refreshList(): void {
		if (!wifiDevice || !wifiDevice.networks) {
			networkList = [];
			return;
		}

		var raw = wifiDevice.networks.values;
		var byName = {};
		for (var i = 0; i < raw.length; i++) {
			var net = raw[i];
			if (!net || !net.name || net.name.trim() === "")
				continue;
			var name = net.name;
			var str = net.signalStrength > 1.0 ? net.signalStrength : (net.signalStrength * 100);
			if (!byName[name] || net.connected || (str > byName[name].signalStrength && !byName[name].connected)) {
				byName[name] = {
					net: net,
					name: name,
					signalStrength: str,
					connected: net.connected,
					known: net.known,
					security: net.security
				};
			}
		}

		var arr = Object.values(byName);
		arr.sort(function(a, b) {
			if (a.connected !== b.connected) return a.connected ? -1 : 1;
			if (a.known !== b.known) return a.known ? -1 : 1;
			return b.signalStrength - a.signalStrength;
		});

		var curName = (currentIndex >= 0 && currentIndex < networkList.length && networkList[currentIndex]) ? networkList[currentIndex].name : "";
		networkList = arr;
		if (curName !== "") {
			for (var s = 0; s < arr.length; s++) {
				if (arr[s].name === curName) {
					currentIndex = s;
					break;
				}
			}
		}
		if (currentIndex >= arr.length)
			currentIndex = Math.max(0, arr.length - 1);

		if (pending.target !== "") {
			for (var c = 0; c < arr.length; c++) {
				if (arr[c].name === pending.target && arr[c].connected) {
					pending.clear();
					break;
				}
			}
		}

		if (promptSsid !== "") {
			for (var p = 0; p < arr.length; p++) {
				if (arr[p].name === promptSsid && arr[p].connected) {
					closePasswordPrompt();
					break;
				}
			}
		}
	}

	function rescan(): void {
		scanning = true;
		if (wifiDevice)
			wifiDevice.scannerEnabled = true;
		Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]);
		scanTimer.restart();
	}

	Timer {
		id: scanTimer
		interval: 3000
		onTriggered: {
			root.scanning = false;
			root.refreshList();
		}
	}

	Timer {
		id: autoRefresh
		interval: 3000
		repeat: true
		running: root.visible && root.wifiEnabled
		onTriggered: root.refreshList()
	}

	function toggleWifi(): void {
		Networking.wifiEnabled = !Networking.wifiEnabled;
		if (Networking.wifiEnabled)
			rescan();
	}

	function selectItem(index): void {
		if (index < 0 || index >= networkList.length)
			return;
		var item = networkList[index];
		if (!item)
			return;

		if (item.connected)
			return;
		if (pending.target === item.name && pending.status !== "")
			return;
		if (item.known || !isSecured(item.security)) {
			connectNetwork(item);
		} else {
			openPasswordPrompt(item);
		}
	}

	function toggleConnection(index): void {
		if (index < 0 || index >= networkList.length)
			return;
		var item = networkList[index];
		if (!item)
			return;

		if (pending.target === item.name && pending.status !== "")
			return;
		if (item.connected) {
			disconnectNetwork(item);
			return;
		}
		if (item.known || !isSecured(item.security)) {
			connectNetwork(item);
		} else {
			openPasswordPrompt(item);
		}
	}

	function connectNetwork(item): void {
		errorMessage = "";
		if (promptSsid !== "" && promptSsid !== item.name)
			closePasswordPrompt();
		pending.start(item.name, "Connecting…");
		try {
			item.net.connect();
		} catch (e) {
			errorMessage = "Connection failed";
			pending.clear();
		}
	}

	function disconnectNetwork(item): void {
		errorMessage = "";
		if (promptSsid === item.name)
			closePasswordPrompt();
		try { item.net.disconnect(); } catch (e) {}
		pending.clear();
		root.refreshList();
	}

	function forgetNetwork(item): void {
		if (!item || !item.name)
			return;
		if (root.pendingForgetSsid !== item.name) {
			root.pendingForgetSsid = item.name;
			root.errorMessage = "Press X again to forget \"" + item.name + "\"";
			forgetConfirmTimer.restart();
			return;
		}
		forgetConfirmTimer.stop();
		root.pendingForgetSsid = "";
		errorMessage = "";
		if (promptSsid === item.name)
			closePasswordPrompt();
		if (item.net) {
			try { item.net.forget(); } catch (e) {}
		}
		Quickshell.execDetached(["nmcli", "connection", "delete", item.name]);
		pending.clear();
		forgetRefreshTimer.restart();
	}

	function openPasswordPrompt(item): void {
		if (!item || item.connected)
			return;
		promptSsid = item.name;
		promptNet = item.net;
		passwordInput = "";
		showPassword = false;
		errorMessage = "";
		pending.clear();
		passInput.text = "";
		passInput.forceActiveFocus();
	}

	function closePasswordPrompt(): void {
		promptSsid = "";
		promptNet = null;
		passwordInput = "";
		errorMessage = "";
		pending.clear();
		forgetConfirmTimer.stop();
		root.pendingForgetSsid = "";
		if (passInput)
			passInput.text = "";
		root.forceActiveFocus();
	}

	function cancelPassword(): void {
		pending.clear();
		closePasswordPrompt();
	}

	function submitPassword(): void {
		if (promptSsid === "")
			return;
		if (pending.target === promptSsid && pending.status !== "")
			return;
		var pass = passInput ? passInput.text : passwordInput;
		if (!pass || pass.trim() === "") {
			if (passInput)
				passInput.forceActiveFocus();
			return;
		}
		var ssid = promptSsid;
		passwordInput = pass;
		pending.start(ssid, "Connecting…");
		errorMessage = "";

		try {
			promptNet.connectWithPsk(pass);
		} catch (e) {
			errorMessage = "Connection failed";
			pending.clear();
			passInput.forceActiveFocus();
			return;
		}
		passInput.forceActiveFocus();
	}

	onVisibleChanged: {
		if (visible) {
			refreshList();
			if (wifiEnabled)
				rescan();
			currentIndex = 0;
			root.forceActiveFocus();
		} else {
			if (promptSsid !== "")
				closePasswordPrompt();
			else
				pending.clear();
		}
	}

	Keys.onPressed: event => {
		if (promptSsid !== "") {
			if (event.key === Qt.Key_Escape) {
				cancelPassword();
				event.accepted = true;
			} else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(passInput && passInput.activeFocus)) {
				submitPassword();
				event.accepted = true;
			} else if (event.key === Qt.Key_J || event.key === Qt.Key_K || event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
				event.accepted = true;
			}
			return;
		}

		if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
			if (networkList.length > 0) {
				currentIndex = Math.min(networkList.length - 1, currentIndex + 1);
				listView.positionViewAtIndex(currentIndex, ListView.Contain);
			}
			event.accepted = true;
		} else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
			if (networkList.length > 0) {
				currentIndex = Math.max(0, currentIndex - 1);
				listView.positionViewAtIndex(currentIndex, ListView.Contain);
			}
			event.accepted = true;
		} else if (event.key === Qt.Key_G && !(event.modifiers & Qt.ShiftModifier)) {
			currentIndex = 0;
			listView.positionViewAtIndex(0, ListView.Contain);
			event.accepted = true;
		} else if (event.key === Qt.Key_G && (event.modifiers & Qt.ShiftModifier)) {
			currentIndex = Math.max(0, networkList.length - 1);
			listView.positionViewAtIndex(currentIndex, ListView.Contain);
			event.accepted = true;
		} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
			if (!event.isAutoRepeat && root.wifiEnabled)
				toggleConnection(currentIndex);
			event.accepted = true;
		} else if (event.key === Qt.Key_Space) {
			if (!event.isAutoRepeat)
				toggleWifi();
			event.accepted = true;
		} else if (event.key === Qt.Key_X || event.key === Qt.Key_Delete) {
			if (!event.isAutoRepeat && currentIndex >= 0 && currentIndex < networkList.length)
				forgetNetwork(networkList[currentIndex]);
			event.accepted = true;
		} else if (event.key === Qt.Key_R) {
			rescan();
			event.accepted = true;
		} else if (event.key === Qt.Key_W) {
			toggleWifi();
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
			title: "Wi-Fi"
			subtitle: !root.wifiEnabled ? "Off" : (root.scanning ? "Scanning…" : (root.networkList.length + " networks found"))
			enabledState: root.wifiEnabled
			isScanning: root.scanning
			onBackClicked: root.backRequested()
			onScanClicked: root.rescan()
			onToggleClicked: root.toggleWifi()
		}

		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: 1
			color: Theme.border
		}

		Rectangle {
			Layout.fillWidth: true
			visible: root.errorMessage !== "" && root.promptSsid === "" && root.wifiEnabled
			radius: Theme.roundingElement
			color: Qt.rgba(Qt.color(Theme.critical).r, Qt.color(Theme.critical).g, Qt.color(Theme.critical).b, 0.10)
			border.color: Qt.rgba(Qt.color(Theme.critical).r, Qt.color(Theme.critical).g, Qt.color(Theme.critical).b, 0.40)
			border.width: 1
			implicitHeight: errRow.implicitHeight + 16

			RowLayout {
				id: errRow
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

		SubViewOffPlaceholder {
			visible: !root.wifiEnabled
			icon: "󰖪"
			title: "Wi-Fi is turned off"
			subtitle: "Turn on Wi-Fi to scan and connect to networks"
			buttonText: "Turn On Wi-Fi"
			hintText: "Press [space] to turn on"
			onEnableClicked: root.toggleWifi()
		}

		Item {
			Layout.fillWidth: true
			Layout.fillHeight: true
			visible: root.wifiEnabled

			ListView {
				id: listView
				anchors.fill: parent
				clip: true
				spacing: 6
				model: root.networkList
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
					readonly property bool isConnecting: root.connectingSsid === modelData.name

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
						z: 2

						Text {
							Layout.preferredWidth: 24
							horizontalAlignment: Text.AlignHCenter
							text: root.getSignalIcon(modelData.signalStrength)
							font.family: Theme.fontFamily
							font.pixelSize: 20
							color: isConnected ? Theme.accentBlue : (modelData.signalStrength >= 50 ? Theme.textMain : Theme.textDim)
						}

						ColumnLayout {
							Layout.fillWidth: true
							spacing: 1

							RowLayout {
								Layout.fillWidth: true
								spacing: 6

								Text {
									Layout.fillWidth: true
									text: modelData.name
									font.family: Theme.fontFamily
									font.pixelSize: Theme.fontSizeSmall + 1
									font.bold: isConnected || isSelected
									color: isConnected ? Theme.accentBlue : Theme.textMain
									elide: Text.ElideRight
								}

								Text {
									visible: root.isSecured(modelData.security)
									text: "󰌾"
									font.family: Theme.fontFamily
									font.pixelSize: 13
									color: Theme.textDim
								}
							}

							RowLayout {
								Layout.fillWidth: true
								spacing: 6

								Text {
									text: isConnecting
										? "Connecting…"
										: (isConnected
											? "Connected"
											: (modelData.known ? "Saved" : String(Math.round(modelData.signalStrength)) + "% signal"))
									font.family: Theme.fontMono
									font.pixelSize: Theme.fontSizeSmall - 2
									color: isConnecting ? Theme.warning : (isConnected ? Theme.accentBlue : Theme.textDim)
								}
							}
						}

						RowLayout {
							spacing: 6

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
										root.disconnectNetwork(modelData);
									}
								}
							}

							Rectangle {
								visible: modelData.known || isConnected
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
										root.forgetNetwork(modelData);
									}
								}
							}

							Text {
								visible: !isConnected && !isConnecting
								text: "›"
								font.family: Theme.fontFamily
								font.pixelSize: 18
								color: isSelected ? Theme.accentBlue : Theme.textMuted
							}
						}
					}
				}
			}

			Item {
				anchors.fill: parent
				visible: root.networkList.length === 0 && !root.scanning

				ColumnLayout {
					anchors.centerIn: parent
					spacing: 8

					Text {
						Layout.alignment: Qt.AlignHCenter
						text: "No networks found"
						font.family: Theme.fontFamily
						font.pixelSize: Theme.fontSizeSmall
						color: Theme.textDim
					}

					Text {
						Layout.alignment: Qt.AlignHCenter
						text: "Press [r] to rescan"
						font.family: Theme.fontMono
						font.pixelSize: Theme.fontSizeSmall - 2
						color: Theme.textMuted
					}
				}
			}
		}

		Rectangle {
			id: passwordCard
			Layout.fillWidth: true
			visible: root.promptSsid !== ""
			radius: Theme.roundingElement
			color: Theme.bgMain
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
						text: "Enter password for \"" + root.promptSsid + "\""
						font.family: Theme.fontFamily
						font.pixelSize: Theme.fontSizeSmall
						font.bold: true
						color: Theme.textMain
						elide: Text.ElideRight
					}

					CloseButton {
						size: 22
						onClicked: root.cancelPassword()
					}
				}

				Rectangle {
					Layout.fillWidth: true
					Layout.preferredHeight: 36
					radius: Theme.roundingSubtle
					color: Theme.bgCard
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
							onTextChanged: root.passwordInput = text
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

							Text {
								anchors.centerIn: parent
								text: root.showPassword ? "󰈉" : "󰈈"
								font.family: Theme.fontFamily
								font.pixelSize: 16
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
					visible: root.errorMessage !== "" || (pending.target === root.promptSsid && pending.status !== "")
					Layout.fillWidth: true
					text: root.errorMessage !== "" ? root.errorMessage : (pending.target === root.promptSsid ? pending.status : "")
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeSmall - 2
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
						color: cancelBtnArea.containsMouse ? Theme.bgHover : "transparent"
						border.color: Theme.border
						border.width: 1

						Text {
							id: cancelLabel
							anchors.centerIn: parent
							text: "Cancel (Esc)"
							font.family: Theme.fontFamily
							font.pixelSize: Theme.fontSizeSmall - 1
							color: Theme.textDim
						}

						MouseArea {
							id: cancelBtnArea
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: root.cancelPassword()
						}
					}

					Rectangle {
						implicitWidth: connectLabel.implicitWidth + 20
						implicitHeight: 30
						radius: Theme.roundingSubtle
						opacity: (pending.target === root.promptSsid && pending.status !== "") ? 0.6 : 1.0
						color: connectBtnArea.containsMouse ? Qt.lighter(Theme.accentBlue, 1.15) : Theme.accentBlue

						Text {
							id: connectLabel
							anchors.centerIn: parent
							text: (pending.target === root.promptSsid && pending.status !== "") ? "Connecting…" : "Connect (Enter)"
							font.family: Theme.fontFamily
							font.pixelSize: Theme.fontSizeSmall - 1
							font.bold: true
							color: Theme.bgMain
						}

						MouseArea {
							id: connectBtnArea
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
}
