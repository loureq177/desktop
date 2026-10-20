import ".."
import QtQuick

// Wheel and touchpad scrolling for the Flickable it is declared in, the way
// the rest of the desktop scrolls, and the same in every list of the shell.
// Flickable turns every wheel notch into a short flick, and its touchpad
// scrolling stops dead when the fingers lift, as Wayland sends no momentum to
// carry on with. Here a notch glides a fixed distance, and the touchpad
// follows the fingers and then keeps going at the speed they left it.
MouseArea {
	id: root

	required property Flickable flickable
	// The wheel scrolls it sideways: the hourly forecast.
	property bool horizontal: false

	// Pixels a notch (a wheel turn of 120) scrolls.
	readonly property int notchStep: 80

	// Over the contents, not inside them (where Flickable puts its children),
	// so it gets the wheel before the rows do. Clicks and hover pass through.
	Component.onCompleted: {
		parent = flickable;
		flickable.boundsBehavior = Flickable.DragAndOvershootBounds;
		flickable.flickDeceleration = 1500;
		flickable.maximumFlickVelocity = 6000;
	}
	anchors.fill: parent
	z: 1
	acceptedButtons: Qt.NoButton

	readonly property real start: horizontal ? flickable.originX : flickable.originY
	readonly property real end: start + Math.max(0, horizontal ? flickable.contentWidth - flickable.width : flickable.contentHeight - flickable.height)

	// The touchpad's last movements, { t, d }, for the speed it leaves at.
	property var samples: []

	function position(): real {
		return horizontal ? flickable.contentX : flickable.contentY;
	}

	function moveTo(p: real): void {
		p = Math.max(start, Math.min(end, p));
		if (horizontal)
			flickable.contentX = p;
		else
			flickable.contentY = p;
	}

	// Pixels a second, from the movements of the last tenth of a second.
	function speed(now: real): real {
		var recent = samples.filter(s => now - s.t < 100);
		if (recent.length === 0)
			return 0;
		var sum = recent.reduce((a, s) => a + s.d, 0);
		return sum / ((now - recent[0].t + 16) / 1000);
	}

	onWheel: wheel => {
		if (end <= start) {
			wheel.accepted = false;
			return;
		}
		var px = wheel.pixelDelta;
		if (wheel.phase !== Qt.NoScrollPhase || px.x !== 0 || px.y !== 0) {
			glide.stop();
			var now = Date.now();
			if (wheel.phase === Qt.ScrollBegin) {
				flickable.cancelFlick();
				root.samples = [];
			}
			var d = horizontal && Math.abs(px.x) > Math.abs(px.y) ? px.x : px.y;
			if (d !== 0) {
				flickable.cancelFlick();
				moveTo(position() - d);
				root.samples = root.samples.filter(s => now - s.t < 100).concat([{ t: now, d: d }]);
			}
			if (wheel.phase === Qt.ScrollEnd) {
				var v = speed(now);
				root.samples = [];
				if (Math.abs(v) > 120)
					horizontal ? flickable.flick(v, 0) : flickable.flick(0, v);
			}
		} else {
			var a = wheel.angleDelta;
			var notches = (horizontal && a.y === 0 ? a.x : a.y) / 120;
			var from = glide.running ? glide.to : position();
			flickable.cancelFlick();
			glide.stop();
			glide.to = Math.max(start, Math.min(end, from - notches * root.notchStep));
			glide.start();
		}
		wheel.accepted = true;
	}

	NumberAnimation {
		id: glide
		target: root.flickable
		property: root.horizontal ? "contentX" : "contentY"
		duration: Theme.animNormal
		easing.type: Easing.OutCubic
	}
}
