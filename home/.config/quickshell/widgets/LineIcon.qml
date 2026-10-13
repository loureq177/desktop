import "LineIcons.js" as LineIcons
import QtQuick

Image {
	id: root

	property string name: ""
	property color color: "white"
	property int size: 16

	width: size
	height: size
	// A wider or taller box (a column of icons) centres the icon instead of stretching it.
	fillMode: Image.PreserveAspectFit
	sourceSize: Qt.size(size * Screen.devicePixelRatio, size * Screen.devicePixelRatio)
	source: LineIcons.uri(name, String(color))
	visible: name !== ""
}
