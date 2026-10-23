import "../.."
import "../../widgets"
import "../../widgets/ListNav.js" as ListNav
import QtQuick
import QtQuick.Layouts

// The Capture page of Actions: the capture commands, the same the launcher
// finds by name.
FocusScope {
	id: root

	signal backRequested()

	implicitHeight: 60 + Commands.captureCommands.length * 66

	onVisibleChanged: {
		if (visible)
			list.currentIndex = 0;
	}

	Keys.onPressed: event => {
		if (ListNav.back(event)) {
			root.backRequested();
			event.accepted = true;
		}
	}

	ColumnLayout {
		id: column
		anchors.fill: parent
		spacing: 12

		SubViewHeader {
			Layout.fillWidth: true
			title: "Capture"
			enabledState: true
			showPowerSwitch: false
			showScan: false
			onBackClicked: root.backRequested()
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
			Layout.fillHeight: true
			spacing: 6
			model: Commands.captureCommands
			onActivated: index => Commands.captureCommands[index].run()
			Keys.onSpacePressed: event => {
				event.isAutoRepeat || activate();
			}

			delegate: ListRow {
				id: row

				required property var modelData

				height: content.implicitHeight + 20
				color: modelData.alert ? Theme.alpha(Theme.critical, 0.18) : Theme.glass(Theme.bgMain)
				border.color: modelData.alert ? Theme.critical : Theme.tileBorder
				border.width: 1

				RowLayout {
					id: content
					anchors.fill: parent
					anchors.margins: 10
					spacing: 12

					LineIcon {
						Layout.preferredWidth: 32
						name: row.modelData.icon
						size: 22
						color: row.modelData.alert ? Theme.critical : (row.modelData.tint ?? Theme.accentBlue)
					}

					ColumnLayout {
						Layout.fillWidth: true
						spacing: 2

						StyledText {
							text: row.modelData.name
							font.bold: true
						}

						StyledText {
							Layout.fillWidth: true
							text: row.modelData.desc
							mono: true
							font.pixelSize: Theme.fontSizeTiny
							color: Theme.textDim
							elide: Text.ElideRight
						}
					}
				}
			}
		}
	}
}
