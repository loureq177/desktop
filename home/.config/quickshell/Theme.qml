pragma Singleton
import Quickshell
import QtQuick
import "ui.js" as Ui

// The colours and what the shell shares with the rest of the desktop come
// from ~/.config/ui/ui.toml (through ui.js, which apply-ui writes). The rest
// belongs to the shell alone and is set here.
Singleton {
	id: theme

	readonly property var ui: Ui.config

	readonly property string bgMain: ui.colors.bg_main
	readonly property string bgCard: ui.colors.bg_card
	readonly property string bgHover: ui.colors.bg_hover
	readonly property string border: ui.colors.border
	readonly property string accentBlue: ui.colors.accent_blue
	readonly property string accentPurple: ui.colors.accent_purple
	readonly property string accentGreen: ui.colors.accent_green
	readonly property string warning: ui.colors.warning
	readonly property string critical: ui.colors.critical
	readonly property string textMain: ui.colors.text_main
	readonly property string textDim: ui.colors.text_dim
	readonly property string textMuted: ui.colors.text_muted

	readonly property color backdropColor: Qt.rgba(0, 0, 0, ui.opacity.dim_special)

	// Lock screen backdrop: blurred screenshot, darkened and slightly saturated.
	readonly property int lockBlurMax: 64
	readonly property real lockBrightness: ui.lock.brightness
	readonly property real lockVibrancy: ui.lock.vibrancy
	readonly property int lockFadeIn: 450
	readonly property int lockFadeOut: 300
	readonly property int lockDotsFade: 400
	readonly property int wallpaperGrow: 900
	readonly property int wallpaperFeather: 120

	readonly property int borderSize: ui.border.size
	readonly property int roundingWindow: ui.rounding.window
	readonly property int roundingElement: 6
	readonly property int roundingSubtle: 3
	readonly property int paddingCard: 16
	readonly property int paddingItem: 8
	// The launcher, clipboard and other centred windows.
	readonly property int windowWidth: 960
	readonly property int windowHeight: 600
	// A row of their lists, and the icon at its start.
	readonly property int rowHeight: 56
	readonly property int rowIcon: 32

	readonly property string fontFamily: ui.font.family
	readonly property string fontMono: ui.font.mono
	// Pixels, like every font size in the shell.
	readonly property int fontSize: 17
	readonly property int fontSizeSmall: 14
	readonly property int fontSizeGrid: 13
	// Search fields and the rows of the centred windows.
	readonly property int fontSizeLarge: 20
	readonly property int fontSizeBar: 15
	readonly property int fontSizeBarIcon: 18

	// Bar geometry: a single translucent strip with hover-highlighted modules.
	readonly property int barHeight: 30
	readonly property int barMarginX: 20
	readonly property int barMarginY: 4

	// Notification surfaces: top-right panel below the bar.
	readonly property int notifWidth: 500
	readonly property int notifTopMargin: 54
	readonly property int notifRightMargin: ui.spacing.gaps_out
	readonly property int notifPadV: 10
	readonly property int notifPadH: 14

	readonly property color accent: accentBlue
	function alpha(c, a) {
		var q = Qt.color(c);
		return Qt.rgba(q.r, q.g, q.b, a);
	}
	readonly property color selectionBg: alpha(accent, 0.2)
	readonly property color selectionBorder: alpha(accent, 0.32)

	// Hairlines around tiles, rows and buttons: a tint of the text colour, so
	// they sit on frosted glass and on solid panels alike.
	readonly property color tileBorder: alpha(textMain, 0.08)
	readonly property color tileBorderHover: alpha(textMain, 0.18)

	// Panels turn to frosted glass exactly when ghostty does (power-save's
	// ghostty_perf); Hyprland blurs whatever lies underneath them. Tiles are
	// denser than the panel so they still read as separate without frames.
	function panel(c) {
		return alpha(c, SystemStatus.glass ? 0.68 : 1);
	}
	// Tiles and fields lying on a panel.
	function inset(c) {
		return alpha(c, SystemStatus.glass ? 0.7 : 1);
	}

	// Animation durations & physics matching Hyprland curves.
	readonly property int animFast: 150
	readonly property int animNormal: 250
	readonly property int animSmooth: 280
	readonly property int flickDecel: 1500
	readonly property int maxFlickVel: 6000
	// Pixels a wheel turn of 120 (one notch, before input:scroll_factor) scrolls.
	readonly property int wheelStep: 160

	// Cubic bezier control points matching Hyprland:
	// easeOutQuint = { { 0.23, 1 }, { 0.32, 1 } }
	readonly property var easeOutQuint: [ 0.23, 1.0, 0.32, 1.0, 1.0, 1.0 ]
}
