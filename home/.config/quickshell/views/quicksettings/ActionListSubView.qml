import "../.."
import "../../widgets"
import "."
import QtQuick
import QtQuick.Layouts

// A quick settings page that is a list of things to run: capture, power.
// Each action is { title, desc, icon, tint, alert, confirm, run }: `alert`
// draws it in the critical colour, `confirm` runs it only on a second press.
Item {
	id: root

	property string title: ""
	property var actions: []

	signal backRequested()

	property int currentIndex: 0
	property int pendingIndex: -1
	focus: true

	readonly property int preferredHeight: 60 + actions.length * 66

	onVisibleChanged: {
		if (visible) {
			currentIndex = 0;
			pendingIndex = -1;
			root.forceActiveFocus();
		}
	}

	Timer {
		id: confirmTimer
		interval: 4000
		onTriggered: root.pendingIndex = -1
	}

	function activate(index) {
		var item = actions[index];
		if (!item)
			return;
		if (item.confirm && pendingIndex !== index) {
			pendingIndex = index;
			confirmTimer.restart();
			return;
		}
		confirmTimer.stop();
		pendingIndex = -1;
		item.run();
	}

	Keys.onPressed: event => {
		if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
			root.currentIndex = Math.min(root.actions.length - 1, root.currentIndex + 1);
			event.accepted = true;
		} else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
			root.currentIndex = Math.max(0, root.currentIndex - 1);
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
			title: root.title
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
			boundsBehavior: Flickable.DragAndOvershootBounds
			flickDeceleration: Theme.flickDecel
			maximumFlickVelocity: Theme.maxFlickVel

			WheelScroll {
				flickable: actionList
			}

			delegate: Rectangle {
				id: actionRow
				required property var modelData
				required property int index
				readonly property bool isSelected: index === root.currentIndex
				readonly property bool pending: index === root.pendingIndex

				width: ListView.view.width
				implicitHeight: actionCol.implicitHeight + 20
				radius: Theme.roundingElement
				color: modelData.alert ? Theme.alpha(Theme.critical, 0.18) : Theme.inset(Theme.bgMain)
				border.color: modelData.alert ? Theme.critical
					: actionRow.pending ? Theme.warning
					: Theme.tileBorder
				border.width: 1

				Behavior on color { ColorAnimation { duration: 120 } }
				Behavior on border.color { ColorAnimation { duration: 120 } }

				SelectionHighlight {
					selected: actionRow.isSelected
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
						root.currentIndex = index;
						root.activate(index);
					}
				}

				RowLayout {
					id: actionCol
					anchors.fill: parent
					anchors.margins: 10
					spacing: 12
					z: 2

					LineIcon {
						name: modelData.icon
						size: 22
						color: modelData.alert ? Theme.critical : (modelData.tint ?? Theme.accentBlue)
						Layout.preferredWidth: 32
					}

					ColumnLayout {
						Layout.fillWidth: true
						spacing: 2

						Text {
							text: modelData.title
							font.family: Theme.fontFamily
							font.pixelSize: Theme.fontSize
							font.bold: true
							color: Theme.textMain
						}

						Text {
							text: actionRow.pending ? "Press again to " + (modelData.verb ?? "confirm") : modelData.desc
							font.family: Theme.fontMono
							font.pixelSize: Theme.fontSizeSmall - 2
							color: actionRow.pending ? Theme.warning : Theme.textDim
							elide: Text.ElideRight
							Layout.fillWidth: true
						}
					}
				}
			}
		}
	}
}
