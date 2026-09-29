// Notification center: slide-in drawer from top-right.
// Displays notification history, live action triggers, DND toggle,
// and individual / bulk dismissal.
// Toggle via IPC: `qs ipc call notifications toggle` (SUPER + CTRL + comma).
// ESC or clicking outside dismisses the panel.
import ".."
import "../widgets"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

SideDrawer {
	id: win

	shown: Notifications.centerOpen
	cardHeight: Math.min(680, win.height - Theme.notifTopMargin - 20)
	onOpened: QuickSettings.close()
	onDismissed: Notifications.closeCenter()

	ColumnLayout {
		anchors.fill: parent
		spacing: 12

			// ─── Header Bar ─────────────────────────────────────────────
			RowLayout {
				Layout.fillWidth: true
				Layout.preferredHeight: 32
				spacing: 10

				// Title + badge
				RowLayout {
					Layout.fillWidth: true
					spacing: 8

					Text {
						text: "Notifications"
						font.family: Theme.fontFamily
						font.pixelSize: Theme.fontSize + 1
						font.bold: true
						color: Theme.textMain
					}

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
				}

				// DND toggle pill
				Rectangle {
					implicitWidth: dndRow.implicitWidth + 16
					implicitHeight: 28
					radius: Theme.roundingElement
					color: dndArea.containsMouse ? Theme.bgHover : (Notifications.dnd ? Theme.selectionBg : "transparent")
					border.color: Notifications.dnd ? Theme.warning : Theme.border
					border.width: 1

					Behavior on color { ColorAnimation { duration: 120 } }
					Behavior on border.color { ColorAnimation { duration: 120 } }

					RowLayout {
						id: dndRow
						anchors.centerIn: parent
						spacing: 6

						Text {
							text: Notifications.dnd ? "󰂛" : "󰂜"
							font.family: Theme.fontFamily
							font.pixelSize: 14
							font.bold: true
							color: Notifications.dnd ? Theme.warning : Theme.textDim
						}

						Text {
							text: "DND"
							font.family: Theme.fontMono
							font.pixelSize: Theme.fontSizeSmall
							font.bold: Notifications.dnd
							color: Notifications.dnd ? Theme.warning : Theme.textDim
						}
					}

					MouseArea {
						id: dndArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: Notifications.toggleDnd()
					}
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
				Rectangle {
					implicitWidth: 28
					implicitHeight: 28
					radius: Theme.roundingElement
					color: closeCenterArea.containsMouse ? Theme.bgHover : "transparent"
					border.color: closeCenterArea.containsMouse ? Theme.textDim : Theme.border
					border.width: 1

					Behavior on color { ColorAnimation { duration: 120 } }

					Text {
						anchors.centerIn: parent
						text: "✕"
						font.pixelSize: 13
						color: closeCenterArea.containsMouse ? Theme.critical : Theme.textDim
					}

					MouseArea {
						id: closeCenterArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: Notifications.closeCenter()
					}
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
				visible: Notifications.history.length > 0
				Layout.fillWidth: true
				Layout.fillHeight: true
				clip: true
				spacing: 8
				model: Notifications.history

				ScrollBar.vertical: ScrollBar {
					active: true
					policy: ScrollBar.AsNeeded
					contentItem: Rectangle {
						implicitWidth: 4
						radius: Theme.roundingSubtle
						color: parent.hovered ? Theme.textDim : Theme.border
					}
				}

				delegate: Item {
					id: entryWrap
					required property var modelData
					property var snap: modelData
					property bool critical: snap.urgency === NotificationUrgency.Critical
					property bool dismissing: false
					readonly property var live: Notifications.liveById(snap.id)
					readonly property bool invitingLive: Notifications.isLive(snap.id)
					// Buttons come from the snapshot, not the live object: the
					// live notification dies when its toast expires, which used
					// to leave center cards without any action buttons. A click
					// on a dead notification is a safe no-op in the singleton.
					readonly property var actionEntries: Notifications.historyActionEntries(snap)
					readonly property bool canReply: entryWrap.live !== null && entryWrap.live.hasInlineReply

					width: ListView.view.width
					implicitHeight: dismissing ? 0 : cardBox.implicitHeight
					clip: true

					Behavior on implicitHeight {
						NumberAnimation {
							duration: 200
							easing.type: Easing.OutCubic
							onRunningChanged: {
								if (!running && entryWrap.dismissing) {
									Notifications.dismissEntry(entryWrap.snap.id);
								}
							}
						}
					}

					Rectangle {
						id: cardBox
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.top: parent.top
						implicitHeight: Math.max(centerBody.implicitHeight + Theme.notifPadV * 2, centerPic.size + Theme.notifPadV * 2)
						color: rowArea.containsMouse ? Theme.bgHover : Theme.bgMain
						border.color: entryWrap.critical ? Theme.critical : (rowArea.containsMouse ? Theme.textDim : Theme.border)
						border.width: 1
						radius: Theme.roundingElement
						clip: true

						opacity: entryWrap.dismissing ? 0.0 : 1.0
						transform: Translate {
							x: entryWrap.dismissing ? 60 : 0
							Behavior on x {
								NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
							}
						}

						Behavior on opacity {
							NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
						}
						Behavior on color {
							ColorAnimation { duration: 120 }
						}
						Behavior on border.color {
							ColorAnimation { duration: 120 }
						}

						// Clicking the card body invokes the default action.
						MouseArea {
							id: rowArea
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: Notifications.activate(entryWrap.snap.id)
						}

						// Critical urgency indicator strip on left
						Rectangle {
							visible: entryWrap.critical
							anchors.top: parent.top
							anchors.bottom: parent.bottom
							anchors.left: parent.left
							width: 3
							color: Theme.critical
							radius: Theme.roundingSubtle
							z: 3
						}

						// Fixed-size picture on the left, vertically centered
						NotificationPicture {
							id: centerPic
							anchors.left: parent.left
							anchors.leftMargin: (entryWrap.critical ? 3 : 0) + Theme.notifPadH
							anchors.verticalCenter: parent.verticalCenter
							size: 64
							image: entryWrap.snap.image || ""
							appIcon: entryWrap.snap.appIcon || ""
							appName: entryWrap.snap.appName || ""
							z: 1
						}

						ColumnLayout {
							id: centerBody
							anchors.left: centerPic.right
							anchors.leftMargin: 12
							anchors.right: parent.right
							anchors.rightMargin: Theme.notifPadH
							anchors.verticalCenter: parent.verticalCenter
							spacing: 3
							z: 2

								RowLayout {
									Layout.fillWidth: true
									spacing: 8

									Text {
										Layout.fillWidth: true
										text: entryWrap.snap.appName || "Notification"
										font.family: Theme.fontMono
										font.pointSize: Theme.fontSizeSmall
										font.bold: true
										color: entryWrap.critical ? Theme.critical : Theme.accentBlue
										elide: Text.ElideRight
									}

									Text {
										text: Qt.formatDateTime(new Date(entryWrap.snap.time), "hh:mm")
										font.family: Theme.fontMono
										font.pointSize: Theme.fontSizeSmall - 1
										color: Theme.textMuted
									}

									// Per-card close button
									Rectangle {
										implicitWidth: 20
										implicitHeight: 20
										radius: Theme.roundingElement
										color: closeItemArea.containsMouse ? Theme.bgCard : "transparent"

										Text {
											anchors.centerIn: parent
											text: "✕"
											font.pixelSize: 11
											color: closeItemArea.containsMouse ? Theme.critical : Theme.textMuted
										}

										MouseArea {
											id: closeItemArea
											anchors.fill: parent
											hoverEnabled: true
											cursorShape: Qt.PointingHandCursor
											onClicked: {
												entryWrap.dismissing = true;
											}
										}
									}
								}

								Text {
									Layout.fillWidth: true
									text: entryWrap.snap.summary || ""
									font.family: Theme.fontFamily
									font.pixelSize: Theme.fontSize - 1
									font.bold: true
									color: Theme.textMain
									wrapMode: Text.WordWrap
									visible: text !== "" && !(text.trim().toLowerCase() === (entryWrap.snap.appName || "").trim().toLowerCase() && (entryWrap.snap.body || "").trim() !== "")
								}

								Text {
									Layout.fillWidth: true
									text: entryWrap.snap.body || ""
									font.family: Theme.fontFamily
									font.pixelSize: (entryWrap.snap.summary || "").trim().toLowerCase() === (entryWrap.snap.appName || "").trim().toLowerCase() ? (Theme.fontSize - 1) : Theme.fontSizeSmall
									color: (entryWrap.snap.summary || "").trim().toLowerCase() === (entryWrap.snap.appName || "").trim().toLowerCase() ? Theme.textMain : Theme.textDim
									wrapMode: Text.WordWrap
									maximumLineCount: 5
									elide: Text.ElideRight
									textFormat: Text.PlainText
									visible: text !== "" && !(text.trim().toLowerCase() === (entryWrap.snap.summary || "").trim().toLowerCase())
								}

								// Action buttons row
								RowLayout {
									visible: entryWrap.actionEntries.length > 0
									Layout.fillWidth: true
									spacing: 6
									Repeater {
										model: entryWrap.actionEntries
										delegate: NotificationActionButton {
											required property var modelData
											Layout.fillWidth: true
											notifId: modelData.snapId
											identifier: modelData.identifier
											label: modelData.text
											enabled: entryWrap.invitingLive
											opacity: entryWrap.invitingLive ? 1.0 : 0.4
										}
									}
								}

								// Inline reply row (live notifications only).
								NotificationReplyField {
									visible: entryWrap.canReply
									Layout.fillWidth: true
									notif: entryWrap.live
									placeholder: entryWrap.live ? entryWrap.live.inlineReplyPlaceholder : ""
									onReplied: Notifications.dismissEntry(entryWrap.snap.id)
								}
							}
						}
					}
				}

			// ─── Empty State ────────────────────────────────────────────
			Item {
				visible: Notifications.history.length === 0
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

					Text {
						Layout.alignment: Qt.AlignHCenter
						text: "You're all caught up"
						font.family: Theme.fontFamily
						font.pixelSize: Theme.fontSizeSmall
						color: Theme.textMuted
					}
				}
			}
	}
}
