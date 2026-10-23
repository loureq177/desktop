pragma Singleton
import Quickshell
import Quickshell.Services.UPower
import QtQuick

Singleton {
	readonly property var device: UPower.devices.values.find(d => d.isLaptopBattery && d.isPresent) ?? null
	readonly property bool present: device !== null
	readonly property int percent: device ? Math.round(device.percentage * 100) : 0
	readonly property bool full: device?.state === UPowerDeviceState.FullyCharged
	readonly property bool charging: device?.state === UPowerDeviceState.Charging || device?.state === UPowerDeviceState.PendingCharge
	readonly property bool onBattery: UPower.onBattery
	// Seconds, 0 when unknown.
	readonly property real timeToFull: device?.timeToFull ?? 0
	readonly property real timeToEmpty: device?.timeToEmpty ?? 0
}
