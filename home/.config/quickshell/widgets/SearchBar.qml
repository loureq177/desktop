import ".."
import QtQuick
import QtQuick.Layouts

// The field the centred windows open on: no box of its own, an icon saying
// what it searches, and a line under it that the window draws.
Rectangle {
	id: bar

	property string icon: "search"
	property string placeholder: ""
	property alias text: input.text
	property bool completeOnTab: false
	property bool leftRightNavigate: false
	property bool showScopeHints: false

	signal accepted()
	signal cancelled()
	signal stepped(int delta)
	signal steppedColumn(int delta)
	signal completed()

	function focusInput() {
		input.focus = true;
		input.forceActiveFocus();
	}

	function clear() {
		input.text = "";
	}

	function complete(t) {
		input.text = t;
		input.cursorPosition = t.length;
	}

	color: "transparent"
	implicitHeight: 48

	MouseArea {
		anchors.fill: parent
		cursorShape: Qt.IBeamCursor
		onClicked: bar.focusInput()
	}

	RowLayout {
		anchors.fill: parent
		anchors.leftMargin: 12
		anchors.rightMargin: 4
		spacing: 12

		LineIcon {
			Layout.alignment: Qt.AlignVCenter
			Layout.preferredWidth: 28
			name: bar.icon
			size: 20
			color: Theme.textDim
		}

		TextInput {
			id: input
			Layout.fillWidth: true
			Layout.alignment: Qt.AlignVCenter
			font.family: Theme.fontMono
			font.pixelSize: Theme.fontSizeLarge
			color: Theme.textMain
			selectionColor: Theme.accentBlue
			focus: true
			clip: true

			Keys.onPressed: event => {
				var isCtrl = (event.modifiers & Qt.ControlModifier);
				if (isCtrl && event.key === Qt.Key_J) {
					bar.stepped(1);
					event.accepted = true;
					return;
				} else if (isCtrl && event.key === Qt.Key_K) {
					bar.stepped(-1);
					event.accepted = true;
					return;
				} else if (isCtrl && event.key === Qt.Key_H) {
					if (bar.leftRightNavigate)
						bar.steppedColumn(-1);
					event.accepted = true;
					return;
				} else if (isCtrl && event.key === Qt.Key_L) {
					if (bar.leftRightNavigate)
						bar.steppedColumn(1);
					event.accepted = true;
					return;
				}

				if (event.key === Qt.Key_Down) {
					bar.stepped(1);
					event.accepted = true;
				} else if (event.key === Qt.Key_Up) {
					bar.stepped(-1);
					event.accepted = true;
				} else if (event.key === Qt.Key_Left) {
					if (bar.leftRightNavigate) {
						bar.steppedColumn(-1);
						event.accepted = true;
					}
				} else if (event.key === Qt.Key_Right) {
					if (bar.leftRightNavigate) {
						bar.steppedColumn(1);
						event.accepted = true;
					}
				} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
					if (!event.isAutoRepeat)
						bar.accepted();
					event.accepted = true;
				} else if (event.key === Qt.Key_Escape) {
					if (!event.isAutoRepeat)
						bar.cancelled();
					event.accepted = true;
				} else if (event.key === Qt.Key_Tab) {
					if (bar.completeOnTab)
						bar.completed();
					else
						bar.stepped(event.modifiers & Qt.ShiftModifier ? -1 : 1);
					event.accepted = true;
				}
			}

			Text {
				anchors.fill: parent
				text: bar.placeholder
				font: input.font
				color: Theme.textDim
				verticalAlignment: Text.AlignVCenter
				elide: Text.ElideRight
				visible: input.text === ""
			}
		}

		// What else the field takes, while it is empty; a click types the prefix.
		RowLayout {
			visible: bar.showScopeHints && input.text === ""
			spacing: 2
			Layout.alignment: Qt.AlignVCenter

			Repeater {
				model: [
					{ prefix: "=", word: "calc", insert: "=" },
					{ prefix: ">", word: "run", insert: ">" }
				]

				delegate: Rectangle {
					id: chip
					required property var modelData
					implicitWidth: chipRow.implicitWidth + 12
					implicitHeight: 26
					radius: Theme.roundingSubtle
					color: chipArea.containsMouse ? Theme.bgHover : "transparent"

					Behavior on color { ColorAnimation { duration: 120 } }

					Row {
						id: chipRow
						anchors.centerIn: parent
						spacing: 5

						Text {
							text: chip.modelData.prefix
							font.family: Theme.fontMono
							font.pixelSize: Theme.fontSizeSmall
							font.bold: true
							color: chipArea.containsMouse ? Theme.accentBlue : Theme.textMain
						}

						Text {
							text: chip.modelData.word
							font.family: Theme.fontMono
							font.pixelSize: Theme.fontSizeSmall
							color: chipArea.containsMouse ? Theme.textMain : Theme.textDim
						}
					}

					MouseArea {
						id: chipArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							bar.complete(chip.modelData.insert);
							bar.focusInput();
						}
					}
				}
			}
		}
	}
}
