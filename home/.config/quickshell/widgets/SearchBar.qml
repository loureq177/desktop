import ".."
import QtQuick
import QtQuick.Layouts

// The launcher's field: no box of its own, an icon saying
// what it searches, and a line under it that the window draws.
Rectangle {
	id: bar

	property string icon: "search"
	property string placeholder: ""
	property alias text: input.text
	property bool completeOnTab: false
	property bool leftRightNavigate: false
	// The names of the other lists, to switch to.
	property var scopes: []
	// Buttons of the window, between the field and the scopes (Clear all).
	default property alias trailing: trailingRow.data

	signal accepted()
	signal cancelled()
	signal stepped(int delta)
	signal steppedColumn(int delta)
	signal completed()
	// Backspace in an empty field.
	signal erased()
	signal scopeChosen(string name)

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

			// Ctrl with J / K (H / L in a grid) moves like the arrows.
			Keys.onPressed: event => {
				var ctrl = event.modifiers & Qt.ControlModifier;
				var key = event.key;
				if (key === Qt.Key_Down || (ctrl && key === Qt.Key_J))
					bar.stepped(1);
				else if (key === Qt.Key_Up || (ctrl && key === Qt.Key_K))
					bar.stepped(-1);
				else if (bar.leftRightNavigate && (key === Qt.Key_Left || (ctrl && key === Qt.Key_H)))
					bar.steppedColumn(-1);
				else if (bar.leftRightNavigate && (key === Qt.Key_Right || (ctrl && key === Qt.Key_L)))
					bar.steppedColumn(1);
				else if (key === Qt.Key_Tab && bar.completeOnTab)
					bar.completed();
				else if (key === Qt.Key_Tab)
					bar.stepped(event.modifiers & Qt.ShiftModifier ? -1 : 1);
				else if (key === Qt.Key_Backspace && input.text === "")
					bar.erased();
				else if (key === Qt.Key_Return || key === Qt.Key_Enter)
					event.isAutoRepeat || bar.accepted();
				else if (key === Qt.Key_Escape)
					event.isAutoRepeat || bar.cancelled();
				else if (!ctrl || (key !== Qt.Key_H && key !== Qt.Key_L))
					return;
				event.accepted = true;
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

		// Before the scopes, so they stay where they are in every window.
		Row {
			id: trailingRow
			spacing: 6
			Layout.alignment: Qt.AlignVCenter
		}

		// The other lists, while the field is empty; a click goes there.
		Row {
			visible: bar.scopes.length > 0 && input.text === ""
			spacing: 2
			Layout.alignment: Qt.AlignVCenter

			Repeater {
				model: bar.scopes

				delegate: Rectangle {
					id: chip
					required property string modelData
					readonly property bool lit: chipArea.containsMouse
					implicitWidth: chipText.implicitWidth + 12
					implicitHeight: 26
					radius: Theme.roundingSubtle
					color: chip.lit ? Theme.bgHover : "transparent"

					Behavior on color { ColorAnimation { duration: Theme.animFast } }

					StyledText {
						id: chipText
						anchors.centerIn: parent
						text: chip.modelData
						mono: true
						font.pixelSize: Theme.fontSizeSmall
						color: chip.lit ? Theme.textMain : Theme.textDim
					}

					MouseArea {
						id: chipArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						// scopeChosen rebuilds the chips, this one with them: last.
						onClicked: {
							bar.focusInput();
							bar.scopeChosen(chip.modelData);
						}
					}
				}
			}
		}
	}
}
