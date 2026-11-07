import "../.."
import "../../widgets"
import "."
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

DeviceList {
	id: root

	readonly property var wifiDevice: Net.wifi
	// The network the password form is open for.
	property var promptItem: null
	// Signed in to with a username (WPA-Enterprise): wifi-join, with a certificate from the home.
	readonly property bool enterprise: promptItem?.enterprise === true
	property var certFiles: []
	property int certPick: 0
	property string joinSecret: ""
	readonly property string home: Quickshell.env("HOME")
	// The certificates whose path has every word typed, the shallow ones first.
	readonly property var certMatches: {
		var words = certField.text.trim().toLowerCase().split(/\s+/).filter(w => w !== "");
		return certFiles.filter(f => words.every(w => f.rel.toLowerCase().includes(w))).slice(0, 3);
	}
	// The saved network shown as a QR code, and where wifi-share drew it.
	property var shareItem: null
	readonly property string shareFile: Quickshell.env("XDG_RUNTIME_DIR") + "/wifi-share.svg"

	title: "Wi-Fi"
	subtitle: !radioOn ? "Off" : (scanning ? "Scanning…" : items.length + (items.length === 1 ? " network found" : " networks found"))
	offIcon: "wifi-off"
	radioKey: Qt.Key_W
	radioOn: Networking.wifiEnabled
	prompting: promptItem !== null || shareItem !== null
	shareable: true
	extraHeight: promptItem !== null ? passwordCard.implicitHeight + 12 : shareItem !== null ? shareCard.implicitHeight + 12 : 0
	// Up to three sign-ins, each waiting for its answer.
	pendingTimeout: enterprise ? 120000 : 15000

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
				icon: Net.signalIcon(strength),
				connected: net.connected,
				saved: net.known,
				detail: net.known ? "Saved" : "",
				level: strength > 0 ? Math.round(strength) + "%" : "",
				dim: strength < 50,
				// One password, or none: what a phone's camera can join from.
				share: net.known && [WifiSecurityType.Wpa2Psk, WifiSecurityType.WpaPsk, WifiSecurityType.Sae, WifiSecurityType.Open, WifiSecurityType.Owe].includes(net.security),
				secured: net.security !== WifiSecurityType.Open && net.security !== WifiSecurityType.Unknown,
				enterprise: [WifiSecurityType.Wpa2Eap, WifiSecurityType.WpaEap, WifiSecurityType.Wpa3SuiteB192].includes(net.security),
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

	function connect(item): void {
		if (promptItem && promptItem.key !== item.key)
			closePrompt();
		startPending(item.key, "Connecting…");
		item.net.connect();
	}

	function openShare(item): void {
		closePrompt();
		shareItem = item;
		qrImage.source = "";
		shareRun.command = [Quickshell.env("HOME") + "/.local/bin/wifi-share", item.name, shareFile];
		shareRun.running = true;
		// Its keys reach the page's handler, not the list's Enter.
		shareCard.forceActiveFocus();
	}

	function closeShare(): void {
		if (shareItem === null)
			return;
		shareItem = null;
		qrImage.source = "";
		errorMessage = "";
		// The code holds the password.
		Quickshell.execDetached(["rm", "-f", shareFile]);
		focusList();
	}

	function openPrompt(item): void {
		closeShare();
		clearPending();
		errorMessage = "";
		for (const f of [userField, passField, certField]) {
			f.text = "";
			f.shown = false;
		}
		certPick = 0;
		promptItem = item;
		if (item.enterprise) {
			certFind.running = true;
			userField.input.forceActiveFocus();
		} else {
			passField.input.forceActiveFocus();
		}
	}

	function closePrompt(): void {
		promptItem = null;
		errorMessage = "";
		clearPending();
		for (const f of [userField, passField, certField])
			f.text = "";
		focusList();
	}

	// A script's error as a sentence: its name off the front.
	function said(text: string, script: string): string {
		var t = text.trim().replace(new RegExp("^" + script + ": "), "");
		return t.charAt(0).toUpperCase() + t.slice(1);
	}

	// A path typed as it is (~ for the home), else the match picked under the field.
	function certPath(): string {
		var t = certField.text.trim();
		if (t.startsWith("~/"))
			return home + t.slice(1);
		if (t.startsWith("/"))
			return t;
		return t === "" ? "" : (certMatches[certPick]?.full ?? "");
	}

	function submitPassword(): void {
		if (!promptItem || isPending(promptItem))
			return;
		if (!enterprise) {
			if (passField.text.trim() === "") {
				passField.input.forceActiveFocus();
				return;
			}
			startPending(promptItem.key, "Connecting…");
			promptItem.net.connectWithPsk(passField.text);
			passField.input.forceActiveFocus();
			return;
		}
		var empty = [userField, passField].find(f => f.text.trim() === "");
		if (empty) {
			empty.input.forceActiveFocus();
			return;
		}
		var cert = certPath();
		if (cert === "") {
			errorMessage = "Pick the network's certificate";
			certField.input.forceActiveFocus();
			return;
		}
		startPending(promptItem.key, "Signing in…");
		joinSecret = passField.text;
		joinRun.command = [home + "/.local/bin/wifi-join", promptItem.name, userField.text.trim(), cert];
		joinRun.running = true;
	}

	// Tab and Shift+Tab go round the fields; in the certificate's, Tab takes the match picked.
	function nextField(back: bool): void {
		var fields = enterprise ? [userField, passField, certField] : [passField];
		var at = fields.findIndex(f => f.input.activeFocus);
		if (!back && fields[at] === certField && certMatches.length > 0 && certPath() !== certMatches[certPick].full) {
			certField.text = certMatches[certPick].rel;
			certPick = 0;
			return;
		}
		fields[(at + (back ? fields.length - 1 : 1)) % fields.length].input.forceActiveFocus();
	}

	// The scanner goes round every 10 s while the page is open, and rests after: scans take
	// the radio off the network for a moment.
	onLookingChanged: {
		if (wifiDevice)
			wifiDevice.scannerEnabled = looking;
		if (!looking)
			return;
		scanning = true;
		// Now rather than at the scanner's next round: Quickshell has no call for it.
		Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]);
		scanTimer.restart();
	}
	onRadioToggled: Networking.wifiEnabled = !Networking.wifiEnabled
	Component.onDestruction: {
		if (looking && wifiDevice)
			wifiDevice.scannerEnabled = false;
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
		if (promptItem !== null)
			passField.input.forceActiveFocus();
	}
	onShareRequested: item => openShare(item)
	onPromptKeyPressed: event => {
		if (shareItem !== null) {
			if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_S)
				closeShare();
			event.accepted = true;
			return;
		}
		if (event.key === Qt.Key_Escape) {
			closePrompt();
		} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
			submitPassword();
		} else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
			nextField(event.key === Qt.Key_Backtab);
		} else if ((event.key === Qt.Key_Down || event.key === Qt.Key_Up) && certField.input.activeFocus) {
			certPick = Math.max(0, Math.min(certMatches.length - 1, certPick + (event.key === Qt.Key_Down ? 1 : -1)));
		} else if (event.key !== Qt.Key_J && event.key !== Qt.Key_K && event.key !== Qt.Key_Down && event.key !== Qt.Key_Up) {
			return;
		}
		event.accepted = true;
	}
	onVisibleChanged: {
		if (!visible && promptItem !== null)
			closePrompt();
		if (!visible)
			closeShare();
	}

	// The certificates in the home, found once the form opens.
	Process {
		id: certFind
		command: ["fd", "--type", "f", "-e", "pem", "-e", "crt", "-e", "cer", "-e", "der", "--max-results", "300", ".", root.home]
		stdout: StdioCollector {
			onStreamFinished: {
				var prefix = root.home + "/";
				root.certFiles = this.text.split("\n").filter(l => l !== "").map(full => ({
					full: full,
					rel: "~/" + (full.startsWith(prefix) ? full.slice(prefix.length) : full)
				})).sort((a, b) => a.rel.split("/").length - b.rel.split("/").length || a.rel.localeCompare(b.rel));
			}
		}
	}

	// The password goes on its stdin, never on a command line.
	Process {
		id: joinRun
		stdinEnabled: true
		stderr: StdioCollector {
			id: joinErr
		}
		onStarted: {
			write(root.joinSecret + "\n");
			root.joinSecret = "";
		}
		onExited: code => {
			root.clearPending();
			if (code === 0)
				root.closePrompt();
			else
				root.errorMessage = root.said(joinErr.text, "wifi-join") || "Could not sign in";
		}
	}

	Process {
		id: shareRun
		stderr: StdioCollector {
			id: shareErr
		}
		onExited: code => {
			if (root.shareItem === null)
				return;
			if (code === 0)
				qrImage.source = root.shareFile;
			else
				root.errorMessage = root.said(shareErr.text, "wifi-share") || "Could not make the code";
		}
	}

	FormCard {
		id: shareCard
		visible: root.shareItem !== null
		title: "Share \"" + (root.shareItem?.name ?? "") + "\""
		cancelText: "Close (Esc)"
		onCancelled: root.closeShare()

		Item {
			Layout.fillWidth: true
			implicitHeight: 188
			visible: root.errorMessage === ""

			Rectangle {
				anchors.horizontalCenter: parent.horizontalCenter
				width: 188
				height: 188
				radius: Theme.roundingElement
				// Dark on light: not every camera reads a code the other way round.
				color: "white"

				Image {
					id: qrImage
					anchors.fill: parent
					anchors.margins: 6
					sourceSize: Qt.size(176, 176)
					fillMode: Image.PreserveAspectFit
					smooth: false
					cache: false
				}
			}
		}

		StyledText {
			visible: root.errorMessage === ""
			Layout.alignment: Qt.AlignHCenter
			text: "A phone's camera joins from it"
			font.pixelSize: Theme.fontSizeTiny
			color: Theme.textDim
		}

		StyledText {
			visible: root.errorMessage !== ""
			Layout.fillWidth: true
			text: root.errorMessage
			mono: true
			font.pixelSize: Theme.fontSizeTiny
			color: Theme.critical
		}
	}

	Timer {
		id: scanTimer
		interval: 3000
		onTriggered: root.scanning = false
	}

	FormCard {
		id: passwordCard
		visible: root.promptItem !== null
		title: (root.enterprise ? "Sign in to \"" : "Enter password for \"") + (root.promptItem?.name ?? "") + "\""
		busy: root.isPending(root.promptItem)
		acceptText: busy ? (root.enterprise ? "Signing in…" : "Connecting…") : (root.enterprise ? "Sign in (Enter)" : "Connect (Enter)")
		onAccepted: root.submitPassword()
		onCancelled: root.closePrompt()

		FormField {
			id: userField
			visible: root.enterprise
			placeholder: "Username…"
			onAccepted: root.submitPassword()
		}

		FormField {
			id: passField
			secret: true
			placeholder: root.enterprise ? "Password…" : "Wi-Fi password…"
			onAccepted: root.submitPassword()
		}

		FormField {
			id: certField
			visible: root.enterprise
			placeholder: "The network's certificate: type to find it…"
			onAccepted: root.submitPassword()
			onTextChanged: root.certPick = 0
		}

		// The certificates that match, Up / Down picks, Tab or a click takes one.
		Column {
			Layout.fillWidth: true
			visible: root.enterprise && certField.input.activeFocus
			spacing: 2

			Repeater {
				model: root.certMatches

				delegate: Rectangle {
					required property var modelData
					required property int index
					width: parent.width
					height: 24
					radius: Theme.roundingSubtle
					color: index === root.certPick ? Theme.selectionBg : "transparent"

					StyledText {
						anchors.left: parent.left
						anchors.leftMargin: 8
						anchors.right: parent.right
						anchors.verticalCenter: parent.verticalCenter
						text: modelData.rel
						mono: true
						font.pixelSize: Theme.fontSizeTiny
						color: index === root.certPick ? Theme.textMain : Theme.textDim
						elide: Text.ElideMiddle
					}

					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							certField.text = modelData.rel;
							certField.input.forceActiveFocus();
						}
					}
				}
			}

			StyledText {
				visible: root.certMatches.length === 0
				width: parent.width
				text: root.certFiles.length === 0 ? "No certificate in your home: the network's page has it (.pem, .crt)" : "No certificate matches"
				font.pixelSize: Theme.fontSizeTiny
				color: Theme.textDim
				wrapMode: Text.Wrap
			}
		}

		StyledText {
			visible: root.errorMessage !== "" || passwordCard.busy
			Layout.fillWidth: true
			text: root.errorMessage !== "" ? root.errorMessage : root.pendingStatus
			mono: true
			font.pixelSize: Theme.fontSizeTiny
			color: root.errorMessage !== "" ? Theme.critical : Theme.warning
			wrapMode: Text.Wrap
		}
	}
}
