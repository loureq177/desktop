import QtQuick

QtObject {
	id: root

	readonly property int timeoutMs: 15000
	property string target: ""
	property string status: ""
	readonly property bool active: target !== "" && status !== ""

	signal timedOut(string expired)

	function start(targetName: string, statusText: string): void {
		target = targetName;
		status = statusText;
		timer.restart();
	}

	function clear(): void {
		timer.stop();
		target = "";
		status = "";
	}

	property Timer timer: Timer {
		interval: root.timeoutMs
		repeat: false
		onTriggered: {
			var expired = root.target;
			root.clear();
			root.timedOut(expired);
		}
	}
}
