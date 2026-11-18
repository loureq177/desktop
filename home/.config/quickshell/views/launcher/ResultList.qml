import "../.."
import "../../widgets"
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Rows of the launcher's lists: { label, subtitle, icon, lineIcon, run } and maybe chord,
// changed (the chord in blue), editing (the subtitle in blue), tooltip (said under the list
// for the picked row), thumb (a picture), swatch (a colour), accent, heading, confirm, setting,
// armId, usage (Usage's key); run returning false keeps the launcher. A row of `tiles` (items
// too) shows them side by side: Left and Right pick among them; a tile's thumb fills it.
SelectList {
	id: list

	property var items: []
	property string emptyText: ""
	// The chord of the row being edited, as it is pressed: no new list per key.
	property string editingChord: ""
	// The row asking for a second press, by its armId, and what it says: no new list.
	property string armedId: ""
	property string armedText: ""
	readonly property int headingHeight: 22
	property int tileHeight: 84
	property int tilesPerRow: 6
	// The tile picked in a row of tiles.
	property int tileIndex: 0
	// What the picked row says of itself: a function is asked only for that row.
	readonly property string currentTip: {
		var it = items[currentIndex];
		return !it ? "" : typeof it.tooltip === "function" ? it.tooltip() : (it.tooltip ?? "");
	}
	readonly property int preferredHeight: items.length === 0 ? 72
		: items.reduce((h, it) => h + (it.tiles ? tileHeight : Theme.rowHeight), 0) + items.filter((it, i) => headingAt(i) !== "").length * headingHeight

	// The item picked: the row, or its tile.
	function picked(): var {
		var it = items[currentIndex];
		return it?.tiles ? it.tiles[Math.min(tileIndex, it.tiles.length - 1)] : it;
	}

	function stepTile(delta: int): void {
		var n = items[currentIndex]?.tiles?.length ?? 0;
		if (n > 0)
			tileIndex = Math.max(0, Math.min(n - 1, tileIndex + delta));
	}

	function headingAt(i: int): string {
		var h = items[i]?.heading ?? "";
		return h !== "" && (i === 0 || items[i - 1].heading !== h) ? h : "";
	}

	// The list is made again as a row changes: the row stays selected.
	function keepIndex(change: var): void {
		var index = currentIndex;
		change();
		Qt.callLater(() => currentIndex = Math.min(index, count - 1));
	}

	function reset(): void {
		// The rows stay as they change: scrolled away from the first, nothing else goes up.
		if (currentIndex === 0)
			positionViewAtBeginning();
		currentIndex = 0;
		tileIndex = 0;
		confirm.reset();
	}

	// At the top, at once: the launcher opens on the start of its list.
	function rewind(): void {
		positionViewAtBeginning();
		reset();
	}

	wrap: true
	// Rows stay as the items change, only their count follows: making every row again
	// was most of a keypress.
	model: ListModel {
		id: slots
	}
	onItemsChanged: {
		if (slots.count > items.length)
			slots.remove(items.length, slots.count - items.length);
		else if (slots.count < items.length)
			slots.append(Array.from({ length: items.length - slots.count }, () => ({})));
	}
	Component.onCompleted: itemsChanged()
	onActivated: index => {
		var item = items[index]?.tiles ? picked() : items[index];
		if (item.confirm && !confirm.ask(item.label, list.byPointer))
			return;
		Usage.note(item.usage ?? "");
		if (item.run() !== false)
			Panels.close("launcher");
	}

	Confirm {
		id: confirm
	}

	StyledText {
		visible: list.items.length === 0
		anchors.centerIn: parent
		font.pixelSize: Theme.fontSizeSmall
		color: Theme.textDim
		text: list.emptyText
	}

	delegate: ListRow {
		id: row

		// Blank for a row on its way out.
		readonly property var modelData: list.items[index] ?? ({ label: "" })
		readonly property string heading: list.headingAt(index)
		readonly property bool armed: modelData.confirm !== undefined && confirm.armed === modelData.label
		readonly property bool armedOutside: list.armedId !== "" && modelData.armId === list.armedId
		readonly property color tint: modelData.accent ? Theme.accentGreen
			: armed || armedOutside ? Theme.warning
			: selected ? Theme.textMain : Theme.textDim

		readonly property var tiles: modelData.tiles ?? null
		readonly property real tileWidth: width / list.tilesPerRow

		height: (tiles ? list.tileHeight : Theme.rowHeight) + topInset
		topInset: heading !== "" ? list.headingHeight : 0
		highlightPart: tiles && selected ? tileSpot : null

		// Where the picked tile is, for the highlight to light.
		Item {
			id: tileSpot
			x: Math.min(list.tileIndex, (row.tiles?.length ?? 1) - 1) * row.tileWidth
			y: row.topInset
			width: row.tileWidth
			// Clear of the heading below.
			height: list.tileHeight - 6
		}

		Row {
			visible: row.tiles !== null
			y: row.topInset

			Repeater {
				model: row.tiles ?? []

				delegate: Item {
					id: tile
					required property var modelData
					required property int index
					width: row.tileWidth
					height: list.tileHeight

					HoverSelect {
						onSelected: {
							list.currentIndex = row.index;
							list.tileIndex = tile.index;
						}
					}

					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							list.currentIndex = row.index;
							list.tileIndex = tile.index;
							list.byPointer = true;
							list.activated(row.index);
						}
					}

					// A picture to pick (a wallpaper), with its name under it.
					ClippingRectangle {
						visible: !!tile.modelData.thumb
						x: 8
						y: 8
						width: parent.width - 16
						height: parent.height - 44
						radius: Theme.roundingSubtle
						color: Theme.glass(Theme.bgCard)

						Image {
							anchors.fill: parent
							source: tile.modelData.thumb ?? ""
							sourceSize.width: width * 2
							sourceSize.height: height * 2
							fillMode: Image.PreserveAspectCrop
							asynchronous: true
						}
					}

					IconImage {
						readonly property string name: tile.modelData.icon ?? ""
						visible: name !== ""
						anchors.horizontalCenter: parent.horizontalCenter
						y: 12
						implicitSize: 36
						source: name.startsWith("data:") ? name
							: name.startsWith("icons/") ? "file://" + Quickshell.shellDir + "/" + name
							: name ? Quickshell.iconPath(name, true) : ""
						asynchronous: true
					}

					LineIcon {
						anchors.horizontalCenter: parent.horizontalCenter
						y: 18
						name: tile.modelData.icon ? "" : (tile.modelData.lineIcon ?? "")
						size: 24
						color: Theme.textMain
					}

					StyledText {
						anchors.horizontalCenter: parent.horizontalCenter
						y: tile.modelData.thumb ? parent.height - 32 : 56
						width: parent.width - 12
						horizontalAlignment: Text.AlignHCenter
						font.pixelSize: Theme.fontSizeSmall
						color: tile.modelData.subtitle ? Theme.accentBlue : Theme.textMain
						elide: Text.ElideRight
						textFormat: Text.PlainText
						text: tile.modelData.label + (tile.modelData.subtitle ? "  ·  " + tile.modelData.subtitle : "")
					}
				}
			}
		}

		// The heading's name inside its divider: ── NAME ──────
		RowLayout {
			visible: row.heading !== ""
			width: parent.width
			height: list.headingHeight
			spacing: 8

			Rectangle {
				Layout.preferredWidth: 12
				Layout.preferredHeight: 1
				color: Theme.tileBorder
			}

			StyledText {
				text: row.heading.toUpperCase()
				font.pixelSize: Theme.fontSizeTiny
				font.bold: true
				font.letterSpacing: 1
				color: Theme.textMuted
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 1
				color: Theme.tileBorder
			}
		}

		RowLayout {
			visible: row.tiles === null
			anchors.fill: parent
			anchors.topMargin: row.topInset
			anchors.leftMargin: 12
			anchors.rightMargin: 12
			spacing: 12

			Item {
				Layout.preferredWidth: row.modelData.thumb ? Theme.rowIcon * 16 / 9 : Theme.rowIcon
				Layout.preferredHeight: Theme.rowIcon

				// A picture to pick (a wallpaper), small and decoded small.
				Image {
					visible: !!row.modelData.thumb
					anchors.fill: parent
					source: row.modelData.thumb ?? ""
					sourceSize.width: width * 2
					sourceSize.height: height * 2
					fillMode: Image.PreserveAspectCrop
					asynchronous: true
				}

				Rectangle {
					visible: !!row.modelData.swatch
					anchors.centerIn: parent
					width: 20
					height: 20
					radius: 10
					color: row.modelData.swatch ?? "transparent"
					border.color: Theme.tileBorderHover
					border.width: 1
				}

				IconImage {
					readonly property string name: row.modelData.icon ?? ""
					visible: name !== ""
					anchors.fill: parent
					implicitSize: Theme.rowIcon
					// One the shell brings (icons/, the web apps', or made here as data:), or the theme's.
					source: name.startsWith("data:") ? name
						: name.startsWith("icons/") ? "file://" + Quickshell.shellDir + "/" + name
						: name ? Quickshell.iconPath(name, true) : ""
					asynchronous: true
				}

				LineIcon {
					anchors.centerIn: parent
					name: row.modelData.icon ? "" : (row.modelData.lineIcon ?? "")
					size: 22
					color: row.tint
				}
			}

			StyledText {
				Layout.maximumWidth: row.width * 0.55
				font.bold: row.modelData.accent ?? false
				color: row.modelData.accent ? Theme.accentGreen : Theme.textMain
				elide: Text.ElideRight
				textFormat: Text.PlainText
				text: row.modelData.label
			}

			StyledText {
				Layout.fillWidth: true
				font.pixelSize: Theme.fontSizeSmall
				color: row.armed || row.armedOutside ? Theme.warning : row.modelData.editing ? Theme.accentBlue : Theme.textDim
				elide: Text.ElideRight
				text: row.armedOutside ? list.armedText
					: row.armed && confirm.byPointer ? "Click again to " + row.modelData.confirm
					: row.armed ? "Press " + (row.modelData.chord ? row.modelData.chord + " or " : "") + "Enter again to " + row.modelData.confirm
					: (row.modelData.subtitle ?? "")
			}

			SettingValue {
				visible: row.modelData.setting !== undefined
				setting: row.modelData.setting ?? null
				selected: row.selected
			}

			KeyCaps {
				chord: row.modelData.editing ? list.editingChord : (row.modelData.chord ?? "")
				highlighted: row.selected
				changed: row.modelData.changed ?? false
			}
		}
	}
}
