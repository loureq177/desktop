pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The backlight, in percent: -1 until it is read, and for good on a machine
// without one. The brightness keys come here (hyprland.lua); what else
// changes it calls `refresh` below, as sysfs reports no changes.
Singleton {
	id: root

	property int percent: -1

	// The keys or power-save changed it: the OSD shows the new level.
	signal adjusted()

	function read(): void {
		if (!query.running)
			query.running = true;
	}

	// Writes at once, then once more when a burst of calls (a slider drag, a
	// held key) settles, so the last value is the one that sticks.
	function setPercent(value: real): void {
		if (percent < 0)
			return;
		percent = Math.max(0, Math.min(100, Math.round(value)));
		if (!settle.running)
			write();
		settle.restart();
	}

	function step(delta: int): void {
		if (percent < 0)
			return;
		setPercent(percent + delta);
		adjusted();
	}

	function write(): void {
		writer.command = ["brightnessctl", "-q", "-c", "backlight", "set", percent + "%"];
		writer.running = true;
	}

	Component.onCompleted: read()

	Process {
		id: query

		property bool announce: false

		command: ["brightnessctl", "-c", "backlight", "-m"]
		stdout: StdioCollector {
			// "amdgpu_bl1,backlight,128,50%,255"
			onStreamFinished: {
				var value = parseInt(this.text.split("\n")[0].split(",")[3]);
				if (!isNaN(value))
					root.percent = Math.max(0, Math.min(100, value));
				if (query.announce && root.percent >= 0)
					root.adjusted();
				query.announce = false;
			}
		}
	}

	Process {
		id: writer
	}

	Timer {
		id: settle
		interval: 60
		onTriggered: root.write()
	}

	IpcHandler {
		target: "brightness"

		function up(): void {
			root.step(10);
		}
		function down(): void {
			root.step(-10);
		}
		function refresh(): void {
			query.announce = true;
			root.read();
		}
	}
}
