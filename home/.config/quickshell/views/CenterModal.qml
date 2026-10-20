import ".."
import "../widgets"
import QtQuick
import QtQuick.Layouts

OverlayWindow {
	id: root

	// The launcher, emoji and clipboard share one width and top edge, so going
	// from one to the other only changes what is inside. A window that sets
	// contentHeight is as tall as its results, up to the shared height.
	readonly property int cardWidth: Theme.windowWidth
	property int contentHeight: -1
	// Everything around the contents: padding, the field, the lines, the footer.
	readonly property int chromeHeight: Theme.paddingCard * 2 + 48 + 12 - 4 + 1 + 12 + (showFooter ? 12 + 1 + 12 + 36 : 0)
	readonly property int cardHeight: contentHeight < 0 ? Theme.windowHeight : Math.min(Theme.windowHeight, chromeHeight + contentHeight)

	property string searchIcon: "search"
	property string searchPlaceholder: ""
	property bool searchCompleteOnTab: false
	property bool searchLeftRightNavigate: false
	// Which of `scopes` this window shows now.
	property string scope: ""
	property alias searchQuery: search.text
	readonly property alias searchBar: search

	property string statusText: ""
	property string errorText: ""
	property bool showFooter: errorText !== "" || statusText !== ""

	signal searchAccepted()
	signal searchStepped(int delta)
	signal searchSteppedColumn(int delta)
	signal searchCompleted()

	// The lists of the launcher and the clipboard, one family: the empty field
	// offers the other three, and Backspace there goes back to the apps. Calc
	// ("=", "2+2") and run (">") are the apps searched another way, not lists.
	readonly property var scopes: ["apps", "emoji", "clipboard", "keys"]

	// "Search 63 apps...": how long the list is, said where it costs nothing.
	function placeholderFor(count, noun): string {
		return "Search " + (count > 0 ? count + " " : "") + noun + "...";
	}

	function openScope(name): void {
		if (name === "clipboard")
			Panels.open("clipboard");
		else
			Panels.open("launcher", name);
	}

	default property alias body: contentSlot.data

	card: dialogCard
	// Between the centred windows (same width, same top edge) only the
	// contents change: the windows swap in place (OverlayWindow.swapIn/Out).
	handoff: Panels.centered.indexOf(Panels.active) !== -1
	swapOut: true
	swapIn: Panels.centered.indexOf(Panels.previous) !== -1
	// CenterBackdrop dims the screen for all of them.
	backdropColor: "transparent"
	enterScale: 0.82
	exitScale: 0.85

	// A new mode in the same window: the contents fade in again.
	function crossfade(): void {
		contentFade.restart();
	}

	NumberAnimation {
		id: contentFade
		target: contentSlot
		property: "opacity"
		from: 0
		to: 1
		duration: Theme.animFast
		easing.type: Easing.OutCubic
	}

	onOpened: {
		if (root.swapIn)
			root.crossfade();
		search.clear();
		search.focusInput();
	}
	onDismissRequested: Panels.close(root.panel)

	Rectangle {
		id: dialogCard
		anchors.horizontalCenter: parent.horizontalCenter
		y: Math.round((parent.height - Theme.windowHeight) / 2)
		transformOrigin: Item.Top
		width: root.cardWidth
		height: root.cardHeight

		Behavior on height {
			enabled: root.shown && !root.animating
			NumberAnimation {
				duration: Theme.animFast
				easing.type: Easing.OutCubic
			}
		}
		color: Theme.glass(Theme.bgCard)
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingWindow
		clip: true

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
				icon: root.searchIcon
				placeholder: root.searchPlaceholder
				scopes: root.scopes.filter(name => name !== root.scope)
				completeOnTab: root.searchCompleteOnTab
				leftRightNavigate: root.searchLeftRightNavigate

				onAccepted: root.searchAccepted()
				onCancelled: Panels.close(root.panel)
				onStepped: delta => root.searchStepped(delta)
				onSteppedColumn: delta => root.searchSteppedColumn(delta)
				onCompleted: root.searchCompleted()
				onErased: {
					if (root.scope !== "apps")
						root.openScope("apps");
				}
				onScopeChosen: name => root.openScope(name)
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.leftMargin: -Theme.paddingCard
				Layout.rightMargin: -Theme.paddingCard
				Layout.topMargin: -4
				Layout.preferredHeight: 1
				color: Theme.border
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
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSize
					color: root.errorText !== "" ? Theme.critical : Theme.textDim
					elide: Text.ElideRight
					text: root.errorText || root.statusText
				}
			}
		}
	}
}
