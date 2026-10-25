import "../.."
import "../../widgets"
import "../../widgets/ListNav.js" as ListNav
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
	property string offIcon: ""
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

	onItemsChanged: {
		var i = items.findIndex(item => item.key === currentKey);
		// Gone, or nothing there before: the first row.
		if (i < 0 && items.length > 0)
			currentKey = items[0].key;
		list.currentIndex = Math.max(0, i);
	}
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
			list.currentIndex = 0;
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
			root.errorMessage = "Timed out";
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
		} else if (ListNav.back(event)) {
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
			message: forgetConfirm.armed !== "" ? "Press X again to forget \"" + (root.items.find(i => i.key === forgetConfirm.armed)?.name ?? "") + "\"" : root.errorMessage
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
				text: root.title + " is off"
				font.bold: true
			}

			TextButton {
				Layout.alignment: Qt.AlignHCenter
				Layout.topMargin: 8
				primary: true
				text: "Turn on (Space)"
				onClicked: root.radioToggled()
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
				border.color: connected ? Theme.alpha(Theme.accent, 0.32) : Theme.tileBorder
				border.width: 1

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

					IconButton {
						visible: row.modelData.saved || row.connected
						implicitWidth: 26
						implicitHeight: 26
						icon: "trash"
						iconSize: 14
						outlined: false
						danger: true
						onClicked: root.forget(row.modelData)
					}

					StyledText {
						visible: !row.connected && !row.busy
						text: "›"
						font.pixelSize: Theme.fontSizeLarge
						color: row.selected ? Theme.textMain : Theme.textMuted
					}
				}
			}

			Column {
				anchors.centerIn: parent
				visible: root.items.length === 0 && !root.scanning
				spacing: 8

				StyledText {
					anchors.horizontalCenter: parent.horizontalCenter
					text: "Nothing found"
					font.pixelSize: Theme.fontSizeSmall
					color: Theme.textDim
				}

				StyledText {
					anchors.horizontalCenter: parent.horizontalCenter
					text: "Press R to scan again"
					mono: true
					font.pixelSize: Theme.fontSizeTiny
					color: Theme.textMuted
				}
			}
		}
	}
}
