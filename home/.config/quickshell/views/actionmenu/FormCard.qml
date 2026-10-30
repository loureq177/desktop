import "../.."
import "../../widgets"
import QtQuick
import QtQuick.Layouts

// A form under a page's list: its title, what it asks for and the two buttons.
Rectangle {
	id: root

	property string title: ""
	property string acceptText: ""
	property bool busy: false
	default property alias content: fields.data

	signal accepted()
	signal cancelled()

	Layout.fillWidth: true
	radius: Theme.roundingElement
	color: Theme.glass(Theme.bgMain)
	border.color: Theme.accentBlue
	border.width: 1
	implicitHeight: column.implicitHeight + 2 * column.anchors.margins

	ColumnLayout {
		id: column
		anchors.fill: parent
		anchors.margins: 12
		spacing: 10

		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			StyledText {
				Layout.fillWidth: true
				text: root.title
				font.pixelSize: Theme.fontSizeSmall
				font.bold: true
				elide: Text.ElideRight
			}

			CloseButton {
				onClicked: root.cancelled()
			}
		}

		ColumnLayout {
			id: fields
			Layout.fillWidth: true
			spacing: 10
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			Item { Layout.fillWidth: true }

			TextButton {
				text: "Cancel (Esc)"
				onClicked: root.cancelled()
			}

			TextButton {
				primary: true
				opacity: root.busy ? 0.6 : 1.0
				text: root.acceptText
				onClicked: root.accepted()
			}
		}
	}
}
