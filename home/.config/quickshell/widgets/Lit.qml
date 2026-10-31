import ".."
import QtQuick

// What every icon and label does under the pointer, on the bar and in the panels: it lights up.
// A dim one comes up to `towards`, any other a little towards white; the shape stays.
Item {
	id: root

	property bool lit: false
	// The colour it has at rest, to tell whether it has anywhere to come up to.
	property color rest: Theme.textMain
	property color towards: Theme.textMain
	// The bar's glow, for a place with no panel behind it.
	property bool halo: false
	// Lit for a moment: something happened.
	property real flash: 0
	property real level: lit ? 1 : 0
	default property alias content: holder.data

	readonly property bool dim: Qt.colorEqual(rest, Theme.textDim)

	// The glow's room.
	width: holder.childrenRect.width + 4
	height: holder.childrenRect.height + 4

	Behavior on level {
		NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
	}

	Item {
		id: holder
		x: 2
		y: 2
		width: childrenRect.width
		height: childrenRect.height
	}

	layer.enabled: true
	layer.samplerName: "source"
	layer.effect: ShaderEffect {
		property real lift: Math.max(root.level * (root.dim ? 1 : 0.35), root.flash * 0.6)
		property color towards: root.dim ? root.towards : "white"

		fragmentShader: Qt.resolvedUrl("../shaders/lit.frag.qsb")
		layer.enabled: root.halo
		layer.effect: Halo {
			shadowColor: Qt.tint("black", Theme.alpha(Theme.accentBlue, root.flash))
		}
	}
}
