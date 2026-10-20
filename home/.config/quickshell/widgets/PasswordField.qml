import ".."
import QtQuick
import QtQuick.Effects

// The password field of the lock screen and the polkit dialog: a gradient
// outline that reports the state, and one dot fading in per typed character.
FocusScope {
	id: field

	property alias text: input.text
	property alias readOnly: input.readOnly
	property bool masked: true
	property bool busy: false
	property bool failed: false
	// Shown in place of the dots for as long as nothing is typed.
	property string message: ""
	property color fillColor: Theme.alpha(Theme.bgCard, 0.65)

	property real dotSize: height * 0.25
	readonly property bool inputFocused: input.activeFocus

	signal accepted()
	signal cancelled()

	function focusInput() {
		input.forceActiveFocus();
	}

	TextInput {
		id: input
		width: 0
		height: 0
		opacity: 0
		focus: true
		echoMode: TextInput.Password

		onTextChanged: {
			while (dots.count < length)
				dots.append({});
			if (dots.count > length)
				dots.remove(length, dots.count - length);
		}
		Keys.onReturnPressed: field.accepted()
		Keys.onEnterPressed: field.accepted()
		Keys.onEscapePressed: field.cancelled()
	}

	ListModel {
		id: dots
	}

	Rectangle {
		anchors.fill: parent
		radius: Theme.roundingWindow
		color: field.fillColor
	}

	Rectangle {
		id: outlineFill
		anchors.fill: parent
		visible: false
		layer.enabled: true
		gradient: Gradient {
			orientation: Gradient.Horizontal
			GradientStop {
				position: 0
				color: field.busy ? Theme.accentGreen : field.failed ? Theme.warning : Theme.accentBlue
			}
			GradientStop {
				position: 1
				color: field.busy ? Theme.accentBlue : field.failed ? Theme.critical : Theme.accentPurple
			}
		}
	}

	Rectangle {
		id: outlineMask
		anchors.fill: parent
		visible: false
		layer.enabled: true
		radius: Theme.roundingWindow
		color: "transparent"
		border.width: Theme.borderSize
		border.color: "black"
	}

	MultiEffect {
		anchors.fill: parent
		source: outlineFill
		maskEnabled: true
		maskSource: outlineMask
	}

	Item {
		anchors.fill: parent
		anchors.margins: Theme.paddingItem
		clip: true

		Row {
			anchors.verticalCenter: parent.verticalCenter
			x: (parent.width - width) / 2
			spacing: field.dotSize * 0.3
			visible: field.masked

			Behavior on x {
				NumberAnimation {
					duration: Theme.lockDotsFade
					easing.type: Easing.OutCubic
				}
			}

			Repeater {
				model: dots
				Rectangle {
					width: field.dotSize
					height: field.dotSize
					radius: width / 2
					color: Theme.textMain

					NumberAnimation on opacity {
						from: 0
						to: 1
						duration: Theme.lockDotsFade
					}
					NumberAnimation on scale {
						from: 0.6
						to: 1
						duration: Theme.lockDotsFade
						easing.type: Easing.OutQuad
					}
				}
			}
		}

		StyledText {
			anchors.centerIn: parent
			width: parent.width
			text: input.length > 0 ? input.text : field.message
			visible: input.length === 0 || !field.masked
			textFormat: Text.PlainText
			color: field.failed || input.length > 0 ? Theme.textMain : Theme.textDim
			horizontalAlignment: Text.AlignHCenter
			elide: Text.ElideRight
			font.pixelSize: Theme.fontSizeSmall
		}
	}
}
