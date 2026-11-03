import "LineIcons.js" as LineIcons
import QtQuick
import Quickshell

Image {
	id: root

	property string name: ""
	property color color: "white"
	property int size: 16
	// For a mark that shows the date: changes with it.
	property int day: 0

	width: size
	height: size
	// A wider or taller box (a column of icons) centres the icon instead of stretching it.
	fillMode: Image.PreserveAspectFit
	// The window's ratio follows a scale change; Screen's is whole (2 at 125%), the icon blurred.
	readonly property real ratio: QsWindow.window?.devicePixelRatio ?? Screen.devicePixelRatio
	sourceSize: Qt.size(size * ratio, size * ratio)
	source: LineIcons.uri(name, String(color), day)
	visible: name !== ""
}
