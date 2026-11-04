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
	property bool leftRightNavigate: false
	// Buttons of the window, after the field (Clear all).
	default property alias trailing: trailingRow.data

	signal accepted()
	signal cancelled()
	// `repeat`: the key is held down.
	signal stepped(int delta, bool repeat)
	signal steppedColumn(int delta, bool repeat)
	// Ctrl + H / L: sideways in a grid, out and in where the list has levels.
	signal sideways(int delta, bool repeat)
	// Tab and Shift+Tab: a step too, unless the list has its own use for it.
	signal tabbed(int delta, bool repeat)
	// Backspace in an empty field.
	signal erased()
	signal resetRequested()
	// Delete with nothing after the cursor to delete.
	signal removeRequested()

	function focusInput() {
		input.focus = true;
		input.forceActiveFocus();
	}

	function clear() {
		input.text = "";
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
			renderType: TextInput.NativeRendering
			Layout.fillWidth: true
			Layout.alignment: Qt.AlignVCenter
			font.family: Theme.fontMono
			font.pixelSize: Theme.fontSizeLarge
			color: Theme.textMain
			selectionColor: Theme.accentBlue
			focus: true
			clip: true

			// Ctrl with J / K moves like the arrows, with H / L as the pane says (sideways).
			Keys.onPressed: event => {
				var ctrl = event.modifiers & Qt.ControlModifier;
				var key = event.key;
				var held = event.isAutoRepeat;
				if (key === Qt.Key_Down || (ctrl && key === Qt.Key_J))
					bar.stepped(1, held);
				else if (key === Qt.Key_Up || (ctrl && key === Qt.Key_K))
					bar.stepped(-1, held);
				else if (ctrl && (key === Qt.Key_H || key === Qt.Key_L))
					bar.sideways(key === Qt.Key_L ? 1 : -1, held);
				else if (bar.leftRightNavigate && key === Qt.Key_Left)
					bar.steppedColumn(-1, held);
				else if (bar.leftRightNavigate && key === Qt.Key_Right)
					bar.steppedColumn(1, held);
				else if (key === Qt.Key_Tab || key === Qt.Key_Backtab)
					bar.tabbed(event.modifiers & Qt.ShiftModifier || key === Qt.Key_Backtab ? -1 : 1, held);
				else if (key === Qt.Key_Backspace && input.text === "")
					bar.erased();
				else if (key === Qt.Key_Return || key === Qt.Key_Enter)
					event.isAutoRepeat || bar.accepted();
				else if (key === Qt.Key_Escape)
					event.isAutoRepeat || bar.cancelled();
				else if (ctrl && key === Qt.Key_R)
					event.isAutoRepeat || bar.resetRequested();
				else if (key === Qt.Key_Delete && input.cursorPosition === input.text.length)
					event.isAutoRepeat || bar.removeRequested();
				else
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

		Row {
			id: trailingRow
			spacing: 6
			Layout.alignment: Qt.AlignVCenter
		}
	}
}
