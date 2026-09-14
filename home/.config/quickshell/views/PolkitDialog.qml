// Polkit authentication dialog (Quattro-style): theme-aware password prompt
// hosted inside the long-running quickshell process.
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
	property string currentPrompt: ""
	property string currentSupplementary: ""
	property bool supplementaryIsError: false
	property bool responseRequired: false
	property bool responseVisible: false
	property bool failed: false
	property bool submitted: false
	property bool closing: false

	readonly property bool dialogVisible: agent.isActive || closing

	function syncFromFlow() {
		var flow = agent.flow;
		if (!flow)
			return;
		currentMessage = String(flow.message || "Authentication is required");
		currentPrompt = String(flow.inputPrompt || "");
		currentSupplementary = String(flow.supplementaryMessage || "");
		supplementaryIsError = !!flow.supplementaryIsError;
		responseRequired = !!flow.isResponseRequired;
		responseVisible = !!flow.responseVisible;
		failed = !!flow.failed;
		if (responseRequired)
			submitted = false;
	}

	function beginFlow() {
		closeTimer.stop();
		closing = false;
		submitted = false;
		failed = false;
		passwordInput.text = "";
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
		interval: 250
		repeat: false
		onTriggered: {
			closing = false;
			currentMessage = "";
			currentPrompt = "";
			currentSupplementary = "";
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
			if (isActive)
				root.syncFromFlow();
			else if (!root.closing)
				closeTimer.restart();
		}
		onIsRegisteredChanged: {
			if (isRegistered)
				console.log("quickshell polkit agent registered");
			else
				console.warn("quickshell polkit agent not registered; another agent may be running");
		}
	}

	Connections {
		target: agent.flow

		function onIsResponseRequiredChanged() {
			root.syncFromFlow();
			Qt.callLater(root.refocus);
		}
		function onInputPromptChanged() {
			root.syncFromFlow();
		}
		function onResponseVisibleChanged() {
			root.syncFromFlow();
		}
		function onSupplementaryMessageChanged() {
			root.syncFromFlow();
		}
		function onFailedChanged() {
			root.syncFromFlow();
		}
		function onAuthenticationFailed() {
			root.syncFromFlow();
			root.submitted = false;
			passwordInput.text = "";
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

	PanelWindow {
		id: panel

		visible: root.dialogVisible
		color: "transparent"

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

		// Dim scrim; click refocuses the password field.
		Rectangle {
			anchors.fill: parent
			color: "#000000"
			opacity: 0.6

			MouseArea {
				anchors.fill: parent
				onClicked: root.refocus()
			}
		}

		Rectangle {
			id: card

			anchors.centerIn: parent
			width: Math.min(440, panel.width - 40)
			implicitHeight: layout.implicitHeight + Theme.paddingCard * 2
			color: Theme.bgCard
			border.color: root.failed ? Theme.critical : Theme.border
			border.width: Theme.borderSize
			radius: Theme.roundingElement

			ColumnLayout {
				id: layout

				anchors.left: parent.left
				anchors.right: parent.right
				anchors.top: parent.top
				anchors.margins: Theme.paddingCard
				spacing: 10

				RowLayout {
					spacing: 10

					Text {
						text: ""
						color: root.failed ? Theme.critical : Theme.accentBlue
						font.family: Theme.fontFamily
						font.pixelSize: 18
					}
					Text {
						text: "Authentication required"
						color: Theme.textMain
						font.family: Theme.fontFamily
						font.pixelSize: 15
						font.bold: true
						Layout.fillWidth: true
					}
				}

				Text {
					text: root.currentMessage
					textFormat: Text.PlainText
					color: Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSizeSmall
					wrapMode: Text.Wrap
					visible: text.length > 0
					Layout.fillWidth: true
				}

				// Identity picker, only when polkit offers more than one.
				ColumnLayout {
					spacing: 4
					visible: agent.flow && agent.flow.identities.length > 1
					Layout.fillWidth: true

					Repeater {
						model: agent.flow ? agent.flow.identities : []

						delegate: Rectangle {
							required property var modelData
							required property int index

							Layout.fillWidth: true
							implicitHeight: 28
							color: agent.flow && agent.flow.selectedIdentity === modelData ? Theme.selectionBg : "transparent"
							border.color: agent.flow && agent.flow.selectedIdentity === modelData ? Theme.selectionBorder : "transparent"
							border.width: 1
							radius: Theme.roundingElement

							Text {
								anchors.fill: parent
								anchors.leftMargin: 8
								text: String(modelData.displayName || "")
								textFormat: Text.PlainText
								color: Theme.textMain
								font.family: Theme.fontFamily
								font.pixelSize: Theme.fontSizeSmall
								verticalAlignment: Text.AlignVCenter
								elide: Text.ElideRight
							}

							MouseArea {
								anchors.fill: parent
								onClicked: agent.flow.selectedIdentity = modelData
							}
						}
					}
				}

				Rectangle {
					Layout.fillWidth: true
					implicitHeight: 36
					color: Theme.bgMain
					border.color: root.failed ? Theme.critical : (passwordInput.activeFocus ? Theme.accentBlue : Theme.border)
					border.width: 1
					radius: Theme.roundingElement

					TextInput {
						id: passwordInput

						anchors.fill: parent
						anchors.leftMargin: 10
						anchors.rightMargin: 10
						verticalAlignment: TextInput.AlignVCenter
						clip: true
						color: Theme.textMain
						selectionColor: Theme.accent
						selectedTextColor: Theme.textMain
						font.family: Theme.fontFamily
						font.pixelSize: 14
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
						anchors.leftMargin: 10
						anchors.rightMargin: 10
						verticalAlignment: Text.AlignVCenter
						text: root.failed ? "Wrong password, try again" : (root.submitted ? "Checking…" : (root.currentPrompt.length > 0 ? root.currentPrompt : "Password"))
						textFormat: Text.PlainText
						color: root.failed ? Theme.critical : Theme.textMuted
						font.family: Theme.fontFamily
						font.pixelSize: 14
						elide: Text.ElideRight
						visible: passwordInput.text.length === 0
					}
				}

				Text {
					text: root.currentSupplementary
					textFormat: Text.PlainText
					color: (root.supplementaryIsError || root.failed) ? Theme.critical : Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSizeSmall
					wrapMode: Text.Wrap
					visible: text.length > 0
					Layout.fillWidth: true
				}

				RowLayout {
					Layout.fillWidth: true
					spacing: 8

					Item {
						Layout.fillWidth: true
					}

					Rectangle {
						implicitWidth: cancelLabel.implicitWidth + 24
						implicitHeight: 32
						color: cancelArea.containsMouse ? Theme.bgHover : "transparent"
						border.color: Theme.border
						border.width: 1
						radius: Theme.roundingElement

						Text {
							id: cancelLabel
							anchors.centerIn: parent
							text: "Cancel"
							color: Theme.textDim
							font.family: Theme.fontFamily
							font.pixelSize: Theme.fontSizeSmall
						}

						MouseArea {
							id: cancelArea
							anchors.fill: parent
							hoverEnabled: true
							onClicked: root.cancelRequest()
						}
					}

					Rectangle {
						implicitWidth: authLabel.implicitWidth + 24
						implicitHeight: 32
						color: !authEnabled ? Theme.bgHover : (authArea.containsMouse ? Theme.accentPurple : Theme.accentBlue)
						radius: Theme.roundingElement
						opacity: !authEnabled ? 0.5 : 1.0

						property bool authEnabled: passwordInput.text.length > 0 && !root.submitted

						Text {
							id: authLabel
							anchors.centerIn: parent
							text: root.submitted ? "Checking…" : "Authenticate"
							color: Theme.bgMain
							font.family: Theme.fontFamily
							font.pixelSize: Theme.fontSizeSmall
							font.bold: true
						}

						MouseArea {
							id: authArea
							anchors.fill: parent
							hoverEnabled: true
							enabled: parent.authEnabled
							onClicked: root.submitResponse()
						}
					}
				}
			}
		}
	}
}
