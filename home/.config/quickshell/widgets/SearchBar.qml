import ".."
import QtQuick
import QtQuick.Layouts

// The launcher's field: no box of its own, an icon saying
// what it searches, and a line under it that the window draws.
Rectangle {
	id: bar

	property string icon: "search"
	// The icon is a button (the way back).
	property bool iconClickable: false
	property string placeholder: ""
	property alias text: input.text
	property bool leftRightNavigate: false
	// Buttons of the window, after the field (Clear all).
	default property alias trailing: trailingRow.data

	signal accepted()
	signal iconClicked()
	signal cancelled()
	// `repeat`: the key is held down.
	signal stepped(int delta, bool repeat)
	signal steppedColumn(int delta, bool repeat)
	// Tab and Shift+Tab: a step too, unless the list has its own use for it.
	signal tabbed(int delta, bool repeat)
	// Ctrl+Shift with H or L: the list before or after.
	signal switched(int delta)
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

		Item {
			Layout.alignment: Qt.AlignVCenter
			Layout.preferredWidth: 28
			Layout.preferredHeight: 28

			Rectangle {
				anchors.fill: parent
				anchors.margins: -2
				radius: Theme.roundingSubtle
				color: iconArea.containsMouse && bar.iconClickable ? Theme.hoverBg : "transparent"
			}

			LineIcon {
				anchors.centerIn: parent
				name: bar.icon
				size: 20
				color: iconArea.containsMouse && bar.iconClickable ? Theme.textMain : Theme.textDim
			}

			MouseArea {
				id: iconArea
				anchors.fill: parent
				anchors.margins: -2
				enabled: bar.iconClickable
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: bar.iconClicked()
			}
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

			// Ctrl with H J K L: the arrows.
			Keys.onPressed: event => {
				var ctrl = event.modifiers & Qt.ControlModifier;
				var vim = ctrl ? [Qt.Key_H, Qt.Key_J, Qt.Key_K, Qt.Key_L].indexOf(event.key) : -1;
				var key = vim < 0 ? event.key : [Qt.Key_Left, Qt.Key_Down, Qt.Key_Up, Qt.Key_Right][vim];
				var held = event.isAutoRepeat;
				if (ctrl && event.modifiers & Qt.ShiftModifier && (vim === 0 || vim === 3)) {
					bar.switched(vim === 0 ? -1 : 1);
					event.accepted = true;
					return;
				}
				if (key === Qt.Key_Down)
					bar.stepped(1, held);
				else if (key === Qt.Key_Up)
					bar.stepped(-1, held);
				else if (bar.leftRightNavigate && key === Qt.Key_Left)
					bar.steppedColumn(-1, held);
				else if (bar.leftRightNavigate && key === Qt.Key_Right)
					bar.steppedColumn(1, held);
				else if (vim >= 0)
					input.cursorPosition = Math.max(0, Math.min(input.text.length, input.cursorPosition + (key === Qt.Key_Right ? 1 : -1)));
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
