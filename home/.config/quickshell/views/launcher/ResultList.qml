import "../.."
import "../../widgets"
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Rows of the launcher's lists: { label, subtitle, icon, lineIcon, run } and maybe chord,
// changed (the chord in blue), editing (the subtitle in blue), tooltip (said under the list
// for the picked row), thumb (a picture), swatch (a colour), accent, heading, confirm, setting,
// armId, usage (Usage's key); run returning false keeps the launcher.
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
	// What the picked row says of itself: a function is asked only for that row.
	readonly property string currentTip: {
		var it = items[currentIndex];
		return !it ? "" : typeof it.tooltip === "function" ? it.tooltip() : (it.tooltip ?? "");
	}
	readonly property int preferredHeight: items.length === 0 ? 72
		: items.length * Theme.rowHeight + items.filter((it, i) => headingAt(i) !== "").length * headingHeight

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
		var item = items[index];
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

		height: Theme.rowHeight + topInset
		topInset: heading !== "" ? list.headingHeight : 0

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
