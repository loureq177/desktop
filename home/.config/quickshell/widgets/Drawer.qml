import ".."
import QtQuick

// A card sliding in from the right under the bar while Panels has `name` open; replaced
// by another, it fades in place. Esc or Q puts it away.
FocusScope {
	id: root

	required property string name
	property int cardWidth: Theme.drawerWidth
	// The body's height; the card stops growing at maxHeight.
	property int contentHeight: maxHeight
	readonly property int maxHeight: Math.min(680, height - Theme.panelTop - 20)
	readonly property bool shown: Panels.active === name
	// 0 off screen, 1 in place.
	property real progress: 0
	property bool handoff: false
	// From the card at rest until it is gone: for what would stutter the slide.
	readonly property bool settled: shown ? progress >= 1 && !anim.running : visible
	default property alias body: bodySlot.data

	// Also when it is opened again on another mode.
	signal opened(string mode)

	// Well past the edge: the exit curve covers its last third in a frame or
	// two, so the card has to be gone before that or it visibly stops short.
	readonly property real offscreen: (cardWidth + Theme.panelMargin) * 1.6
	readonly property real offset: handoff ? 0 : (1 - progress) * offscreen

	anchors.fill: parent
	visible: progress > 0
	enabled: shown

	onShownChanged: {
		anim.stop();
		if (shown) {
			handoff = false;
			forceActiveFocus();
		} else {
			handoff = Panels.active !== "" && parent.drawers.includes(Panels.active);
		}
		anim.to = shown ? 1 : 0;
		anim.duration = handoff ? Theme.animFast : Theme.animNormal;
		anim.easing.type = shown ? Easing.BezierSpline : handoff ? Easing.OutCubic : Easing.InCubic;
		anim.start();
	}

	Connections {
		target: Panels
		function onOpened(name, mode) {
			if (name === root.name)
				root.opened(mode);
		}
	}

	Keys.onPressed: event => {
		if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
			Panels.close(root.name);
			event.accepted = true;
		}
	}

	NumberAnimation {
		id: anim
		target: root
		property: "progress"
		easing.bezierCurve: Theme.easeOutQuint
	}

	Rectangle {
		id: card

		x: parent.width - width - Theme.panelMargin + root.offset
		y: Theme.panelTop
		width: root.cardWidth
		height: Math.min(root.maxHeight, root.contentHeight + Theme.paddingCard * 2)
		opacity: root.handoff ? root.progress : 1
		color: Theme.glass(Theme.bgCard)
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingWindow
		clip: true

		Behavior on height {
			NumberAnimation {
				duration: Theme.animNormal
				easing.type: Easing.BezierSpline
				easing.bezierCurve: Theme.easeOutQuint
			}
		}

		// Clicks on the card stay on it, not on the dim behind.
		MouseArea {
			anchors.fill: parent
			hoverEnabled: true
		}

		// Laid out at the height the card goes to: it reveals the body, never squeezes it.
		Item {
			id: bodySlot
			x: Theme.paddingCard
			y: Theme.paddingCard
			width: card.width - 2 * Theme.paddingCard
			height: Math.min(root.maxHeight, root.contentHeight + Theme.paddingCard * 2) - 2 * Theme.paddingCard
		}
	}
}
