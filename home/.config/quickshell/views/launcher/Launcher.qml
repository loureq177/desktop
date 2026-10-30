import "../.."
import "../../widgets"
import QtQuick
import QtQuick.Layouts

// One search field over the lists (LauncherPane): apps, emoji, clipboard, keys
// and settings; Backspace in the empty field goes back to the apps.
ModalWindow {
	id: root

	property string scope: "apps"
	readonly property var panes: ({ apps: apps, emoji: emoji, clipboard: clipboard, keys: keys, settings: settings })
	readonly property var pane: panes[scope]

	shown: Panels.active === "launcher"
	onDismissRequested: Panels.close("launcher")
	onShownChanged: {
		if (!shown)
			root.pane.closed();
	}

	Connections {
		target: Panels
		function onOpened(name, mode) {
			if (name !== "launcher")
				return;
			var next = root.panes[mode] ? mode : "apps";
			// Another list in the open window: its contents fade in.
			if (next !== root.scope) {
				root.pane.closed();
				if (!root.animating)
					contentFade.restart();
			}
			root.scope = next;
			search.clear();
			search.focusInput();
			root.pane.opened();
		}
	}

	Connections {
		target: root.pane
		function onQueryRequested(text) {
			search.text = text;
			search.focusInput();
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
				leftRightNavigate: root.pane.grid

				onAccepted: root.pane.activate()
				onCancelled: {
					if (!root.pane.back())
						Panels.close("launcher");
				}
				onResetRequested: root.pane.resetValue()
				onRemoveRequested: root.pane.removeValue()
				onStepped: (delta, repeat) => root.pane.step(delta, repeat)
				onSteppedColumn: (delta, repeat) => root.pane.stepColumn(delta, repeat)
				onErased: {
					if (!root.pane.back() && root.scope !== "apps")
						Panels.open("launcher", "apps");
				}

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

				// The other lists, the open one in blue: a click on it goes back to the apps.
				Repeater {
					model: ["clipboard", "emoji", "keys", "settings"]

					delegate: IconButton {
						id: listButton
						required property string modelData
						readonly property var command: Commands.get(modelData)
						readonly property string chord: Keybinds.chordFor(command.bind)
						readonly property bool open: root.scope === modelData

						implicitWidth: 28
						implicitHeight: 28
						icon: command.icon
						outlined: false
						iconColor: open ? Theme.accentBlue : hovered ? Theme.textMain : Theme.textDim
						onClicked: Panels.open("launcher", open ? "apps" : modelData)

						Tip {
							text: listButton.command.name + (listButton.chord !== "" ? "  ·  " + listButton.chord : "")
							visible: listButton.hovered
							x: Math.round((listButton.width - width) / 2)
							y: listButton.height + 6
						}
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

				SettingsPane {
					id: settings
					anchors.fill: parent
					visible: root.scope === "settings"
					query: visible ? search.text : ""
				}
			}

			ErrorBanner {
				visible: message !== ""
				message: root.pane.error
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
				text: root.pane.footer
			}
		}
	}
}
