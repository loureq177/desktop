import ".."
import "../widgets"
import Quickshell.Services.Polkit
import QtQuick
import QtQuick.Layouts

ModalWindow {
	id: root

	property string currentMessage: ""
	property bool responseRequired: false
	property bool responseVisible: false
	property bool failed: false
	property bool submitted: false
	property string displayCommand: ""

	// Escape hides the dialog at once; the agent drops the request a moment later.
	property bool cancelled: false

	shown: agent.isActive && !cancelled
	dismissOnClick: false

	onDismissRequested: cancelRequest()
	onVisibleChanged: {
		if (visible)
			return;
		currentMessage = "";
		displayCommand = "";
		responseRequired = false;
		failed = false;
		submitted = false;
		field.text = "";
	}

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
		var matchSvc = m.match(/to (restart|start|stop|reload) ['"`]([^'"`]+)['"`]/i);
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
		// The dots stay while the answer is checked, until something new is asked.
		if (responseRequired && submitted) {
			submitted = false;
			field.text = "";
		}
		updateCommandInfo();
	}

	function beginFlow() {
		cancelled = false;
		submitted = false;
		failed = false;
		field.text = "";
		cardTrans.x = 0;
		syncFromFlow();
		Qt.callLater(refocus);
	}

	function refocus() {
		if (!shown)
			return;
		field.focusInput();
	}

	function submitResponse() {
		if (root.submitted)
			return;
		var flow = agent.flow;
		if (!flow || !flow.isResponseRequired || field.text.length === 0) {
			Qt.callLater(root.refocus);
			return;
		}
		failed = false;
		submitted = true;
		flow.submit(field.text);
	}

	function cancelRequest() {
		if (cancelled)
			return;
		cancelled = true;
		if (agent.flow)
			agent.flow.cancelAuthenticationRequest();
	}

	PolkitAgent {
		id: agent
		path: "/org/quickshell/PolkitAgent"

		onAuthenticationRequestStarted: root.beginFlow()
		onIsActiveChanged: {
			if (isActive)
				root.syncFromFlow();
		}
	}

	Connections {
		target: agent

		function onFlowChanged() {
			root.syncFromFlow();
			Qt.callLater(root.refocus);
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
			field.text = "";
			shakeAnim.restart();
			Qt.callLater(root.refocus);
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

	Rectangle {
		anchors.centerIn: parent
		scale: 0.96 + 0.04 * root.progress
		width: Math.min(460, root.width - 40)
		implicitHeight: cardLayout.implicitHeight + 48
		color: Theme.glass(Theme.bgCard)
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingWindow

		transform: Translate {
			id: cardTrans
		}

		ColumnLayout {
			id: cardLayout

			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: parent.top
			anchors.margins: 24
			spacing: 20

			StyledText {
				Layout.fillWidth: true
				text: root.displayCommand
				mono: true
				font.bold: true
				wrapMode: Text.WrapAnywhere
				maximumLineCount: 3
				elide: Text.ElideRight
				lineHeight: 1.2
			}

			PasswordField {
				id: field

				Layout.fillWidth: true
				Layout.preferredHeight: 46
				visible: root.responseRequired || root.submitted
				focus: true
				fillColor: Theme.glass(Theme.bgMain)
				masked: !root.responseVisible
				readOnly: root.submitted
				busy: root.submitted
				failed: root.failed
				message: root.failed ? "Wrong password, try again" : ""

				onAccepted: root.submitResponse()
				onCancelled: root.cancelRequest()
				onTextChanged: {
					if (text.length > 0 && root.failed)
						root.failed = false;
				}
			}
		}
	}
}
