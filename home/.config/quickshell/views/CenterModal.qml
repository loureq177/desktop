// Shared modal dialog window for centered overlays (Launcher, Keybindings, Clipboard).
// Encapsulates the layer-shell window, monitor tracking, dimmed backdrop,
// centered card container, integrated SearchBar, and footer status bar.
import ".."
import "../widgets"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
	id: root

	property bool shown: false
	property int cardWidth: Theme.windowWidth
	property int cardHeight: Theme.windowHeight

	property string searchTitle: ""
	property string searchPlaceholder: ""
	property bool searchCompleteOnTab: false
	property bool searchLeftRightNavigate: false
	property bool searchScopeHints: false
	property alias searchQuery: search.text
	readonly property alias searchBar: search

	property string statusText: ""
	property string errorText: ""
	property bool showFooter: errorText !== "" || statusText !== ""

	signal opened()
	signal dismissed()
	signal searchAccepted()
	signal searchStepped(int delta)
	signal searchSteppedColumn(int delta)
	signal searchCompleted()

	default property alias body: contentSlot.data

	visible: shown || exitAnim.running

	function open() {
		search.clear();
		root.shown = true;
		search.focusInput();
	}

	function close() {
		root.shown = false;
	}

	function toggle() {
		if (root.shown)
			close();
		else
			open();
	}

	onShownChanged: {
		if (shown) {
			exitAnim.stop();
			enterAnim.restart();
			root.opened();
		} else {
			enterAnim.stop();
			exitAnim.restart();
			root.dismissed();
		}
	}

	ParallelAnimation {
		id: enterAnim

		NumberAnimation {
			target: backdrop
			property: "opacity"
			from: 0.0
			to: 1.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}

		NumberAnimation {
			target: dialogCard
			property: "opacity"
			from: 0.0
			to: 1.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}

		NumberAnimation {
			target: dialogCard
			property: "scale"
			from: 0.82
			to: 1.0
			duration: Theme.animNormal
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
	}

	ParallelAnimation {
		id: exitAnim

		NumberAnimation {
			target: backdrop
			property: "opacity"
			to: 0.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}

		NumberAnimation {
			target: dialogCard
			property: "opacity"
			to: 0.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}

		NumberAnimation {
			target: dialogCard
			property: "scale"
			to: 0.85
			duration: Theme.animFast
			easing.type: Easing.InCubic
		}
	}

	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	exclusiveZone: 0

	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell"

	screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	Shortcut {
		sequences: ["Esc"]
		enabled: root.visible
		onActivated: root.close()
	}

	// Full-screen dim backdrop
	Rectangle {
		id: backdrop
		anchors.fill: parent
		color: Theme.backdropColor

		MouseArea {
			anchors.fill: parent
			enabled: root.shown
			// Dismiss on press, same layer-surface split reason as the
			// SideDrawer/WeatherView backdrops.
			onPressed: root.close()
		}
	}

	// Centered dialog card
	Rectangle {
		id: dialogCard
		anchors.centerIn: parent
		width: root.cardWidth
		height: root.cardHeight
		color: Theme.bgMain
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingWindow
		clip: true

		// Absorb mouse clicks inside the dialog card.
		// Disabled with the dialog so clicks during the exit animation
		// fall through instead of dying on a leaving card.
		MouseArea {
			anchors.fill: parent
			enabled: root.shown
		}

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: Theme.paddingCard
			spacing: 12

			SearchBar {
				id: search
				Layout.fillWidth: true
				Layout.preferredHeight: 48
				title: root.searchTitle
				placeholder: root.searchPlaceholder
				showScopeHints: root.searchScopeHints
				completeOnTab: root.searchCompleteOnTab
				leftRightNavigate: root.searchLeftRightNavigate

				onAccepted: root.searchAccepted()
				onCancelled: root.close()
				onStepped: delta => root.searchStepped(delta)
				onSteppedColumn: delta => root.searchSteppedColumn(delta)
				onCompleted: root.searchCompleted()
			}

			Item {
				id: contentSlot
				Layout.fillWidth: true
				Layout.fillHeight: true
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 1
				color: Theme.border
				visible: root.showFooter
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 36
				visible: root.showFooter
				color: "transparent"

				Text {
					anchors.fill: parent
					verticalAlignment: Text.AlignVCenter
					horizontalAlignment: Text.AlignLeft
					font.family: Theme.fontMono
					font.pointSize: Theme.fontSizeSmall
					color: root.errorText !== "" ? Theme.critical : Theme.textDim
					elide: Text.ElideRight
					text: root.errorText !== "" ? root.errorText : root.statusText
				}
			}
		}
	}
}
