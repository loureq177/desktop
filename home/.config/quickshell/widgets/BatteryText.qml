import ".."
import QtQuick

// The battery's charge: green on the charger, then warning and critical as it
// runs down. Nothing on a machine without a battery.
StyledText {
	visible: Battery.present
	text: Battery.percent + "%"
	mono: true
	font.bold: true
	color: Battery.charging || Battery.full ? Theme.accentGreen
		: Battery.percent <= 10 ? Theme.critical
		: Battery.percent <= 20 ? Theme.warning
		: Theme.textMain
}
