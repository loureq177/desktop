import "LineIcons.js" as LineIcons
import QtQuick

Image {
	id: root

	property string name: ""
	property color color: "white"
	property int size: 16

	width: size
	height: size
	sourceSize: Qt.size(size * Screen.devicePixelRatio, size * Screen.devicePixelRatio)
	source: LineIcons.uri(name, String(color))
	visible: name !== ""
}
