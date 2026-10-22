import ".."
import QtQuick

// A card that slides in from the right edge, under the bar (or from the top,
// `fromTop`), while Panels has `name` open. One that leaves because another
// drawer takes its place fades where it is instead of sliding across the
// newcomer. Esc that nothing inside took puts it away.
FocusScope {
	id: root

	required property string name
	property bool fromTop: false
	property int cardWidth: Theme.drawerWidth
	// The body's height; the card stops growing at maxHeight.
	property int contentHeight: maxHeight
	readonly property int maxHeight: Math.min(680, height - Theme.panelTop - 20)
	readonly property bool shown: Panels.active === name
	// 0 off screen, 1 in place.
	property real progress: 0
	property bool handoff: false
	default property alias body: bodySlot.data

	// Also when it is opened again on another mode.
	signal opened(string mode)

	// Well past the edge: the exit curve covers its last third in a frame or
	// two, so the card has to be gone before that or it visibly stops short.
	readonly property real offscreen: fromTop ? card.height + Theme.panelTop + 60 : (cardWidth + Theme.panelMargin) * 1.6
	readonly property real offset: handoff ? 0 : (1 - progress) * offscreen

	anchors.fill: parent
	visible: progress > 0
	enabled: shown

	onShownChanged: {
		anim.stop();
		if (shown) {
			handoff = false;
			forceActiveFocus();
		} else if (Panels.instant) {
			progress = 0;
			return;
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

	Keys.onEscapePressed: Panels.close(root.name)

	NumberAnimation {
		id: anim
		target: root
		property: "progress"
		easing.bezierCurve: Theme.easeOutQuint
	}

	Rectangle {
		id: card

		x: root.fromTop ? Math.round((parent.width - width) / 2) : parent.width - width - Theme.panelMargin + root.offset
		y: root.fromTop ? Theme.panelTop - root.offset : Theme.panelTop
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

		Item {
			id: bodySlot
			anchors.fill: parent
			anchors.margins: Theme.paddingCard
		}
	}
}
