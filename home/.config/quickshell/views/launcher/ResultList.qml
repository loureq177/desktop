import "../.."
import "../../widgets"
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// The rows of the apps' and the keys' lists. Each item is
//   { label, subtitle, icon, lineIcon, run }
// and maybe `chord` (its keys, as caps), `accent` (the calculator's green),
// `heading` (the section it opens when it differs from the row before) and
// `confirm` (the verb of what runs on a second Enter only). `icon` is a theme
// icon or one of the shell's (icons/); without one the row shows `lineIcon`.
// `run` returning false keeps the launcher open.
SelectList {
	id: list

	property var items: []
	property string emptyText: ""
	readonly property int headingHeight: 34
	readonly property int preferredHeight: items.length === 0 ? 72
		: items.length * Theme.rowHeight + items.filter((it, i) => headingAt(i) !== "").length * headingHeight

	function headingAt(i: int): string {
		var h = items[i]?.heading ?? "";
		return h !== "" && (i === 0 || items[i - 1].heading !== h) ? h : "";
	}

	function reset(): void {
		currentIndex = 0;
		confirm.reset();
	}

	wrap: true
	model: items
	onActivated: index => {
		var item = items[index];
		if (item.confirm && !confirm.ask(item.label))
			return;
		if (item.run() !== false)
			Panels.close("launcher");
	}

	Confirm {
		id: confirm
		interval: 4000
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

		required property var modelData
		readonly property string heading: list.headingAt(index)
		readonly property bool armed: modelData.confirm !== undefined && confirm.armed === modelData.label
		readonly property color tint: modelData.accent ? Theme.accentGreen
			: armed ? Theme.warning
			: selected ? Theme.accentBlue : Theme.textDim

		height: Theme.rowHeight + topInset
		topInset: heading !== "" ? list.headingHeight : 0

		Item {
			visible: row.heading !== ""
			width: parent.width
			height: list.headingHeight

			Rectangle {
				visible: row.index > 0
				anchors.left: parent.left
				anchors.right: parent.right
				anchors.top: parent.top
				anchors.margins: 12
				anchors.topMargin: 6
				height: 1
				color: Theme.tileBorder
			}

			StyledText {
				anchors.left: parent.left
				anchors.bottom: parent.bottom
				anchors.leftMargin: 12
				anchors.bottomMargin: 4
				text: row.heading.toUpperCase()
				font.pixelSize: Theme.fontSizeTiny
				font.bold: true
				font.letterSpacing: 1
				color: Theme.textMuted
			}
		}

		RowLayout {
			anchors.fill: parent
			anchors.topMargin: row.topInset
			anchors.leftMargin: 12
			anchors.rightMargin: 12
			spacing: 12

			Item {
				Layout.preferredWidth: Theme.rowIcon
				Layout.preferredHeight: Theme.rowIcon

				IconImage {
					readonly property string name: row.modelData.icon ?? ""
					visible: name !== ""
					anchors.fill: parent
					implicitSize: Theme.rowIcon
					// One the shell brings (icons/, the web apps'), or the theme's.
					source: name.startsWith("icons/") ? "file://" + Quickshell.shellDir + "/" + name
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
				color: row.armed ? Theme.warning : Theme.textDim
				elide: Text.ElideRight
				text: row.armed ? "Press Enter again to " + row.modelData.confirm : (row.modelData.subtitle ?? "")
			}

			KeyCaps {
				chord: row.modelData.chord ?? ""
				highlighted: row.selected
			}
		}
	}
}
