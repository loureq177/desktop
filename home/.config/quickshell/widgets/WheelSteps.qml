import QtQuick

// The wheel over what moves by whole steps (a slider by 5%): a
// notch is one step, and a touchpad one every stepPixels the fingers travel,
// not one for each of the many small events it sends. Clicks and hover pass
// through.
MouseArea {
	id: root

	property int stepPixels: 40
	// +1 for a turn towards the user (down: the next one, less), -1 away.
	signal stepped(int delta)

	property real travel: 0

	anchors.fill: parent
	acceptedButtons: Qt.NoButton

	onWheel: wheel => {
		var px = wheel.pixelDelta.y;
		if (wheel.phase === Qt.NoScrollPhase && px === 0 && wheel.pixelDelta.x === 0) {
			if (wheel.angleDelta.y !== 0)
				root.stepped(wheel.angleDelta.y > 0 ? -1 : 1);
			return;
		}
		if (wheel.phase === Qt.ScrollBegin)
			root.travel = 0;
		root.travel += px;
		while (Math.abs(root.travel) >= root.stepPixels) {
			var away = root.travel > 0;
			root.travel += away ? -root.stepPixels : root.stepPixels;
			root.stepped(away ? -1 : 1);
		}
	}
}
