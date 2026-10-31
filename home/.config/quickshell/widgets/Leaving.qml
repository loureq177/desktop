import ".."
import QtQuick

// What a Repeater shows of `values`: what left them stays a moment, for its way out.
Item {
	property var values: []
	property var shown: []

	visible: false

	onValuesChanged: {
		var gone = shown.filter(v => !values.includes(v));
		shown = gone.concat(values).sort((a, b) => a < b ? -1 : a > b ? 1 : 0);
		prune.restart();
	}

	Timer {
		id: prune
		interval: Theme.animFast + 50
		onTriggered: parent.shown = parent.values
	}
}
