import "../.."
import "../../widgets"
import "../../widgets/ListNav.js" as ListNav
import "."
import QtQuick
import QtQuick.Layouts

// The night light's strength: its temperature, stronger as it gets warmer.
FocusScope {
	id: root

	signal backRequested()

	readonly property int weakest: 5500
	readonly property int strongest: 2500
	readonly property real strength: (weakest - Modes.nightLightKelvin) / (weakest - strongest) * 100

	implicitHeight: column.implicitHeight

	function setStrength(percent: real): void {
		var kelvin = weakest - percent / 100 * (weakest - strongest);
		Modes.setNightLightKelvin(Math.max(strongest, Math.min(weakest, Math.round(kelvin / 100) * 100)));
	}

	Keys.onPressed: event => {
		var key = event.key;
		if (key === Qt.Key_H || key === Qt.Key_Left) {
			Modes.setNightLightKelvin(Math.min(weakest, Modes.nightLightKelvin + 100));
		} else if (key === Qt.Key_L || key === Qt.Key_Right) {
			Modes.setNightLightKelvin(Math.max(strongest, Modes.nightLightKelvin - 100));
		} else if (key === Qt.Key_Space || key === Qt.Key_N) {
			event.isAutoRepeat || Modes.toggleNightLight();
		} else if (ListNav.back(event)) {
			root.backRequested();
		} else {
			return;
		}
		event.accepted = true;
	}

	ColumnLayout {
		id: column
		anchors.left: parent.left
		anchors.right: parent.right
		spacing: 12

		SubViewHeader {
			Layout.fillWidth: true
			title: "Night light"
			subtitle: "Turns on at 8 PM"
			enabledState: Modes.nightLight
			toggleKey: "N"
			onBackClicked: root.backRequested()
			onToggleClicked: Modes.toggleNightLight()
		}

		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: 1
			color: Theme.border
		}

		SliderRow {
			current: true
			icon: "moon"
			label: Modes.nightLightKelvin + " K"
			ready: true
			muted: !Modes.nightLight
			value: root.strength
			iconInteractive: true
			onIconClicked: Modes.toggleNightLight()
			onScrubbed: v => root.setStrength(v)
		}
	}
}
