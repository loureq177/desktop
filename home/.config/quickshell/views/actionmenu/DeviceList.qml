import "../.."
import "../../widgets"
import QtQuick
import QtQuick.Layouts

// The Wi-Fi and Bluetooth pages: a header with the radio switch, the list of
// networks or devices, and what stands in for it while the radio is off.
//
// Each of `items` is an object with key, name, icon, connected, saved (can be
// forgotten), detail (the status line when idle), dim, secured (a lock after
// the name) and battery (0..1, -1 for none). The page asks before forgetting
// and tracks one action at a time (startPending).
FocusScope {
	id: root

	property string title: ""
	property string subtitle: ""
	// "Wi-Fi", "Bluetooth"; things: what the list holds ("networks").
	property string noun: ""
	property string things: ""
	property string offIcon: ""
	property string emptyTitle: ""
	property string emptyHint: ""
	property string forgetVerb: "forget"
	property string timeoutMessage: ""
	property int radioKey: 0
	property bool radioOn: false
	property bool scanning: false
	property var items: []
	property string errorMessage: ""
	// A form under the list (the Wi-Fi password) has the keys and the errors.
	property bool prompting: false

	// The row the keyboard is on, by key: it stays on it when the list resorts.
	property string currentKey: ""
	readonly property var currentItem: items.find(i => i.key === currentKey) ?? null

	property string pendingKey: ""
	property string pendingStatus: ""

	default property alias extra: column.data

	// The height of a form under the list.
	property int extraHeight: 0
	implicitHeight: !radioOn ? 260 : items.length === 0 ? 220 + extraHeight : Math.min(620, Math.max(260, 75 + items.length * 56 + extraHeight))

	signal backRequested()
	signal radioToggled()
	signal scanRequested()
	// Enter or a click on a row that is not connected: connect, pair, ask.
	signal activated(var item)
	signal disconnectRequested(var item)
	signal forgetConfirmed(var item)
	signal promptKeyPressed(var event)
	signal timedOut()

	function isPending(item): bool {
		return item !== null && pendingKey === item.key && pendingStatus !== "";
	}

	function startPending(key: string, status: string): void {
		errorMessage = "";
		pendingKey = key;
		pendingStatus = status;
		pendingTimer.restart();
	}

	function clearPending(): void {
		pendingTimer.stop();
		pendingKey = "";
		pendingStatus = "";
	}

	function toggleConnection(item): void {
		if (!item || isPending(item))
			return;
		if (item.connected)
			root.disconnectRequested(item);
		else
			root.activated(item);
	}

	function forget(item): void {
		if (!item)
			return;
		if (!forgetConfirm.ask(item.key))
			return;
		if (pendingKey === item.key)
			clearPending();
		root.forgetConfirmed(item);
	}

	onItemsChanged: list.currentIndex = Math.max(0, items.findIndex(i => i.key === currentKey))
	onRadioOnChanged: {
		if (!radioOn) {
			clearPending();
			errorMessage = "";
		}
	}
	onVisibleChanged: {
		if (visible) {
			errorMessage = "";
			currentKey = items[0]?.key ?? "";
			if (radioOn)
				root.scanRequested();
		} else {
			clearPending();
		}
	}

	Timer {
		id: pendingTimer
		interval: 15000
		onTriggered: {
			root.clearPending();
			root.errorMessage = root.timeoutMessage;
			root.timedOut();
		}
	}

	Confirm {
		id: forgetConfirm
	}

	Keys.onPressed: event => {
		if (root.prompting) {
			root.promptKeyPressed(event);
			return;
		}
		var key = event.key;
		if (key === Qt.Key_Space || key === radioKey) {
			event.isAutoRepeat || root.radioToggled();
		} else if (key === Qt.Key_X || key === Qt.Key_Delete) {
			event.isAutoRepeat || forget(currentItem);
		} else if (key === Qt.Key_R) {
			root.scanRequested();
		} else if (key === Qt.Key_H || key === Qt.Key_Left || key === Qt.Key_Backspace || key === Qt.Key_Escape || key === Qt.Key_Q) {
			root.backRequested();
		} else {
			return;
		}
		event.accepted = true;
	}

	ColumnLayout {
		id: column
		anchors.fill: parent
		spacing: 12

		SubViewHeader {
			Layout.fillWidth: true
			title: root.title
			subtitle: root.subtitle
			enabledState: root.radioOn
			isScanning: root.scanning
			scanKey: "R"
			toggleKey: String.fromCharCode(root.radioKey)
			onBackClicked: root.backRequested()
			onScanClicked: root.scanRequested()
			onToggleClicked: root.radioToggled()
		}

		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: 1
			color: Theme.border
		}

		ErrorBanner {
			visible: root.radioOn && !root.prompting && (root.errorMessage !== "" || forgetConfirm.armed !== "")
			message: forgetConfirm.armed !== "" ? "Press X again to " + root.forgetVerb + " \"" + (root.items.find(i => i.key === forgetConfirm.armed)?.name ?? "") + "\"" : root.errorMessage
		}

		Item {
			visible: !root.radioOn
			Layout.fillWidth: true
			Layout.fillHeight: true

			ColumnLayout {
				anchors.centerIn: parent
				spacing: 12

			LineIcon {
				Layout.alignment: Qt.AlignHCenter
				name: root.offIcon
				size: 48
				color: Theme.textMuted
			}

			StyledText {
				Layout.alignment: Qt.AlignHCenter
				text: root.noun + " is turned off"
				font.bold: true
			}

			StyledText {
				Layout.alignment: Qt.AlignHCenter
				text: "Turn on " + root.noun + " to scan and connect to " + root.things
				mono: true
				font.pixelSize: Theme.fontSizeSmall
				color: Theme.textDim
			}

			TextButton {
				Layout.alignment: Qt.AlignHCenter
				Layout.topMargin: 8
				primary: true
				text: "Turn On " + root.noun
				onClicked: root.radioToggled()
			}

			StyledText {
				Layout.alignment: Qt.AlignHCenter
				Layout.topMargin: 4
				text: "Press [space] to turn on"
				mono: true
				font.pixelSize: Theme.fontSizeTiny
				color: Theme.textMuted
			}
			}
		}

		SelectList {
			id: list
			visible: root.radioOn
			focus: true
			Layout.fillWidth: true
			Layout.fillHeight: true
			scrollBar: true
			spacing: 6
			model: root.items
			onCurrentIndexChanged: root.currentKey = root.items[currentIndex]?.key ?? ""
			onActivated: index => root.toggleConnection(root.items[index])

			delegate: ListRow {
				id: row

				required property var modelData
				readonly property bool connected: modelData.connected
				readonly property bool busy: root.isPending(modelData)

				height: 50
				color: connected ? Theme.alpha(Theme.accent, 0.08) : Theme.glass(Theme.bgMain)
				border.color: connected ? Theme.selectionBorder : Theme.tileBorder
				border.width: 1
				highlightColor: connected ? Theme.alpha(Theme.accent, 0.20) : Theme.selectionBg

				Behavior on color { ColorAnimation { duration: Theme.animFast } }

				// A click only connects; Enter on a connected row disconnects.
				MouseArea {
					anchors.fill: parent
					cursorShape: Qt.PointingHandCursor
					onClicked: {
						list.currentIndex = row.index;
						if (!row.connected && !row.busy)
							root.activated(row.modelData);
					}
				}

				RowLayout {
					anchors.fill: parent
					anchors.leftMargin: 12
					anchors.rightMargin: 12
					spacing: 10

					LineIcon {
						Layout.preferredWidth: 24
						name: row.modelData.icon
						size: 20
						color: row.connected ? Theme.accentBlue : (row.modelData.dim ? Theme.textDim : Theme.textMain)
					}

					ColumnLayout {
						Layout.fillWidth: true
						spacing: 1

						RowLayout {
							spacing: 6

							StyledText {
								Layout.fillWidth: true
								text: row.modelData.name
								font.bold: row.connected || row.selected
								color: row.connected ? Theme.accentBlue : Theme.textMain
								elide: Text.ElideRight
							}

							LineIcon {
								visible: row.modelData.secured
								name: "lock"
								size: 13
								color: Theme.textDim
							}
						}

						RowLayout {
							spacing: 6

							StyledText {
								text: row.busy ? root.pendingStatus : (row.connected ? "Connected" : row.modelData.detail)
								mono: true
								font.pixelSize: Theme.fontSizeTiny
								color: row.busy ? Theme.warning : (row.connected ? Theme.accentBlue : Theme.textDim)
							}

							Row {
								id: battery
								readonly property real level: row.modelData.battery
								readonly property color tint: level <= 0.20 ? Theme.critical : (level <= 0.40 ? Theme.warning : Theme.accentGreen)
								visible: level >= 0
								spacing: 4

								StyledText {
									anchors.verticalCenter: parent.verticalCenter
									text: "·"
									mono: true
									font.pixelSize: Theme.fontSizeTiny
									color: battery.tint
								}

								LineIcon {
									anchors.verticalCenter: parent.verticalCenter
									name: "battery-medium"
									size: Theme.fontSizeSmall
									color: battery.tint
								}

								StyledText {
									anchors.verticalCenter: parent.verticalCenter
									text: Math.round(battery.level * 100) + "%"
									mono: true
									font.pixelSize: Theme.fontSizeTiny
									color: battery.tint
								}
							}
						}
					}

					TextButton {
						visible: row.connected
						implicitHeight: 26
						text: "Disconnect"
						onClicked: root.disconnectRequested(row.modelData)
					}

					Rectangle {
						visible: row.modelData.saved || row.connected
						implicitWidth: 26
						implicitHeight: 26
						radius: Theme.roundingSubtle
						color: forgetArea.containsMouse ? Theme.bgCard : "transparent"
						border.color: forgetArea.containsMouse ? Theme.critical : "transparent"
						border.width: 1

						LineIcon {
							anchors.centerIn: parent
							name: "trash"
							size: 14
							color: forgetArea.containsMouse ? Theme.critical : Theme.textDim
						}

						MouseArea {
							id: forgetArea
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: root.forget(row.modelData)
						}
					}

					StyledText {
						visible: !row.connected && !row.busy
						text: "›"
						font.pixelSize: Theme.fontSizeLarge
						color: row.selected ? Theme.accentBlue : Theme.textMuted
					}
				}
			}

			Column {
				anchors.centerIn: parent
				visible: root.items.length === 0 && !root.scanning
				spacing: 8

				StyledText {
					anchors.horizontalCenter: parent.horizontalCenter
					text: root.emptyTitle
					font.pixelSize: Theme.fontSizeSmall
					color: Theme.textDim
				}

				StyledText {
					anchors.horizontalCenter: parent.horizontalCenter
					text: root.emptyHint
					mono: true
					font.pixelSize: Theme.fontSizeTiny
					color: Theme.textMuted
				}
			}
		}
	}
}
