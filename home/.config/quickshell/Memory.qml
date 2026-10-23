pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Memory in use, from /proc/meminfo every few seconds, in KiB; `percent` is
// -1 until it is read.
Singleton {
	id: root

	property real total: 0
	property real used: 0
	readonly property int percent: total > 0 ? Math.round(used * 100 / total) : -1

	Timer {
		interval: 5000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: meminfo.reload()
	}

	FileView {
		id: meminfo
		path: "/proc/meminfo"
		onLoaded: {
			var text = this.text();
			var field = name => Number((text.match(new RegExp(name + ":\\s+(\\d+)")) || [0, 0])[1]);
			root.total = field("MemTotal");
			root.used = root.total - field("MemAvailable");
		}
	}
}
