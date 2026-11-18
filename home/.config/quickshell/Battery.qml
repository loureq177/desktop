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
	property string kernelStatus: ""
	// The charger's uevent comes at once; the battery's status ~2.3 s later and UPower's
	// ~3 s (2026-11-18). Until the status moves, the guess the charger's event gives.
	property bool plugChanged: false
	property string guessFrom: ""
	property string guess: ""
	readonly property string status: plugChanged ? guess : kernelStatus
	readonly property bool full: status === "Full"
	readonly property bool charging: status === "Charging"
	readonly property bool onBattery: status === "Discharging"
	readonly property bool critical: !charging && !full && percent < 15
	// Green on the charger, red once it runs short; no yellow step between.
	readonly property color color: charging || full ? Theme.accentGreen
		: critical ? Theme.critical
		: Theme.textMain

	// "2 h 10 min", or "" while UPower does not know yet.
	function duration(seconds: real): string {
		if (!(seconds > 0))
			return "";
		var m = Math.round(seconds / 60), h = Math.floor(m / 60);
		return h > 0 ? h + " h " + (m % 60) + " min" : m + " min";
	}

	// What the battery's tip says: the level, and how long it lasts or takes to fill.
	readonly property string summary: {
		var left = duration(device?.timeToEmpty ?? 0), toFull = duration(device?.timeToFull ?? 0);
		var state = full ? "Full" : charging ? (toFull !== "" ? "Charging, full in " + toFull : "Charging")
			: status === "Not charging" ? "Plugged in, not charging"
			: onBattery && left !== "" ? left + " left" : "";
		return [percent + "%", state].filter(t => t !== "").join("  ·  ");
	}

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

	// Power supply uevents, as they come.
	Process {
		id: uevents
		running: root.present
		command: ["udevadm", "monitor", "--kernel", "--subsystem-match=power_supply"]
		stdout: SplitParser {
			onRead: line => {
				if (!line.includes("/power_supply/"))
					return;
				// The mains adapter (ADP1, AC), as ghostty-effects reads it; USB-C ones waver.
				var charger = line.match(/\/power_supply\/(A[^ \/]*) /);
				if (charger) {
					chargerFile.path = "/sys/class/power_supply/" + charger[1] + "/online";
					chargerFile.reload();
				}
				statusFile.reload();
			}
		}
		onExited: uRestart.start()
	}

	Timer {
		id: uRestart
		interval: 5000
		onTriggered: uevents.running = root.present
	}

	// A charger the battery does not follow: its word after all.
	Timer {
		id: plugSettle
		interval: 10000
		onTriggered: root.plugChanged = false
	}

	FileView {
		id: chargerFile
		printErrors: false
		onLoaded: {
			var guess = this.text().trim() === "1" ? "Charging" : "Discharging";
			if ((root.plugChanged ? root.guess : root.kernelStatus === "Discharging" ? "Discharging" : "Charging") === guess)
				return;
			if (!root.plugChanged)
				root.guessFrom = root.kernelStatus;
			root.guess = guess;
			root.plugChanged = true;
			plugSettle.restart();
		}
	}

	FileView {
		id: statusFile
		path: root.device ? "/sys/class/power_supply/" + root.device.nativePath + "/status" : ""
		printErrors: false
		onLoaded: {
			root.kernelStatus = this.text().trim();
			if (root.plugChanged && root.kernelStatus !== root.guessFrom)
				root.plugChanged = false;
		}
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
