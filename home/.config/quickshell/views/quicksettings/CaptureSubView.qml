import "../.."
import "../../widgets"
import "../../widgets/ListNav.js" as ListNav
import "."
import QtQuick
import QtQuick.Layouts

// The Capture page of Quick actions: the capture actions of Actions.qml, the
// same the launcher finds by name.
Item {
	id: root

	readonly property var actions: Actions.captureActions

	signal backRequested()

	property int currentIndex: 0
	focus: true

	readonly property int preferredHeight: 60 + actions.length * 66

	onVisibleChanged: {
		if (visible) {
			currentIndex = 0;
			root.forceActiveFocus();
		}
	}

	function activate(index) {
		actions[index]?.run();
	}

	Keys.onPressed: event => {
		var next = ListNav.step(event, root.actions.length, root.currentIndex);
		if (next !== -1) {
			root.currentIndex = next;
			event.accepted = true;
		} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
			if (!event.isAutoRepeat)
				root.activate(root.currentIndex);
			event.accepted = true;
		} else if (event.key === Qt.Key_Escape || event.key === Qt.Key_H || event.key === Qt.Key_Q || event.key === Qt.Key_Back || event.key === Qt.Key_Backspace) {
			root.backRequested();
			event.accepted = true;
		}
	}

	ColumnLayout {
		anchors.fill: parent
		spacing: 12

		SubViewHeader {
			Layout.fillWidth: true
			title: "Capture"
			subtitle: ""
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

		ListView {
			id: actionList
			Layout.fillWidth: true
			Layout.fillHeight: true
			clip: true
			spacing: 6
			model: root.actions
			currentIndex: root.currentIndex

			WheelScroll {
				flickable: actionList
			}

			delegate: Rectangle {
				id: actionRow
				required property var modelData
				required property int index

				width: ListView.view.width
				implicitHeight: actionCol.implicitHeight + 20
				radius: Theme.roundingElement
				color: modelData.alert ? Theme.alpha(Theme.critical, 0.18) : Theme.glass(Theme.bgMain)
				border.color: modelData.alert ? Theme.critical : Theme.tileBorder
				border.width: 1

				Behavior on color { ColorAnimation { duration: Theme.animFast } }
				Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

				SelectionHighlight {
					selected: actionRow.index === root.currentIndex
				}

				HoverSelect {
					enabled: !actionList.moving
					onSelected: root.currentIndex = actionRow.index
				}

				MouseArea {
					anchors.fill: parent
					cursorShape: Qt.PointingHandCursor
					z: 1
					onClicked: mouse => {
						mouse.accepted = true;
						root.currentIndex = actionRow.index;
						root.activate(actionRow.index);
					}
				}

				RowLayout {
					id: actionCol
					anchors.fill: parent
					anchors.margins: 10
					spacing: 12
					z: 2

					LineIcon {
						name: actionRow.modelData.lineIcon
						size: 22
						color: actionRow.modelData.alert ? Theme.critical : (actionRow.modelData.tint ?? Theme.accentBlue)
						Layout.preferredWidth: 32
					}

					ColumnLayout {
						Layout.fillWidth: true
						spacing: 2

						StyledText {
							text: actionRow.modelData.label
							font.bold: true
						}

						StyledText {
							text: actionRow.modelData.desc
							mono: true
							font.pixelSize: Theme.fontSizeTiny
							color: Theme.textDim
							elide: Text.ElideRight
							Layout.fillWidth: true
						}
					}
				}
			}
		}
	}
}
