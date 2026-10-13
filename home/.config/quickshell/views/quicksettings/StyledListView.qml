import "../.."
import "../../widgets"
import QtQuick
import QtQuick.Controls

ListView {
	anchors.fill: parent
	clip: true
	spacing: 6
	boundsBehavior: Flickable.DragAndOvershootBounds
	flickDeceleration: Theme.flickDecel
	maximumFlickVelocity: Theme.maxFlickVel

	ScrollBar.vertical: ThinScrollBar {}
}
