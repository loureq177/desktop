import ".."
import QtQuick
import QtQuick.Layouts

Rectangle {
	id: bar

	property string title: ""
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

	color: Theme.bgCard
	border.color: Theme.border
	border.width: 1
	radius: Theme.roundingElement
	implicitHeight: 48

	MouseArea {
		anchors.fill: parent
		cursorShape: Qt.IBeamCursor
		onClicked: bar.focusInput()
	}

	RowLayout {
		anchors.fill: parent
		anchors.leftMargin: 14
		anchors.rightMargin: 14
		spacing: Theme.paddingItem

		Text {
			visible: bar.title !== ""
			text: bar.title
			font.family: Theme.fontMono
			font.pointSize: Theme.fontSizeBar
			font.bold: true
			color: Theme.accentBlue
			verticalAlignment: Text.AlignVCenter
		}

		TextInput {
			id: input
			Layout.fillWidth: true
			Layout.alignment: Qt.AlignVCenter
			font.family: Theme.fontMono
			font.pointSize: Theme.fontSizeSearch
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
					bar.accepted();
					event.accepted = true;
				} else if (event.key === Qt.Key_Escape) {
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

		RowLayout {
			visible: bar.showScopeHints && input.text === ""
			spacing: 12
			Layout.alignment: Qt.AlignVCenter

			Text {
				text: "󰐥"
				font.family: Theme.fontFamily
				font.pixelSize: 15
				color: Theme.textMuted
			}

			Text {
				text: "󰪚"
				font.family: Theme.fontFamily
				font.pixelSize: 15
				color: Theme.textMuted
			}

			Text {
				text: ">"
				font.family: Theme.fontMono
				font.pixelSize: 13
				color: Theme.textMuted
			}
		}
	}
}
