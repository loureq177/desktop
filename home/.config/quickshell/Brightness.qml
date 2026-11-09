pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// The backlight in percent, -1 when there is none; sysfs reports no changes, so
// whatever changes it calls refresh().
Singleton {
	id: root

	property int percent: -1

	// The keys changed it: the OSD shows the new level.
	signal adjusted()

	function read(): void {
		if (!query.running)
			query.running = true;
	}

	function setPercent(value: real): void {
		if (percent < 0)
			return;
		percent = Math.max(0, Math.min(100, Math.round(value)));
		write();
	}

	function step(delta: int): void {
		if (percent < 0)
			return;
		setPercent(percent + delta);
		adjusted();
	}

	// What the backlight was last told.
	property int written: -1

	// One brightnessctl at a time: a level set meanwhile (a slider drag, a held key) goes
	// out as it ends, so the last one sticks.
	function write(): void {
		if (writer.running || percent === written)
			return;
		written = percent;
		writer.command = ["brightnessctl", "-q", "-c", "backlight", "set", percent + "%"];
		writer.running = true;
	}

	Component.onCompleted: read()

	Process {
		id: query

		command: ["brightnessctl", "-c", "backlight", "-m"]
		stdout: StdioCollector {
			// "amdgpu_bl1,backlight,128,50%,255"
			onStreamFinished: {
				var value = parseInt(this.text.split("\n")[0].split(",")[3]);
				if (!isNaN(value))
					root.percent = root.written = Math.max(0, Math.min(100, value));
			}
		}
	}

	Process {
		id: writer
		onExited: root.write()
	}

	// What the keys press (binds.lua): no process for a step.
	GlobalShortcut {
		appid: "shell"
		name: "brightness-up"
		onPressed: root.step(10)
	}

	GlobalShortcut {
		appid: "shell"
		name: "brightness-down"
		onPressed: root.step(-10)
	}
}
