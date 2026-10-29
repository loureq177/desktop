import ".."
import "../widgets"
import Quickshell
import QtQuick
import QtQuick.Layouts

// A tray app's menu under its icon; a submenu opens in its place with a way back.
PopupWindow {
	id: root

	// The QsMenuHandle of the app's menu, and the menus opened inside it.
	property var menu: null
	property var trail: []
	readonly property var current: trail.length > 0 ? trail[trail.length - 1] : menu

	function open(item: Item, handle: var): void {
		menu = handle;
		trail = [];
		anchor.item = item;
		visible = true;
	}

	function close(): void {
		visible = false;
	}

	function pick(entry: var): void {
		if (entry.hasChildren) {
			trail = trail.concat([entry]);
			return;
		}
		entry.triggered();
		close();
	}

	// Under the icon, the gap the panels keep from the bar.
	anchor.rect.y: (anchor.item?.height ?? 0) + Theme.barMarginY
	anchor.rect.height: 1
	anchor.edges: Edges.Top
	anchor.gravity: Edges.Bottom
	grabFocus: true
	color: "transparent"
	implicitWidth: card.width
	implicitHeight: card.height

	onVisibleChanged: {
		if (visible)
			fadeIn.restart();
	}

	QsMenuOpener {
		id: opener
		menu: root.current
	}

	Rectangle {
		id: card

		width: Math.max(180, Math.min(320, column.implicitWidth + 12))
		height: column.implicitHeight + 12
		color: Theme.glass(Theme.bgCard)
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingElement + 4
		focus: true

		Keys.onEscapePressed: root.close()

		NumberAnimation {
			id: fadeIn
			target: card
			property: "opacity"
			from: 0
			to: 1
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}

		ColumnLayout {
			id: column
			anchors.fill: parent
			anchors.margins: 6
			spacing: 0

			MenuRow {
				visible: root.trail.length > 0
				icon: "arrow-left"
				text: root.trail[root.trail.length - 1]?.text ?? ""
				onClicked: root.trail = root.trail.slice(0, -1)
			}

			Repeater {
				model: opener.children

				delegate: Loader {
					id: slot
					required property var modelData

					Layout.fillWidth: true
					sourceComponent: modelData.isSeparator ? separator : entryRow

					Component {
						id: separator
						Rectangle {
							implicitHeight: 9
							color: "transparent"
							Rectangle {
								anchors.centerIn: parent
								width: parent.width - 12
								height: 1
								color: Theme.border
							}
						}
					}

					Component {
						id: entryRow
						MenuRow {
							readonly property var entry: slot.modelData
							text: entry.text.replace(/_(?=\S)/, "")
							enabled: entry.enabled
							checked: entry.buttonType !== QsMenuButtonType.None && entry.checkState === Qt.Checked
							checkable: entry.buttonType !== QsMenuButtonType.None
							submenu: entry.hasChildren
							onClicked: root.pick(entry)
						}
					}
				}
			}
		}
	}

	// One line of the menu: a tick or an icon's room before the text, an arrow
	// after it when it opens a menu of its own.
	component MenuRow: Rectangle {
		id: row

		property string text: ""
		property string icon: ""
		property bool checkable: false
		property bool checked: false
		property bool submenu: false
		signal clicked()

		Layout.fillWidth: true
		implicitWidth: line.implicitWidth + 20
		implicitHeight: 30
		radius: Theme.roundingElement
		color: area.containsMouse && enabled ? Theme.selectionBg : "transparent"

		RowLayout {
			id: line
			anchors.fill: parent
			anchors.leftMargin: 8
			anchors.rightMargin: 8
			spacing: 8

			LineIcon {
				visible: row.icon !== "" || row.checkable
				name: row.icon !== "" ? row.icon : row.checked ? "check" : ""
				size: 14
				color: Theme.textMain
				Layout.preferredWidth: 14
			}

			StyledText {
				Layout.fillWidth: true
				text: row.text
				textFormat: Text.PlainText
				elide: Text.ElideRight
				font.pixelSize: Theme.fontSizeSmall
				color: row.enabled ? Theme.textMain : Theme.textDim
			}

			LineIcon {
				visible: row.submenu
				name: "chevron-right"
				size: 14
				color: Theme.textDim
			}
		}

		MouseArea {
			id: area
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: row.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
			onClicked: {
				if (row.enabled)
					row.clicked();
			}
		}
	}
}
