// Polkit authentication dialog: pure hyprlock minimalist style.
// Test with: pkexec true
import ".."
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Item {
	id: root

	property string currentMessage: ""
	property bool responseRequired: false
	property bool responseVisible: false
	property bool failed: false
	property bool submitted: false
	property bool closing: false

	readonly property bool dialogVisible: agent.isActive || closing

	property string displayCommand: ""

	function updateCommandInfo() {
		if (!currentMessage) {
			displayCommand = "Authentication";
			return;
		}
		var m = currentMessage.trim();
		var matchRun = m.match(/to run ['"`]([^'"`]+)['"`]/i);
		if (matchRun) {
			var cmd = matchRun[1].trim();
			var parts = cmd.split(/\s+/);
			var exe = parts[0];
			parts[0] = exe.substring(exe.lastIndexOf('/') + 1);
			displayCommand = parts.join(" ").replace(/\s+--$/, "");
			return;
		}
		var matchSvc = m.match(/to (?:restart|start|stop|reload) ['"`]([^'"`]+)['"`]/i);
		if (matchSvc) {
			displayCommand = "systemctl " + matchSvc[1] + " " + matchSvc[2];
			return;
		}
		if (m.startsWith("Authentication is required to ")) {
			var act = m.slice("Authentication is required to ".length);
			if (act.endsWith("."))
				act = act.slice(0, -1);
			displayCommand = act.charAt(0).toUpperCase() + act.slice(1);
		} else {
			displayCommand = m;
		}
	}

	function syncFromFlow() {
		var flow = agent.flow;
		if (!flow)
			return;
		currentMessage = String(flow.message || "");
		responseRequired = !!flow.isResponseRequired;
		responseVisible = !!flow.responseVisible;
		failed = !!flow.failed;
		if (responseRequired)
			submitted = false;
		updateCommandInfo();
	}

	function beginFlow() {
		closeTimer.stop();
		closing = false;
		submitted = false;
		failed = false;
		passwordInput.text = "";
		cardTrans.x = 0;
		syncFromFlow();
		Qt.callLater(refocus);
	}

	function refocus() {
		if (dialogVisible)
			passwordInput.forceActiveFocus();
	}

	function submitResponse() {
		var flow = agent.flow;
		if (!flow || !flow.isResponseRequired || passwordInput.text.length === 0)
			return;
		submitted = true;
		flow.submit(passwordInput.text);
		passwordInput.text = "";
	}

	function cancelRequest() {
		passwordInput.text = "";
		submitted = false;
		closing = true;
		closeTimer.restart();
		if (agent.flow)
			agent.flow.cancelAuthenticationRequest();
	}

	Timer {
		id: closeTimer
		interval: 160
		repeat: false
		onTriggered: {
			closing = false;
			currentMessage = "";
			displayCommand = "";
			responseRequired = false;
			failed = false;
			submitted = false;
			passwordInput.text = "";
		}
	}

	PolkitAgent {
		id: agent
		path: "/org/quickshell/PolkitAgent"

		onAuthenticationRequestStarted: root.beginFlow()
		onIsActiveChanged: {
			if (isActive) {
				root.syncFromFlow();
			} else if (!root.closing) {
				root.closing = true;
				closeTimer.restart();
			}
		}
	}

	Connections {
		target: agent.flow

		function onIsResponseRequiredChanged() {
			root.syncFromFlow();
			Qt.callLater(root.refocus);
		}
		function onFailedChanged() {
			root.syncFromFlow();
			if (root.failed)
				shakeAnim.restart();
		}
		function onAuthenticationFailed() {
			root.syncFromFlow();
			root.submitted = false;
			passwordInput.text = "";
			shakeAnim.restart();
			Qt.callLater(root.refocus);
		}
		function onAuthenticationSucceeded() {
			root.closing = true;
			closeTimer.restart();
		}
		function onAuthenticationRequestCancelled() {
			root.closing = true;
			closeTimer.restart();
		}
	}

	SequentialAnimation {
		id: shakeAnim

		NumberAnimation { target: cardTrans; property: "x"; to: -14; duration: 40; easing.type: Easing.OutQuad }
		NumberAnimation { target: cardTrans; property: "x"; to: 14; duration: 50; easing.type: Easing.InOutQuad }
		NumberAnimation { target: cardTrans; property: "x"; to: -10; duration: 40; easing.type: Easing.InOutQuad }
		NumberAnimation { target: cardTrans; property: "x"; to: 10; duration: 50; easing.type: Easing.InOutQuad }
		NumberAnimation { target: cardTrans; property: "x"; to: -4; duration: 35; easing.type: Easing.InOutQuad }
		NumberAnimation { target: cardTrans; property: "x"; to: 4; duration: 35; easing.type: Easing.InOutQuad }
		NumberAnimation { target: cardTrans; property: "x"; to: 0; duration: 30; easing.type: Easing.OutQuad }
	}

	PanelWindow {
		id: panel

		visible: root.dialogVisible
		color: "transparent"
		exclusionMode: ExclusionMode.Ignore
		exclusiveZone: 0

		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
		WlrLayershell.namespace: "quickshell-polkit"

		screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

		anchors {
			top: true
			bottom: true
			left: true
			right: true
		}

		// Darkened backdrop matching hyprlock dimming
		Rectangle {
			id: backdrop
			anchors.fill: parent
			color: Theme.backdropColor
			opacity: root.dialogVisible && !root.closing ? 1.0 : 0.0

			Behavior on opacity {
				NumberAnimation { duration: 150 }
			}

			MouseArea {
				anchors.fill: parent
				onClicked: root.refocus()
			}
		}

		Rectangle {
			id: card

			anchors.centerIn: parent
			width: Math.min(460, panel.width - 40)
			implicitHeight: cardLayout.implicitHeight + 48
			color: Qt.rgba(Theme.bgCardColor.r, Theme.bgCardColor.g, Theme.bgCardColor.b, 0.92)
			border.color: root.failed ? Theme.critical : (root.submitted ? Theme.accentGreen : Theme.border)
			border.width: Theme.borderSize
			radius: Theme.roundingWindow
			clip: true

			opacity: root.dialogVisible && !root.closing ? 1.0 : 0.0
			scale: root.dialogVisible && !root.closing ? 1.0 : 0.96

			Behavior on opacity {
				NumberAnimation { duration: 150 }
			}
			Behavior on scale {
				NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
			}
			Behavior on border.color {
				ColorAnimation { duration: 150 }
			}

			transform: Translate {
				id: cardTrans
				x: 0
			}

			ColumnLayout {
				id: cardLayout

				anchors.left: parent.left
				anchors.right: parent.right
				anchors.top: parent.top
				anchors.margins: 24
				spacing: 20

				// 1. Command label: clean, prominent, large mono text (16px)
				RowLayout {
					Layout.fillWidth: true
					spacing: 10

					Text {
						text: ""
						color: root.failed ? Theme.critical : (root.submitted ? Theme.accentGreen : Theme.accentBlue)
						font.family: Theme.fontFamily
						font.pixelSize: 18
						Layout.alignment: Qt.AlignTop

						Behavior on color {
							ColorAnimation { duration: 150 }
						}
					}

					Text {
						Layout.fillWidth: true
						text: root.displayCommand
						color: Theme.textMain
						font.family: Theme.fontMono
						font.pixelSize: 16
						font.bold: true
						wrapMode: Text.WrapAnywhere
						maximumLineCount: 3
						elide: Text.ElideRight
						lineHeight: 1.2
					}
				}

				// 2. Identity picker (only if >1 identity)
				ColumnLayout {
					spacing: 4
					visible: agent.flow && agent.flow.identities.length > 1
					Layout.fillWidth: true

					Repeater {
						model: agent.flow ? agent.flow.identities : []

						delegate: Rectangle {
							required property var modelData
							Layout.fillWidth: true
							implicitHeight: 32
							color: agent.flow && agent.flow.selectedIdentity === modelData ? Theme.selectionBg : "transparent"
							border.color: agent.flow && agent.flow.selectedIdentity === modelData ? Theme.accentBlue : Theme.border
							border.width: 1
							radius: Theme.roundingElement

							Text {
								anchors.centerIn: parent
								text: String(modelData.displayName || "")
								color: Theme.textMain
								font.family: Theme.fontFamily
								font.pixelSize: 15
							}

							MouseArea {
								anchors.fill: parent
								onClicked: agent.flow.selectedIdentity = modelData
							}
						}
					}
				}

				// 3. Hyprlock input field
				Rectangle {
					Layout.fillWidth: true
					implicitHeight: 54
					color: Theme.bgMain
					border.color: root.failed ? Theme.critical : (root.submitted ? Theme.accentGreen : (passwordInput.activeFocus ? Theme.accentBlue : Theme.border))
					border.width: Theme.borderSize
					radius: Theme.roundingWindow

					Behavior on border.color {
						ColorAnimation { duration: 150 }
					}

					TextInput {
						id: passwordInput

						anchors.fill: parent
						anchors.leftMargin: 18
						anchors.rightMargin: 18
						verticalAlignment: TextInput.AlignVCenter
						clip: true
						color: Theme.textMain
						selectionColor: Theme.selectionBg
						selectedTextColor: Theme.textMain
						font.family: Theme.fontMono
						font.pixelSize: 20
						font.letterSpacing: root.responseVisible ? 0 : 4
						echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
						passwordCharacter: "•"
						activeFocusOnPress: true
						enabled: root.dialogVisible && !root.submitted
						onAccepted: root.submitResponse()
						Keys.onPressed: function (event) {
							if (event.key === Qt.Key_Escape) {
								root.cancelRequest();
								event.accepted = true;
							}
						}
					}

					Text {
						anchors.fill: parent
						anchors.leftMargin: 18
						anchors.rightMargin: 18
						verticalAlignment: Text.AlignVCenter
						text: root.failed ? "Wrong password, try again" : (root.submitted ? "Checking…" : "Password…")
						textFormat: Text.PlainText
						color: root.failed ? Theme.critical : (root.submitted ? Theme.accentGreen : Theme.textMuted)
						font.family: Theme.fontFamily
						font.pixelSize: 17
						elide: Text.ElideRight
						visible: passwordInput.text.length === 0

						Behavior on color {
							ColorAnimation { duration: 150 }
						}
					}
				}

				// 4. Subtle footer hints: esc to cancel • enter to submit
				RowLayout {
					Layout.fillWidth: true

					MouseArea {
						Layout.fillWidth: true
						implicitHeight: 28
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: root.cancelRequest()

						Text {
							anchors.left: parent.left
							anchors.verticalCenter: parent.verticalCenter
							text: "esc  cancel"
							color: parent.containsMouse ? Theme.textMain : Theme.textMuted
							font.family: Theme.fontMono
							font.pixelSize: 14
						}
					}

					MouseArea {
						Layout.fillWidth: true
						implicitHeight: 28
						hoverEnabled: true
						enabled: passwordInput.text.length > 0 && !root.submitted
						cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
						onClicked: root.submitResponse()

						Text {
							anchors.right: parent.right
							anchors.verticalCenter: parent.verticalCenter
							text: root.submitted ? "checking…" : "enter  submit ↵"
							color: !parent.enabled ? Theme.textMuted : (parent.containsMouse ? Theme.accentPurple : Theme.accentBlue)
							font.family: Theme.fontMono
							font.pixelSize: 14
							font.bold: parent.enabled
						}
					}
				}
			}
		}
	}
}
