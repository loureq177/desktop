import ".."
import "../widgets"
import QtQuick
import QtQuick.Layouts

FadeOverlay {
	id: root

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

	signal searchAccepted()
	signal searchStepped(int delta)
	signal searchSteppedColumn(int delta)
	signal searchCompleted()

	default property alias body: contentSlot.data

	card: dialogCard
	enterScale: 0.82
	exitScale: 0.85

	function open() {
		search.clear();
		root.shown = true;
		search.focusInput();
	}

	function toggle() {
		if (root.shown)
			close();
		else
			open();
	}

	onDismissRequested: root.close()

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
