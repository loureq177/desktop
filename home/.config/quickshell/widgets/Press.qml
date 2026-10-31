import ".."
import QtQuick

// A press landing: `target` dips and comes back, the same however short the click.
SequentialAnimation {
	id: root

	required property Item target
	property real depth: 0.88

	alwaysRunToEnd: true

	NumberAnimation {
		target: root.target
		property: "scale"
		to: root.depth
		duration: Theme.animFast * 0.6
		easing.type: Easing.OutCubic
	}
	NumberAnimation {
		target: root.target
		property: "scale"
		to: 1
		duration: Theme.animFast
		easing.type: Easing.OutCubic
	}
}
