pragma Singleton
import Quickshell
import Quickshell.Services.UPower
import QtQuick

Singleton {
	id: root

	readonly property var device: UPower.devices.values.find(d => d.isLaptopBattery && d.isPresent) ?? null
	readonly property bool present: device !== null
	readonly property int percent: device ? Math.round(device.percentage * 100) : 0
	readonly property bool full: device?.state === UPowerDeviceState.FullyCharged
	readonly property bool charging: device?.state === UPowerDeviceState.Charging || device?.state === UPowerDeviceState.PendingCharge
	readonly property bool onBattery: UPower.onBattery

	// The lowest level already warned of: a warning comes once as the charge
	// falls past 10% and 5%, and again only after the charger. At 2% UPower
	// takes over (CriticalPowerAction).
	property int warnedAt: 101

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
