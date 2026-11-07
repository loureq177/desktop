pragma Singleton
import Quickshell
import Quickshell.Networking
import QtQuick

// The network: Wi-Fi and wired. Not "Network": Quickshell.Networking has a
// type of that name, which hides this one wherever both are imported.
Singleton {
	id: root

	readonly property var wifi: device(DeviceType.Wifi)
	readonly property var wired: device(DeviceType.Wired)
	readonly property bool wifiUp: wifi?.connected ?? false
	readonly property bool wiredUp: wired?.connected ?? false
	readonly property bool online: wifiUp || wiredUp
	readonly property bool wifiOn: Networking.wifiEnabled
	readonly property string icon: wifiUp ? "wifi" : wiredUp ? "ethernet-port" : "wifi-off"
	// The network the Wi-Fi is on, or null.
	readonly property var wifiNetwork: (wifi?.networks?.values ?? []).find(n => n?.connected) ?? null
	readonly property string wifiStatus: !Networking.wifiHardwareEnabled ? "Blocked"
		: !Networking.wifiEnabled ? "Off"
		: wifiNetwork?.name || (wifiUp ? "On" : "No connection")
	// The connected network's signal in percent, or -1 when it is not known.
	readonly property int wifiSignal: Math.round(signalPercent(wifiNetwork)) || -1

	function device(type): var {
		return Networking.devices.values.find(d => d.type === type) ?? null;
	}

	// A network's signal in percent. NetworkManager reports a 0..1 fraction,
	// some backends already a percentage.
	function signalPercent(net): real {
		var s = net?.signalStrength ?? 0;
		return s > 1 ? s : s * 100;
	}

	function signalIcon(strength: real): string {
		return strength >= 75 ? "wifi" : strength >= 50 ? "wifi-high" : strength >= 25 ? "wifi-low" : strength > 0 ? "wifi-zero" : "wifi-off";
	}

	function toggleWifi(): void {
		if (Networking.wifiHardwareEnabled)
			Networking.wifiEnabled = !Networking.wifiEnabled;
	}
}
