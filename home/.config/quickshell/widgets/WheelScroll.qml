import ".."
import "Pointer.js" as Pointer
import QtQuick

// Wheel and touchpad scrolling for the Flickable it is declared in, the way
// the rest of the desktop scrolls, and the same in every list of the shell.
// Flickable turns every wheel notch into a short flick, and its touchpad
// scrolling stops dead when the fingers lift, as Wayland sends no momentum to
// carry on with. Here a notch glides a fixed distance, and the touchpad
// moves the list as far as it moves a page in Firefox, then keeps going at
// the speed the fingers left it.
MouseArea {
	id: root

	required property Flickable flickable
	// The wheel scrolls it sideways: the hourly forecast.
	property bool horizontal: false

	// Pixels a notch (a wheel turn of 120) scrolls.
	readonly property int notchStep: 80
	// Pixels a touchpad's pixel moves the list. Firefox (on GTK 3) scrolls 4:
	// GDK divides what Wayland sends by 10, the pan gesture multiplies it by
	// 40 (apz.gtk.pangesture.pixel_delta_mode_multiplier).
	readonly property real fingerGain: 4

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

	// The wheel or the touchpad moves the list, not the keyboard: the rows
	// passing under the resting pointer take the selection (HoverSelect), up
	// to the one it stops under. It lasts a moment longer than the movement,
	// as the hover of a frame comes in the next one.
	property bool byPointer: false
	readonly property bool gliding: glide.running || flickable.moving
	onByPointerChanged: Pointer.setScrolling(byPointer)
	onGlidingChanged: {
		if (!gliding && byPointer)
			settle.restart();
	}

	function position(): real {
		return horizontal ? flickable.contentX : flickable.contentY;
	}

	function setPosition(p: real): void {
		if (horizontal)
			flickable.contentX = p;
		else
			flickable.contentY = p;
	}

	function moveTo(p: real): void {
		setPosition(Math.max(start, Math.min(end, p)));
	}

	function glideTo(p: real, duration: int): void {
		flickable.cancelFlick();
		glide.stop();
		glide.duration = duration;
		glide.to = p;
		glide.start();
	}

	// Brings the row (or cell) `index` of a ListView or GridView into sight, as
	// positionViewAtIndex(index, Contain) does, but gliding there in the time
	// the highlight takes to light it, so the two arrive together. A step made
	// mid-glide counts from where the glide was going. The pointer's picks
	// (Pointer.pick) are in sight already, and leave the list moving as it was.
	function reveal(index: int): void {
		if (Pointer.picking)
			return;
		settle.stop();
		byPointer = false;
		if (!flickable.visible) {
			glide.stop();
			flickable.positionViewAtIndex(index, ListView.Contain);
			return;
		}
		var from = position();
		var aim = glide.running ? glide.to : from;
		glide.stop();
		setPosition(aim);
		flickable.positionViewAtIndex(index, ListView.Contain);
		var to = position();
		setPosition(from);
		if (to !== from)
			glideTo(to, Theme.animFast);
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
		settle.restart();
		byPointer = true;
		// Only the touchpad scrolls in phases; a wheel's notch comes with a
		// pixel delta as well (15 under Hyprland), which is not the one to use.
		var px = wheel.pixelDelta;
		if (wheel.phase !== Qt.NoScrollPhase) {
			glide.stop();
			var now = Date.now();
			if (wheel.phase === Qt.ScrollBegin) {
				flickable.cancelFlick();
				root.samples = [];
			}
			var d = (horizontal && Math.abs(px.x) > Math.abs(px.y) ? px.x : px.y) * root.fingerGain;
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
			glideTo(Math.max(start, Math.min(end, from - notches * root.notchStep)), Theme.animNormal);
		}
		wheel.accepted = true;
	}

	// After the last move: the touchpad's come one by one, with nothing
	// running between them.
	Timer {
		id: settle
		interval: 100
		onTriggered: {
			if (!root.gliding)
				root.byPointer = false;
		}
	}

	NumberAnimation {
		id: glide
		target: root.flickable
		property: root.horizontal ? "contentX" : "contentY"
		easing.type: Easing.OutCubic
	}
}
