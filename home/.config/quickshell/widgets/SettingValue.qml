import ".."
import QtQuick

// A setting's value at the end of its row: switch, swatch, number in its range or
// choice; blue when set in the settings.
Row {
	id: root

	required property var setting
	property bool selected: false

	readonly property string kind: setting?.kind ?? ""
	readonly property bool changed: setting ? Settings.changed(setting) : false
	readonly property color tint: changed ? Theme.accentBlue : selected ? Theme.textMain : Theme.textDim
	readonly property real fraction: setting && (kind === "int" || kind === "float") && setting.min !== null && setting.max !== null && setting.max > setting.min
		? Math.max(0, Math.min(1, (Number(setting.value) - setting.min) / (setting.max - setting.min))) : -1

	spacing: 8

	Rectangle {
		visible: root.kind === "bool"
		anchors.verticalCenter: parent.verticalCenter
		width: 30
		height: 16
		radius: 8
		color: root.setting?.value ? Theme.accentBlue : Theme.bgHover
		border.color: root.setting?.value ? Theme.accentBlue : Theme.border
		border.width: 1

		Behavior on color { ColorAnimation { duration: Theme.animFast } }

		Rectangle {
			width: 10
			height: 10
			radius: 5
			anchors.verticalCenter: parent.verticalCenter
			x: root.setting?.value ? parent.width - width - 3 : 3
			color: root.setting?.value ? Theme.bgMain : Theme.textDim

			Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
		}
	}

	Rectangle {
		readonly property string swatch: root.setting ? Settings.swatch(root.setting) : ""
		visible: swatch !== ""
		anchors.verticalCenter: parent.verticalCenter
		width: 14
		height: 14
		radius: 3
		color: swatch || "transparent"
		border.color: Theme.border
		border.width: 1
	}

	StyledText {
		visible: root.kind === "enum"
		anchors.verticalCenter: parent.verticalCenter
		text: "‹"
		color: Theme.textDim
		opacity: root.selected ? 1 : 0
	}

	StyledText {
		visible: root.kind !== "bool"
		anchors.verticalCenter: parent.verticalCenter
		width: Math.min(implicitWidth, 200)
		elide: Text.ElideRight
		textFormat: Text.PlainText
		text: root.setting ? Settings.display(root.setting) : ""
		mono: true
		font.pixelSize: Theme.fontSizeSmall
		color: root.tint
	}

	StyledText {
		visible: root.kind === "enum"
		anchors.verticalCenter: parent.verticalCenter
		text: "›"
		color: Theme.textDim
		opacity: root.selected ? 1 : 0
	}

	Rectangle {
		visible: root.fraction >= 0
		anchors.verticalCenter: parent.verticalCenter
		width: 56
		height: 4
		radius: 2
		color: Theme.bgHover

		Rectangle {
			width: parent.width * root.fraction
			height: parent.height
			radius: 2
			color: root.changed ? Theme.accentBlue : Theme.textDim

			Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
		}
	}
}
