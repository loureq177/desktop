pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

Singleton {
	id: root

	readonly property var device: UPower.devices.values.find(d => d.isLaptopBattery && d.isPresent) ?? null
	readonly property bool present: device !== null
	readonly property int percent: device ? Math.round(device.percentage * 100) : 0
	// The kernel's word, read here: plugging in a charger can come with no event at all,
	// and UPower then only notices at its next poll, half a minute on.
	property string status: ""
	readonly property bool full: status === "Full"
	readonly property bool charging: status === "Charging"
	readonly property bool onBattery: status === "Discharging"
	readonly property bool critical: !charging && !full && percent < 15
	readonly property bool low: !charging && !full && percent < 30
	// Green on the charger, then warning and critical as it runs down.
	readonly property color color: charging || full ? Theme.accentGreen
		: critical ? Theme.critical
		: low ? Theme.warning
		: Theme.textMain

	// The lowest level warned of: once at 10% and 5%, again after charging; UPower
	// takes over at 2%.
	property int warnedAt: 101

	Timer {
		interval: 5000
		running: root.present
		repeat: true
		triggeredOnStart: true
		onTriggered: statusFile.reload()
	}

	FileView {
		id: statusFile
		path: root.device ? "/sys/class/power_supply/" + root.device.nativePath + "/status" : ""
		printErrors: false
		onLoaded: root.status = this.text().trim()
	}

	onPercentChanged: root.warnLow()
	onOnBatteryChanged: root.warnLow()

	function warnLow(): void {
		if (!root.present || !root.onBattery) {
			root.warnedAt = 101;
			return;
		}
		for (const level of [5, 10]) {
			if (root.percent > level || level >= root.warnedAt)
				continue;
			root.warnedAt = level;
			// Critical at 5%: through do-not-disturb, and it stays.
			var critical = level === 5;
			Quickshell.execDetached(["notify-send", "--app-name", "Battery", "--urgency", critical ? "critical" : "normal",
				"Battery low", root.percent + "% left" + (critical ? ": plug in the charger" : "")]);
			return;
		}
	}
}
