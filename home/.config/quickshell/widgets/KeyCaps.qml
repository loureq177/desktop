import ".."
import QtQuick

// A chord as key caps: "SUPER + SHIFT + E" is three caps side by side, while
// "/" and "," between keys (alternatives, presses in turn) stay plain text.
Row {
	id: root

	property string chord: ""
	property bool highlighted: false

	readonly property var parts: chord.split(/( \/ |, )/).reduce((out, p) => out.concat(p === " / " || p === ", "
		? [{ text: p.trim(), cap: false }]
		: p.split(" + ").map(k => ({ text: k, cap: true }))), [])

	spacing: 4
	visible: chord !== ""

	Repeater {
		model: root.parts

		delegate: Item {
			required property var modelData
			width: modelData.cap ? Math.max(24, capText.implicitWidth + 12) : sepText.implicitWidth
			height: 24

			Rectangle {
				visible: parent.modelData.cap
				anchors.fill: parent
				radius: Theme.roundingSubtle + 1
				color: Theme.alpha(Theme.textMain, root.highlighted ? 0.1 : 0.05)
				border.color: Theme.tileBorder
				border.width: 1
			}

			StyledText {
				id: capText
				visible: parent.modelData.cap
				anchors.centerIn: parent
				mono: true
				font.pixelSize: Theme.fontSizeTiny
				font.bold: true
				color: root.highlighted ? Theme.textMain : Theme.textDim
				text: parent.modelData.text
			}

			StyledText {
				id: sepText
				visible: !parent.modelData.cap
				anchors.centerIn: parent
				mono: true
				font.pixelSize: Theme.fontSizeTiny
				color: Theme.textMuted
				text: parent.modelData.text
			}
		}
	}
}
