pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The GPU the desktop renders on at its full clock while a panel moves, on battery: an AMD
// iGPU sits at 400-675 MHz there and the slides drop frames; held all the time it costs ~4 W.
// etc/udev/rules.d/70-gpu-boost.rules gives the file to the video group.
Singleton {
	id: root

	// What is moving now, by name.
	property var holders: ({})
	readonly property bool wanted: Battery.onBattery && Object.keys(holders).length > 0
	// The first of AQ_DRM_DEVICES renders (env.lua); alone, the only card.
	readonly property string card: (Quickshell.env("AQ_DRM_DEVICES") || "/dev/dri/card0").split(":")[0].split("/").pop()

	function hold(name: string, on: bool): void {
		if (!!holders[name] === on)
			return;
		var next = Object.assign({}, holders);
		if (on)
			next[name] = true;
		else
			delete next[name];
		holders = next;
	}

	onWantedChanged: level.setText(wanted ? "high" : "auto")

	FileView {
		id: level
		path: "/sys/class/drm/" + root.card + "/device/power_dpm_force_performance_level"
		atomicWrites: false
		printErrors: false
		// A shell gone mid-slide left it high.
		onLoaded: {
			if (!root.wanted && this.text().trim() === "high")
				setText("auto");
		}
	}
}
