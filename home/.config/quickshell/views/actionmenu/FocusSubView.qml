import "../.."
import "../../widgets"
import "../../widgets/ListNav.js" as ListNav
import "."
import QtQuick
import QtQuick.Layouts

// How long Focus stays on: a pick turns it on and goes back.
FocusScope {
	id: root

	signal backRequested()

	// The minute now, for the end times the rows show.
	property double now: Date.now()
	readonly property var choices: [
		{ name: "Until turned off", minutes: 0 },
		{ name: "30 minutes", minutes: 30 },
		{ name: "1 hour", minutes: 60 },
		{ name: "2 hours", minutes: 120 },
		{ name: "Until morning", until: morning(now) }
	]

	// 6:00, when the night light ends.
	function morning(from: double): double {
		var d = new Date(from);
		if (d.getHours() >= 6)
			d.setDate(d.getDate() + 1);
		d.setHours(6, 0, 0, 0);
		return d.getTime();
	}

	function endOf(c): double {
		return c.until ?? (c.minutes > 0 ? now + c.minutes * 60000 : 0);
	}

	function pick(c): void {
		Notifications.focusFor(c.minutes ?? 0, c.until ?? 0);
		root.backRequested();
	}

	implicitHeight: column.implicitHeight
	onVisibleChanged: {
		if (visible) {
			now = Date.now();
			list.currentIndex = 0;
		}
	}

	Timer {
		running: root.visible
		interval: 10000
		repeat: true
		onTriggered: root.now = Date.now()
	}

	Keys.onPressed: event => {
		if (event.key === Qt.Key_Space || event.key === Qt.Key_F) {
			event.isAutoRepeat || (Notifications.dnd = !Notifications.dnd);
		} else if (ListNav.back(event)) {
			root.backRequested();
		} else {
			return;
		}
		event.accepted = true;
	}

	ColumnLayout {
		id: column
		anchors.left: parent.left
		anchors.right: parent.right
		spacing: 12

		SubViewHeader {
			Layout.fillWidth: true
			title: "Focus"
			subtitle: !Notifications.dnd ? "" : Notifications.dndUntil > 0
				? "Until " + Notifications.clockText(Notifications.dndUntil) : "Until turned off"
			enabledState: Notifications.dnd
			toggleKey: "F"
			onBackClicked: root.backRequested()
			onToggleClicked: Notifications.dnd = !Notifications.dnd
		}

		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: 1
			color: Theme.border
		}

		SelectList {
			id: list
			focus: true
			Layout.fillWidth: true
			Layout.preferredHeight: contentHeight
			interactive: false
			scrollBar: false
			slidingHighlight: false
			spacing: 6
			model: root.choices
			onActivated: index => root.pick(root.choices[index])

			delegate: ListRow {
				id: row

				required property var modelData
				readonly property double end: root.endOf(modelData)

				height: 44
				color: Theme.glass(Theme.bgMain)
				border.color: Theme.tileBorder
				border.width: 1

				FadeHighlight {
					selected: row.selected
				}

				RowLayout {
					anchors.fill: parent
					anchors.leftMargin: 12
					anchors.rightMargin: 12
					spacing: 10

					StyledText {
						Layout.fillWidth: true
						text: row.modelData.name
						font.bold: row.selected
						elide: Text.ElideRight
					}

					StyledText {
						visible: row.end > 0
						text: "until " + Notifications.clockText(row.end)
						mono: true
						font.pixelSize: Theme.fontSizeSmall
						color: Theme.textDim
					}
				}
			}
		}
	}
}
