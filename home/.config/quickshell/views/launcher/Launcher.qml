import "../.."
import "../../widgets"
import QtQuick
import QtQuick.Layouts

// One search field over four lists: the apps (with the commands, arithmetic,
// files and the PATH), the emoji, the clipboard history and the keys. The
// empty field offers the other three; Backspace there goes back to the apps.
// Each list (pane) has the same shape: query, icon, placeholder,
// preferredHeight, step(), activate(), and maybe stepColumn(), complete(),
// opened(), closed() and a footer line.
ModalWindow {
	id: root

	property string scope: "apps"
	readonly property var panes: ({ apps: apps, emoji: emoji, clipboard: clipboard, keys: keys })
	readonly property var pane: panes[scope]

	panel: true
	shown: Panels.active === "launcher"
	onDismissRequested: Panels.close("launcher")
	onShownChanged: {
		if (!shown && root.pane.closed)
			root.pane.closed();
	}

	Connections {
		target: Panels
		function onOpened(name, mode) {
			if (name !== "launcher")
				return;
			var next = root.panes[mode] ? mode : "apps";
			// Another list in the open window: its contents fade in.
			if (root.shown && !root.animating && next !== root.scope)
				contentFade.restart();
			root.scope = next;
			search.clear();
			search.focusInput();
			if (root.pane.opened)
				root.pane.opened();
		}
	}

	NumberAnimation {
		id: contentFade
		target: content
		property: "opacity"
		from: 0
		to: 1
		duration: Theme.animFast
		easing.type: Easing.OutCubic
	}

	Rectangle {
		anchors.horizontalCenter: parent.horizontalCenter
		y: Math.round((parent.height - Theme.windowHeight) / 2)
		transformOrigin: Item.Top
		scale: 0.82 + 0.18 * root.progress
		width: Theme.windowWidth
		// As tall as what the list has, up to the shared height.
		height: Math.min(Theme.windowHeight, column.implicitHeight + Theme.paddingCard * 2)
		color: Theme.glass(Theme.bgCard)
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingWindow
		clip: true

		Behavior on height {
			enabled: root.shown && !root.animating
			NumberAnimation {
				duration: Theme.animFast
				easing.type: Easing.OutCubic
			}
		}

		// Clicks on the card stay on it, not on the dim behind.
		MouseArea {
			anchors.fill: parent
		}

		ColumnLayout {
			id: column
			anchors.fill: parent
			anchors.margins: Theme.paddingCard
			spacing: 12

			SearchBar {
				id: search
				Layout.fillWidth: true
				icon: root.pane.icon
				placeholder: root.pane.placeholder
				scopes: Object.keys(root.panes).filter(name => name !== root.scope)
				completeOnTab: root.pane.completeOnTab ?? false
				leftRightNavigate: root.pane.stepColumn !== undefined

				onAccepted: root.pane.activate()
				onCancelled: Panels.close("launcher")
				onStepped: delta => root.pane.step(delta)
				onSteppedColumn: delta => root.pane.stepColumn(delta)
				onCompleted: {
					var line = root.pane.complete();
					if (line)
						search.complete(line);
				}
				onErased: {
					if (root.scope !== "apps")
						Panels.open("launcher", "apps");
				}
				onScopeChosen: name => Panels.open("launcher", name)

				// The first click arms it, the second wipes the history.
				TextButton {
					visible: root.scope === "clipboard" && clipboard.entries.length > 0
					icon: clipboard.wipeArmed ? "triangle-alert" : "list-x"
					text: clipboard.wipeArmed ? "Click again" : "Clear all"
					danger: clipboard.wipeArmed
					onClicked: {
						clipboard.wipe();
						search.focusInput();
					}
				}
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.leftMargin: -Theme.paddingCard
				Layout.rightMargin: -Theme.paddingCard
				Layout.topMargin: -4
				Layout.preferredHeight: 1
				color: Theme.border
			}

			Item {
				id: content
				Layout.fillWidth: true
				Layout.fillHeight: true
				Layout.preferredHeight: root.pane.preferredHeight

				AppsPane {
					id: apps
					anchors.fill: parent
					visible: root.scope === "apps"
					query: visible ? search.text : ""
				}

				EmojiPane {
					id: emoji
					anchors.fill: parent
					visible: root.scope === "emoji"
					query: visible ? search.text : ""
				}

				ClipboardPane {
					id: clipboard
					anchors.fill: parent
					visible: root.scope === "clipboard"
					query: visible ? search.text : ""
				}

				KeysPane {
					id: keys
					anchors.fill: parent
					visible: root.scope === "keys"
					query: visible ? search.text : ""
				}
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 1
				visible: footer.visible
				color: Theme.border
			}

			StyledText {
				id: footer
				Layout.fillWidth: true
				Layout.preferredHeight: 36
				visible: text !== ""
				verticalAlignment: Text.AlignVCenter
				mono: true
				color: Theme.textDim
				elide: Text.ElideRight
				text: root.pane.footer ?? ""
			}
		}
	}
}
