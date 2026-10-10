import ".."
import QtQuick

OverlayWindow {
	id: root

	property Item card
	property real enterScale: 0.96
	property real exitScale: 0.97

	Connections {
		target: root
		function onShownChanged() {
			if (!root.shown)
				root.dismissed();
		}
	}

	enterAnimation: ParallelAnimation {
		NumberAnimation {
			target: root
			property: "backdropOpacity"
			from: 0.0
			to: 1.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}
		NumberAnimation {
			target: root.card
			property: "opacity"
			from: 0.0
			to: 1.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}
		NumberAnimation {
			target: root.card
			property: "scale"
			from: root.enterScale
			to: 1.0
			duration: Theme.animNormal
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
	}

	exitAnimation: ParallelAnimation {
		NumberAnimation {
			target: root
			property: "backdropOpacity"
			to: 0.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}
		NumberAnimation {
			target: root.card
			property: "opacity"
			to: 0.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}
		NumberAnimation {
			target: root.card
			property: "scale"
			to: root.exitScale
			duration: Theme.animFast
			easing.type: Easing.InCubic
		}
	}
}
