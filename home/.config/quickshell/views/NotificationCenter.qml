// Notification center: slide-in drawer from top-right.
// Displays notification history, live action triggers, DND toggle,
// and individual / bulk dismissal.
// Toggle via IPC: `qs ipc call notifications toggle` (SUPER + CTRL + comma).
// ESC or clicking outside dismisses the panel.
import ".."
import "../widgets"
import Quickshell.Services.Notifications
import QtQml.Models
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

SideDrawer {
	id: win

	shown: Notifications.centerOpen
	cardHeight: Math.min(680, win.height - Theme.notifTopMargin - 20)
	property int currentIndex: 0

	// Incremental visual mirror of history (role: entry). Row ops are
	// incremental, so dismissing one entry never rebuilds the rest —
	// rapid successive dismissals keep every collapse animation alive.
	// Gone rows linger until the sweep drops them after their exit.
	ListModel {
		id: centerModel
	}

	function clampIndex(): void {
		if (win.currentIndex >= centerModel.count)
			win.currentIndex = Math.max(0, centerModel.count - 1);
	}

	function syncCenter(): void {
		var h = Notifications.history;
		var have = {};
		var i;
		for (i = 0; i < centerModel.count; i++)
			have[centerModel.get(i).nid] = true;
		for (i = h.length - 1; i >= 0; i--) {
			if (h[i] && !have[String(h[i].id)])
				centerModel.insert(0, { nid: String(h[i].id), entry: h[i] });
		}
		win.clampIndex();
		var liveIds = {};
		for (i = 0; i < h.length; i++) {
			if (h[i])
				liveIds[String(h[i].id)] = true;
		}
		for (i = 0; i < centerModel.count; i++) {
			if (!liveIds[centerModel.get(i).nid]) {
				sweepTimer.restart();
				return;
			}
		}
	}

	onOpened: {
		QuickSettings.close();
		Weather.close();
		var validHistory = [];
		for (var i = 0; i < Notifications.history.length; i++) {
			var item = Notifications.history[i];
			if (item && (item.summary || item.body || item.appName || item.image))
				validHistory.push(item);
		}
		if (validHistory.length !== Notifications.history.length)
			Notifications.history = validHistory;
		win.syncCenter();
		win.currentIndex = 0;
		centerList.forceActiveFocus();
	}
	onDismissed: Notifications.closeCenter()

	Connections {
		target: Notifications
		function onHistoryChanged() {
			win.syncCenter();
		}
	}

	// Drops exit-animated rows once their collapse finished.
	Timer {
		id: sweepTimer
		interval: 280
		onTriggered: {
			var h = Notifications.history;
			var ids = {};
			for (var i = 0; i < h.length; i++) {
				if (h[i])
					ids[String(h[i].id)] = true;
			}
			for (var k = centerModel.count - 1; k >= 0; k--) {
				if (!ids[centerModel.get(k).nid])
					centerModel.remove(k);
			}
			win.clampIndex();
		}
	}

	ColumnLayout {
		anchors.fill: parent
		spacing: 12

			// ─── Header Bar ─────────────────────────────────────────────
			RowLayout {
				Layout.fillWidth: true
				Layout.preferredHeight: 32
				spacing: 10

				// Title
				Text {
					text: "Notifications"
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSize + 1
					font.bold: true
					color: Theme.textMain
				}

				// Badge
				Rectangle {
					visible: Notifications.history.length > 0
					implicitWidth: countLabel.implicitWidth + 12
					implicitHeight: 20
					radius: height / 2
					color: Theme.selectionBg
					border.color: Theme.selectionBorder
					border.width: 1

					Text {
						id: countLabel
						anchors.centerIn: parent
						text: String(Notifications.history.length)
						font.family: Theme.fontMono
						font.pixelSize: Theme.fontSizeSmall - 1
						font.bold: true
						color: Theme.accentBlue
					}
				}

				// Push Clear All and Close button to the far right corner
				Item {
					Layout.fillWidth: true
				}

				// Clear all button
				Rectangle {
					visible: Notifications.history.length > 0
					implicitWidth: clearRow.implicitWidth + 16
					implicitHeight: 28
					radius: Theme.roundingElement
					color: clearArea.containsMouse ? Theme.bgHover : "transparent"
					border.color: clearArea.containsMouse ? Theme.textDim : Theme.border
					border.width: 1

					Behavior on color { ColorAnimation { duration: 120 } }

					RowLayout {
						id: clearRow
						anchors.centerIn: parent
						spacing: 5

						Text {
							text: "󰎟"
							font.family: Theme.fontFamily
							font.pixelSize: 14
							color: clearArea.containsMouse ? Theme.textMain : Theme.textDim
						}

						Text {
							text: "Clear all"
							font.family: Theme.fontMono
							font.pixelSize: Theme.fontSizeSmall
							color: clearArea.containsMouse ? Theme.textMain : Theme.textDim
						}
					}

					MouseArea {
						id: clearArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: Notifications.clear()
					}
				}

				// Close (✕) button
				CloseButton {
					onClicked: Notifications.closeCenter()
				}
			}

			// Subtle 1px separator
			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 1
				color: Theme.border
			}

			// ─── Notification List ──────────────────────────────────────
			ListView {
				id: centerList
				visible: centerModel.count > 0
				Layout.fillWidth: true
				Layout.fillHeight: true
				clip: true
				boundsBehavior: Flickable.DragAndOvershootBounds
				flickDeceleration: Theme.flickDecel
				maximumFlickVelocity: Theme.maxFlickVel
				spacing: 8
				model: centerModel
				currentIndex: win.currentIndex
				highlightFollowsCurrentItem: true
				highlightMoveDuration: 0
				focus: true

				function rowId(idx): var {
					if (idx < 0 || idx >= centerModel.count)
						return -1;
					var row = centerModel.get(idx);
					return row && row.entry ? row.entry.id : -1;
				}

				Keys.onPressed: event => {
					var count = centerModel.count;
					if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
						if (count > 0) {
							win.currentIndex = Math.min(count - 1, win.currentIndex + 1);
							centerList.positionViewAtIndex(win.currentIndex, ListView.Visible);
						}
						event.accepted = true;
					} else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
						if (count > 0) {
							win.currentIndex = Math.max(0, win.currentIndex - 1);
							centerList.positionViewAtIndex(win.currentIndex, ListView.Visible);
						}
						event.accepted = true;
					} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
						if (!event.isAutoRepeat && count > 0 && win.currentIndex >= 0 && win.currentIndex < count) {
							var actId = centerList.rowId(win.currentIndex);
							if (actId !== -1)
								Notifications.activate(actId);
						}
						event.accepted = true;
					} else if (event.key === Qt.Key_X) {
						if (!event.isAutoRepeat && count > 0 && win.currentIndex >= 0 && win.currentIndex < count) {
							var disId = centerList.rowId(win.currentIndex);
							if (disId !== -1) {
								Notifications.dismissEntry(disId);
								if (win.currentIndex >= count - 1) {
									win.currentIndex = Math.max(0, count - 2);
								}
							}
						}
						event.accepted = true;
					} else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
						Notifications.closeCenter();
						event.accepted = true;
					}
				}

				ScrollBar.vertical: ScrollBar {
					id: vScrollBar
					visible: size < 1.0
					active: size < 1.0
					policy: ScrollBar.AsNeeded
					contentItem: Rectangle {
						implicitWidth: 4
						radius: Theme.roundingSubtle
						color: parent.hovered || parent.pressed ? Theme.textDim : Theme.border
					}
				}

				delegate: Item {
					id: entryWrap
					required property var entry
					required property int index
					// Gone from history (✕, X, SUPER+,, clear): collapse in
					// place; the sweep drops the row after the animation.
					// Derives from the notifying history array, so rapid
					// successive dismissals never rebuild surviving rows.
					readonly property string nid: entry ? String(entry.id) : ""
					readonly property bool gone: {
						var h = Notifications.history;
						for (var i = 0; i < h.length; i++) {
							if (h[i] && String(h[i].id) === entryWrap.nid)
								return false;
						}
						return true;
					}

					width: ListView.view.width
					implicitHeight: gone ? 0 : card.implicitHeight
					clip: true

					Behavior on implicitHeight {
						NumberAnimation {
							duration: 200
							easing.type: Easing.OutCubic
						}
					}

					NotificationCard {
						id: card
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.rightMargin: (centerList.ScrollBar.vertical && centerList.ScrollBar.vertical.visible) ? 10 : 0
						anchors.top: parent.top
						notif: entry
						isSelected: index === win.currentIndex
						isToast: false
						showTime: true

						// Fade in place + top-anchored collapse wipes the card
						// bottom-to-top inside the panel. No sideways slide:
						// entries must not exit like toasts.
						opacity: entryWrap.gone ? 0.0 : 1.0
						Behavior on opacity {
							NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
						}

						onActivated: {
							win.currentIndex = index;
							Notifications.activate(entry.id);
						}
						onDismissed: {
							Notifications.dismissEntry(entry.id);
						}
					}
				}
			}

			// ─── Empty State ────────────────────────────────────────────
			Item {
				visible: centerModel.count === 0
				Layout.fillWidth: true
				Layout.fillHeight: true

				ColumnLayout {
					anchors.centerIn: parent
					spacing: 10

					Text {
						Layout.alignment: Qt.AlignHCenter
						text: "󰂜"
						font.family: Theme.fontFamily
						font.pixelSize: 44
						color: Theme.textMuted
					}

					Text {
						Layout.alignment: Qt.AlignHCenter
						text: "No notifications"
						font.family: Theme.fontFamily
						font.pixelSize: Theme.fontSize
						font.bold: true
						color: Theme.textDim
					}
				}
			}
	}
}
