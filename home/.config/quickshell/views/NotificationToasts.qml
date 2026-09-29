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

	// Shown while toasts exist and neither drawer is open; unmap is
	// deferred until the slide-out animation finishes.
	property bool shown: Notifications.toasts.length > 0 && !Notifications.centerOpen && !QuickSettings.panelOpen
	// 0 = on screen; width + margin = fully off the right edge (the toast
	// slides in leftward from the right screen edge into its corner; the
	// margin goes negative to push the window past the screen edge).
	property int slide: Theme.notifWidth + Theme.notifRightMargin

	visible: shown || slideOut.running
	color: "transparent"
	exclusiveZone: 0

	// Global inline-reply keyboard focus state: the count of toast focus
	// scopes whose TextInput currently has active focus (increases on focus
	// gained, decreases on focus lost, clamped at 0). The window reacts by
	// taking KeyboardFocus.Exclusive while a reply is being typed.
	QtObject {
		id: replyFocus

		property int count: 0
		readonly property bool active: count > 0

		function bump(delta: int): void {
			count = Math.max(0, count + delta);
			// Release focus so the layer keyboard lock drops cleanly when
			// the count hits zero.
			if (count === 0 && win.visible)
				stack.forceActiveFocus();
		}
	}

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
	// Keyboard focus only while an inline reply field owns focus, so typing
	// into a toast works while normal app shortcuts stay untouched.
	WlrLayershell.keyboardFocus: replyFocus.active !== true ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
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
				readonly property var actionEntries: Notifications.entriesFromActions(notif.id, notif.actions)

				width: stack.width
				implicitHeight: Math.max(bodyCol.implicitHeight + Theme.notifPadV * 2, toastPic.size + Theme.notifPadV * 2)
				color: hoverArea.containsMouse ? Theme.bgHover : Theme.bgCard
				border.color: card.critical ? Theme.critical : Theme.border
				border.width: Theme.borderSize
				radius: Theme.roundingElement
				clip: true

				// Below the content: child button areas stay clickable on top.
				// Body click activates "default" (open chat / custom action);
				// notifications without one are dismissed on click.
				MouseArea {
					id: hoverArea
					anchors.fill: parent
					hoverEnabled: true
					acceptedButtons: Qt.LeftButton
					onClicked: Notifications.activate(notif.id)
				}

				// Critical urgency indicator strip on left
				Rectangle {
					visible: card.critical
					anchors.top: parent.top
					anchors.bottom: parent.bottom
					anchors.left: parent.left
					width: 3
					color: Theme.critical
					radius: Theme.roundingSubtle
					z: 3
				}

				// Picture on the left side of the toast - fixed size, vertically centered
				NotificationPicture {
					id: toastPic
					anchors.left: parent.left
					anchors.leftMargin: (card.critical ? 3 : 0) + Theme.notifPadH
					anchors.verticalCenter: parent.verticalCenter
					size: 64
					image: card.notif.image || ""
					appIcon: card.notif.appIcon || ""
					appName: card.notif.appName || ""
					z: 1
				}

				// Main text and actions column, vertically centered
				ColumnLayout {
					id: bodyCol
					z: 2
					anchors.left: toastPic.right
					anchors.leftMargin: 12
					anchors.right: closeBtn.left
					anchors.rightMargin: 8
					anchors.verticalCenter: parent.verticalCenter
					spacing: 3

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
							text: {
								var t = Notifications.historyTimeById(card.notif.id);
								return Qt.formatDateTime(t ? new Date(t) : new Date(), "hh:mm");
							}
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
						visible: text !== "" && !(text.trim().toLowerCase() === (card.notif.appName || "").trim().toLowerCase() && (card.notif.body || "").trim() !== "")
					}
					Text {
						Layout.fillWidth: true
						text: card.notif.body || ""
						font.family: Theme.fontFamily
						font.pixelSize: (card.notif.summary || "").trim().toLowerCase() === (card.notif.appName || "").trim().toLowerCase() ? Theme.fontSize : (Theme.fontSizeSmall + 1)
						color: (card.notif.summary || "").trim().toLowerCase() === (card.notif.appName || "").trim().toLowerCase() ? Theme.textMain : Theme.textDim
						wrapMode: Text.WordWrap
						maximumLineCount: 6
						elide: Text.ElideRight
						textFormat: Text.PlainText
						visible: text !== "" && !(text.trim().toLowerCase() === (card.notif.summary || "").trim().toLowerCase())
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

					// Inline reply row (only for inline-reply capable senders).
					NotificationReplyField {
						id: replyField
						visible: card.notif !== null && card.notif.hasInlineReply
						Layout.fillWidth: true
						notif: card.notif
						placeholder: card.notif ? card.notif.inlineReplyPlaceholder : ""
						onReplied: Notifications.dismissEntry(card.notif.id)
						onFocusLost: replyFocus.bump(-1)
						onFocusGained: replyFocus.bump(1)
					}
				}

				// Close button in top-right corner
				Rectangle {
					id: closeBtn
					anchors.top: parent.top
					anchors.topMargin: 8
					anchors.right: parent.right
					anchors.rightMargin: 8
					implicitWidth: 20
					implicitHeight: 20
					radius: Theme.roundingElement
					color: closeArea.containsMouse ? Theme.bgHover : "transparent"
					z: 2

					Text {
						anchors.centerIn: parent
						text: "✕"
						font.pixelSize: 11
						color: closeArea.containsMouse ? Theme.critical : Theme.textMuted
					}

					MouseArea {
						id: closeArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: Notifications.dismissEntry(notif.id)
					}
				}
			}
		}
	}
}
