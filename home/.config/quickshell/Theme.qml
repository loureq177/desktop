pragma Singleton
import Quickshell
import QtQuick

Singleton {
	id: theme

	readonly property string bgMain: "#0d1117"
	readonly property string bgCard: "#161b22"
	readonly property string bgHover: "#21262d"
	readonly property string border: "#30363d"
	readonly property string accentBlue: "#58a6ff"
	readonly property string accentPurple: "#bc8cff"
	readonly property string accentGreen: "#3fb950"
	readonly property string warning: "#d29922"
	readonly property string critical: "#f85149"
	readonly property string textMain: "#c9d1d9"
	readonly property string textDim: "#8b949e"
	readonly property string textMuted: "#484f58"
	readonly property string shadow: "#010409"

	readonly property color bgCardColor: bgCard
	readonly property color barStripColor: Qt.rgba(bgCardColor.r, bgCardColor.g, bgCardColor.b, 0.85)
	readonly property color overlayColor: Qt.rgba(bgCardColor.r, bgCardColor.g, bgCardColor.b, 0.94)
	readonly property real backdropDim: 0.2
	readonly property color backdropColor: Qt.rgba(0, 0, 0, backdropDim)

	readonly property int borderSize: 2
	readonly property int roundingWindow: 8
	readonly property int roundingElement: 6
	readonly property int roundingSubtle: 3
	readonly property int paddingCard: 16
	readonly property int paddingItem: 8
	readonly property int windowWidth: 960
	readonly property int windowHeight: 600

	readonly property string fontFamily: "JetBrainsMono Nerd Font Propo"
	readonly property string fontMono: "JetBrainsMono Nerd Font Mono"
	readonly property int fontSize: 17
	readonly property int fontSizeSmall: 14
	readonly property int fontSizeGrid: 13
	readonly property int fontSizeSearch: 15
	readonly property int fontSizeBar: 15
	readonly property int fontSizeBarIcon: 18

	readonly property int barHeight: 30
	readonly property int barMarginX: 20
	readonly property int barMarginY: 4
	readonly property int barSpacing: 8
	readonly property int barPad: 10

	readonly property int notifWidth: 500
	readonly property int notifTopMargin: 54
	readonly property int notifRightMargin: 20
	readonly property int notifPadV: 10
	readonly property int notifPadH: 14

	readonly property color accent: accentBlue
	function alpha(c, a) {
		var q = Qt.color(c);
		return Qt.rgba(q.r, q.g, q.b, a);
	}
	readonly property color selectionBg: Qt.rgba(accent.r, accent.g, accent.b, 0.12)
	readonly property color selectionBorder: Qt.rgba(accent.r, accent.g, accent.b, 0.45)

	readonly property int animFast: 150
	readonly property int animNormal: 250
	readonly property int animSmooth: 280
	readonly property int flickDecel: 1500
	readonly property int maxFlickVel: 6000

	readonly property var myBezier: [ 0.05, 0.9, 0.1, 1.05, 1.0, 1.0 ]
	readonly property var easeOutQuint: [ 0.23, 1.0, 0.32, 1.0, 1.0, 1.0 ]
}
