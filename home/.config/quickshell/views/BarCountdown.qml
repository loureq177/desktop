import ".."
import "../widgets"
import QtQuick

// A countdown in the middle of the bar, calm out of the corner of an eye: whole minutes in
// dim colours, its own colour and the seconds only in the last minute.
Row {
	id: root

	property bool wanted: false
	property int secondsLeft: 0
	property int total: 0
	property string icon: ""
	property color tone: Theme.accentBlue
	readonly property bool last: secondsLeft <= 60
	// Moves once a minute, as the text does.
	readonly property int shown: last ? secondsLeft : Math.ceil(secondsLeft / 60) * 60

	function text(s: int): string {
		if (s <= 60)
			return Modes.timerText(s);
		var min = Math.ceil(s / 60), h = Math.floor(min / 60);
		return h > 0 ? h + " h" + (min % 60 ? " " + min % 60 + " min" : "") : min + " min";
	}

	anchors.centerIn: parent
	height: parent.height
	spacing: 10
	visible: opacity > 0
	opacity: wanted ? 1 : 0
	layer.enabled: true
	layer.effect: Halo {}

	Behavior on opacity {
		NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
	}

	LineIcon {
		anchors.verticalCenter: parent.verticalCenter
		name: root.icon
		color: root.last ? root.tone : Theme.textDim
	}

	Level {
		anchors.verticalCenter: parent.verticalCenter
		height: 6
		radius: 3
		value: root.total > 0 ? root.shown / root.total : 0
		fill: root.last ? root.tone : Theme.textDim
	}

	// As wide as its longest text: the row stays put as it changes.
	StyledText {
		id: time
		anchors.verticalCenter: parent.verticalCenter
		width: Math.max(startRoom.width, lastRoom.width)
		text: root.text(root.secondsLeft)
		mono: true
		font.bold: root.last
		font.pixelSize: Theme.fontSizeBar
		color: root.last ? Theme.textMain : Theme.textDim

		TextMetrics {
			id: startRoom
			font.family: time.font.family
			font.pixelSize: time.font.pixelSize
			font.bold: true
			text: root.text(root.total)
		}

		TextMetrics {
			id: lastRoom
			font.family: time.font.family
			font.pixelSize: time.font.pixelSize
			font.bold: true
			text: "0:00"
		}
	}
}
