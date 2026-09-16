// Sticky toast popups, top-right above everything (layer-shell overlay).
// Geometry mirrors the old SwayNC setup: 500px wide, 58px below the top
// (clears the bar), 20px from the right (matches Hyprland gaps_out).
// Pops slide in from the right screen edge and slide back out right.
// Toasts are sticky: focus changes, new windows, and opening/closing the
// center never dismiss them. The window hugs its content exactly and hides
// when empty so it never blocks clicks. No expire timers: sticky parity
// (timeout 0).
import ".."
import "../widgets"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
	id: win

	// Shown while toasts exist and the control center is closed; unmap is
	// deferred until the slide-out animation finishes.
	property bool shown: Notifications.toasts.length > 0 && !Notifications.centerOpen
	// 0 = on screen; width + margin = fully off the right edge (the toast
	// slides in leftward from the right screen edge into its corner; the
	// margin goes negative to push the window past the screen edge).
	property int slide: Theme.notifWidth + Theme.notifRightMargin

	visible: shown || slideOut.running
	color: "transparent"
	exclusiveZone: 0

	// Input follows the content: clicks outside the stacked cards fall
	// through to the windows below instead of hitting this overlay.
	mask: Region {
		item: stack
	}

	onShownChanged: {
		if (shown) {
			slideOut.stop();
			slideIn.restart();
		} else {
			slideIn.stop();
			slideOut.restart();
		}
	}

	SequentialAnimation {
		id: slideIn

		NumberAnimation {
			target: win
			property: "slide"
			to: 0
			duration: 300
			easing.type: Easing.OutCubic
		}
	}

	SequentialAnimation {
		id: slideOut

		NumberAnimation {
			target: win
			property: "slide"
			to: Theme.notifWidth + Theme.notifRightMargin
			duration: 300
			easing.type: Easing.OutCubic
		}
	}

	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell"

	screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

	anchors {
		top: true
		right: true
	}
	margins {
		top: Theme.notifTopMargin
		right: Theme.notifRightMargin - slide
	}

	implicitWidth: Theme.notifWidth
	implicitHeight: stack.implicitHeight

	Column {
		id: stack
		anchors.top: parent.top
		anchors.left: parent.left
		anchors.right: parent.right
		spacing: 8

		Repeater {
			model: Notifications.toasts

			delegate: Rectangle {
				id: card
				required property var modelData
				property var notif: modelData
				property bool critical: notif && notif.urgency === NotificationUrgency.Critical
				// Plain entries for the nested action Repeater: its delegates
				// receive the outer `modelData`, so each entry carries the
				// stable notification id + identifier for singleton lookup.
				// The "default" action is not a button: body clicks invoke it.
				readonly property var actionEntries: {
					var out = [];
					if (!notif || !notif.actions)
						return out;
					for (var i = 0; i < notif.actions.length; i++) {
						var a = notif.actions[i];
						if (a.identifier === "default")
							continue;
						out.push({
							identifier: a.identifier || "",
							text: a.text || "Action",
							toastId: notif.id
						});
					}
					return out;
				}

				width: stack.width
				implicitHeight: Math.max(cardRow.implicitHeight, 40) + Theme.notifPadV * 2
				color: hoverArea.containsMouse ? Theme.bgHover : Theme.bgCard
				border.color: card.critical ? Theme.critical : Theme.border
				border.width: 1
				radius: Theme.roundingElement

				// Below the content: child button areas stay clickable on top.
				// Body click runs the default action (opens the app); only
				// actionless notifications fall back to plain dismissal.
				MouseArea {
					id: hoverArea
					anchors.fill: parent
					hoverEnabled: true
					acceptedButtons: Qt.LeftButton
					onClicked: Notifications.activate(notif.id)
				}

				Rectangle {
					visible: card.critical
					anchors.top: parent.top
					anchors.bottom: parent.bottom
					anchors.left: parent.left
					anchors.leftMargin: Theme.borderSize
					width: 3
					color: Theme.critical
				}

				RowLayout {
					id: cardRow
					anchors.fill: parent
					anchors.leftMargin: Theme.notifPadH
					anchors.rightMargin: Theme.notifPadH
					anchors.topMargin: Theme.notifPadV
					anchors.bottomMargin: Theme.notifPadV
					spacing: 12

					NotificationPicture {
						id: toastPic
						image: card.notif.image || ""
						appIcon: card.notif.appIcon || ""
						size: 48
						Layout.preferredWidth: toastPic.visible ? 48 : 0
						Layout.preferredHeight: toastPic.visible ? 48 : 0
						Layout.alignment: Qt.AlignTop
					}

					ColumnLayout {
						id: bodyCol
						Layout.fillWidth: true
						spacing: 4

						RowLayout {
							Layout.fillWidth: true
							spacing: 8
							Text {
								Layout.fillWidth: true
								text: card.notif.appName || ""
								font.family: Theme.fontMono
								font.pointSize: Theme.fontSizeSmall
								font.bold: true
								color: Theme.textDim
								elide: Text.ElideRight
								visible: text !== ""
							}
							Text {
								text: Qt.formatDateTime(new Date(), "hh:mm")
								font.family: Theme.fontMono
								font.pointSize: Theme.fontSizeSmall
								color: Theme.textMuted
							}
						}
						Text {
							Layout.fillWidth: true
							text: card.notif.summary || ""
							font.family: Theme.fontFamily
							font.pixelSize: Theme.fontSize
							font.bold: true
							color: Theme.textMain
							wrapMode: Text.WordWrap
							visible: text !== ""
						}
						Text {
							Layout.fillWidth: true
							text: card.notif.body || ""
							font.family: Theme.fontFamily
							font.pixelSize: Theme.fontSizeSmall + 1
							color: Theme.textDim
							wrapMode: Text.WordWrap
							maximumLineCount: 6
							elide: Text.ElideRight
							textFormat: Text.PlainText
							visible: text !== ""
						}

						// Actions share one row instead of stacking.
						RowLayout {
							visible: card.actionEntries.length > 0
							Layout.fillWidth: true
							spacing: 6
							Repeater {
								model: card.actionEntries
								delegate: NotificationActionButton {
									required property var modelData
									Layout.fillWidth: true
									notifId: modelData.toastId
									identifier: modelData.identifier
									label: modelData.text
								}
							}
						}
					}

					Text {
						Layout.alignment: Qt.AlignTop
						text: "✕"
						font.pixelSize: 16
						color: closeArea.containsMouse ? Theme.critical : Theme.textMuted

						MouseArea {
							id: closeArea
							anchors.fill: parent
							anchors.margins: -10
							hoverEnabled: true
							onClicked: Notifications.safeDismiss(notif)
						}
					}
				}
			}
		}
	}
}
