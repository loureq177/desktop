import ".."
import "../widgets"
import Quickshell.Services.Polkit
import QtQuick
import QtQuick.Layouts

OverlayWindow {
	id: root

	property string currentMessage: ""
	property bool responseRequired: false
	property bool responseVisible: false
	property bool failed: false
	property bool submitted: false
	property string displayCommand: ""

	property string inputPromptText: ""

	// What PAM says without asking for anything, e.g. pam_fprintd's "place your
	// finger": until that module is done there is no password prompt to answer.
	property string supplementaryText: ""
	property bool supplementaryError: false
	// Enter was pressed before the password was asked for: send it once it is.
	property bool queued: false

	// Escape hides the dialog at once; the agent drops the request a moment later.
	property bool cancelled: false

	shown: agent.isActive && !cancelled
	card: dialogCard
	dismissOnClick: false

	onDismissRequested: cancelRequest()
	onFullyClosed: {
		currentMessage = "";
		displayCommand = "";
		responseRequired = false;
		failed = false;
		submitted = false;
		queued = false;
		inputPromptText = "";
		supplementaryText = "";
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
		inputPromptText = String(flow.inputPrompt || "").replace(/:\s*$/, "");
		supplementaryText = String(flow.supplementaryMessage || "").trim();
		supplementaryError = !!flow.supplementaryIsError;
		// The dots stay while the answer is checked, until something new is asked.
		if (responseRequired && submitted) {
			submitted = false;
			field.text = "";
		}
		updateCommandInfo();
		if (responseRequired && queued) {
			queued = false;
			if (field.text.length > 0)
				submitResponse();
		}
	}

	function beginFlow() {
		cancelled = false;
		submitted = false;
		failed = false;
		queued = false;
		inputPromptText = "";
		supplementaryText = "";
		field.text = "";
		cardTrans.x = 0;
		syncFromFlow();
		Qt.callLater(refocus);
	}

	function refocus() {
		if (shown)
			field.focusInput();
	}

	function submitResponse() {
		if (root.submitted)
			return;
		var flow = agent.flow;
		if (!flow || field.text.length === 0) {
			Qt.callLater(root.refocus);
			return;
		}
		if (!flow.isResponseRequired) {
			queued = true;
			return;
		}
		queued = false;
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
		function onSupplementaryMessageChanged() {
			root.syncFromFlow();
		}
		function onSupplementaryIsErrorChanged() {
			root.syncFromFlow();
		}
		function onFailedChanged() {
			root.syncFromFlow();
			if (root.failed)
				shakeAnim.restart();
		}
		function onAuthenticationFailed() {
			root.syncFromFlow();
			root.submitted = false;
			root.queued = false;
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
		id: dialogCard

		anchors.centerIn: parent
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

			Text {
				Layout.fillWidth: true
				text: root.displayCommand
				color: Theme.textMain
				font.family: Theme.fontMono
				font.pixelSize: Theme.fontSize
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
				focus: true
				fillColor: Theme.glass(Theme.bgMain)
				masked: !root.responseVisible
				readOnly: root.submitted
				busy: root.submitted
				failed: root.failed
				message: root.failed ? "Wrong password, try again" : root.inputPromptText

				onAccepted: root.submitResponse()
				onCancelled: root.cancelRequest()
				onTextChanged: {
					if (text.length > 0 && root.failed)
						root.failed = false;
				}
			}

			Text {
				Layout.fillWidth: true
				Layout.topMargin: -8
				visible: text !== ""
				text: {
					if (root.submitted)
						return "";
					if (root.queued)
						return (root.supplementaryText !== "" ? root.supplementaryText + " — " : "") + "password goes in once it is asked for";
					return root.supplementaryText;
				}
				textFormat: Text.PlainText
				color: root.supplementaryError && !root.queued ? Theme.critical : Theme.textDim
				font.family: Theme.fontFamily
				font.pixelSize: Theme.fontSizeSmall
				wrapMode: Text.Wrap
			}
		}
	}
}
