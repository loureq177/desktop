// Clipboard history picker: replaces the cliphist + fzf + Ghostty special
// workspace. Toggled with SUPER + CTRL + V (`qs ipc call clipboard toggle`).
// Two-column dialog: entry list on the left, large preview pane on the
// right (images decoded from cliphist, text shown in full). Enter or click
// copies the entry and pastes it via wtype.
import ".."
import "../widgets"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
	id: win

	visible: false
	color: "transparent"
	exclusiveZone: 0

	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell"

	screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	property string query: ""
	// All entries as {id, preview}; newest first (cliphist order).
	property var entries: []
	property var filtered: []
	property int currentIndex: 0
	// Set after the preview decode for the current entry succeeds.
	property string decodedId: ""

	// "[[ binary data 496 KiB png 2539x1765 ]]" is how cliphist previews
	// images.
	readonly property var currentEntry: filtered.length > 0 && currentIndex < filtered.length ? filtered[currentIndex] : null
	readonly property bool currentIsImage: {
		if (!currentEntry)
			return false;
		return / binary data (\d+(?:\.\d+)?) [KMG]?i?B (png|jpe?g|webp|gif|bmp) (\d+x\d+)/.test(currentEntry.preview || "");
	}

	function refilter() {
		var q = query.toLowerCase().trim();
		var out = [];
		for (var i = 0; i < entries.length; i++) {
			var e = entries[i];
			if (q === "" || e.preview.toLowerCase().indexOf(q) !== -1)
				out.push(e);
		}
		filtered = out;
		currentIndex = 0;
		// The entry under index 0 changed even when currentIndex stayed 0.
		previewTimer.restart();
	}

	function paste(entry) {
		if (!entry)
			return;
		pasteProc.command = ["sh", "-c", 'cliphist decode ' + JSON.stringify(String(entry.id)) + ' | wl-copy; wtype -M ctrl -k v -m ctrl'];
		pasteProc.running = true;
		win.close();
	}

	function activate() {
		paste(filtered[currentIndex]);
	}

	function open() {
		query = "";
		search.clear();
		listLoader.running = true;
		win.visible = true;
		search.focusInput();
	}

	function close() {
		win.visible = false;
	}

	function toggle() {
		if (win.visible)
			close();
		else
			open();
	}

	function move(delta) {
		var n = filtered.length;
		if (n === 0) {
			currentIndex = 0;
			return;
		}
		currentIndex = Math.max(0, Math.min(n - 1, currentIndex + delta));
	}

	onCurrentIndexChanged: {
		previewTimer.restart();
		list.positionViewAtIndex(currentIndex, ListView.Contain);
	}

	// Decode the selected entry to a file for the preview pane.
	Timer {
		id: previewTimer
		interval: 1
		onTriggered: {
			win.decodedId = "";
			decodeProc.running = true;
		}
	}

	Process {
		id: decodeProc
		command: {
			var e = win.currentEntry;
			if (!e || !win.currentIsImage)
				return ["true"];
			return ["sh", "-c", 'cliphist decode ' + JSON.stringify(String(e.id)) + ' > "$XDG_RUNTIME_DIR/clipboard-preview"'];
		}
		onExited: function (exitCode) {
			if (exitCode === 0 && win.currentEntry)
				win.decodedId = win.currentEntry.id;
		}
	}

	Process {
		id: listLoader
		command: ["cliphist", "list"]
		stdout: StdioCollector {
			onStreamFinished: {
				var out = [];
				var lines = String(this.text || "").split("\n");
				for (var i = 0; i < lines.length; i++) {
					var line = lines[i];
					if (line.trim() === "")
						continue;
					var tab = line.indexOf("\t");
					if (tab === -1)
						continue;
					out.push({ id: line.substring(0, tab), preview: line.substring(tab + 1) });
				}
				win.entries = out;
				win.refilter();
			}
		}
	}

	Process {
		id: pasteProc
	}

	Shortcut {
		sequences: ["Esc"]
		enabled: win.visible
		onActivated: win.close()
	}

	// Clicking outside the card closes.
	MouseArea {
		anchors.fill: parent
		onClicked: win.close()

		Rectangle {
			id: dialogCard
			anchors.centerIn: parent
			width: Theme.windowWidth
			height: Theme.windowHeight
			color: Theme.bgMain
			border.color: Theme.border
			border.width: Theme.borderSize
			radius: Theme.roundingWindow

			MouseArea {
				anchors.fill: parent
			}

			ColumnLayout {
				anchors.fill: parent
				spacing: 0

				SearchBar {
					id: search
					Layout.fillWidth: true
					Layout.preferredHeight: 64
					title: "Clip"
					placeholder: "Search clipboard..."
					onTextChanged: {
						win.query = text;
						win.refilter();
					}
					onAccepted: win.activate()
					onCancelled: win.close()
					onStepped: delta => win.move(delta)
				}

				Rectangle {
					Layout.fillWidth: true
					Layout.preferredHeight: 1
					color: Theme.border
				}

				Item {
					id: contentBox
					Layout.fillWidth: true
					Layout.fillHeight: true
					Layout.margins: Theme.paddingCard

					ListView {
						id: list
						anchors.top: parent.top
						anchors.bottom: parent.bottom
						anchors.left: parent.left
						width: parent.width * 0.55 - Theme.paddingItem
						clip: true
						flickDeceleration: 600
						maximumFlickVelocity: 4000
						spacing: 2
						model: win.filtered

						delegate: Rectangle {
							id: row
							required property var modelData
							required property int index

							readonly property string preview: row.modelData?.preview ?? ""
							// Image rows get a small inline thumbnail, decoded
							// from cliphist once (atomic tmp+mv publish;
							// skipped when the cached file already exists).
							readonly property var imageInfo: {
								var m = preview.match(/binary data (\d+(?:\.\d+)?) [KMG]?i?B (png|jpe?g|webp|gif|bmp) (\d+x\d+)/);
								return m ? m[2].toUpperCase() + "  " + m[3] : "";
							}
							readonly property bool isImage: imageInfo !== ""
							readonly property string thumbPath: row.isImage ? (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/clipboard-thumbs/" + String(row.modelData.id) : ""
							property bool thumbReady: false

							width: ListView.view.width
							implicitHeight: 44
							color: index === win.currentIndex ? Theme.selectionBg : (rowArea.containsMouse ? Theme.bgHover : "transparent")
							border.color: index === win.currentIndex ? Theme.selectionBorder : "transparent"
							border.width: 1
							radius: Theme.roundingElement

							Behavior on color {
								ColorAnimation { duration: 100 }
							}

							Process {
								running: row.isImage
								command: {
									// Paths from cliphist go through JSON.stringify,
									// like the id already does: raw interpolation is a shell injection point.
									var id = JSON.stringify(String(row.modelData.id));
									return ["sh", "-c",
										'f=' + JSON.stringify(row.thumbPath)
										+ '; [ -s "$f" ] || { mkdir -p ' + JSON.stringify((Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/clipboard-thumbs")
										+ ' && cliphist decode ' + id + ' > "$f.tmp" && mv "$f.tmp" "$f"; }'];
								}
								onExited: function (exitCode) {
									row.thumbReady = (exitCode === 0);
								}
							}

							RowLayout {
								anchors.fill: parent
								anchors.leftMargin: 12
								anchors.rightMargin: 12
								spacing: 10

								Image {
									visible: row.isImage && row.thumbReady
									source: visible ? "file://" + row.thumbPath : ""
									asynchronous: true
									fillMode: Image.PreserveAspectFit
									sourceSize.width: 64
									sourceSize.height: 64
									Layout.preferredWidth: 32
									Layout.preferredHeight: 32
									Layout.alignment: Qt.AlignVCenter
								}

								Text {
									visible: row.isImage
									text: row.imageInfo
									textFormat: Text.PlainText
									font.family: Theme.fontMono
									font.pixelSize: Theme.fontSizeSmall + 1
									color: index === win.currentIndex ? Theme.accentBlue : Theme.textDim
									elide: Text.ElideRight
									Layout.fillWidth: true
									Layout.alignment: Qt.AlignVCenter
								}

								Text {
									visible: !row.isImage
									text: row.preview
									textFormat: Text.PlainText
									font.family: Theme.fontMono
									font.pixelSize: Theme.fontSizeSmall + 1
									color: index === win.currentIndex ? Theme.accentBlue : Theme.textMain
									elide: Text.ElideRight
									Layout.fillWidth: true
									Layout.alignment: Qt.AlignVCenter
								}
							}

							MouseArea {
								id: rowArea
								anchors.fill: parent
								hoverEnabled: true
								onEntered: win.currentIndex = row.index
								onClicked: win.paste(row.modelData)
							}
						}
					}

					Text {
						visible: win.filtered.length === 0
						anchors.horizontalCenter: list.horizontalCenter
						anchors.verticalCenter: parent.verticalCenter
						text: win.entries.length === 0 ? "No clipboard entries" : "No match"
						font.family: Theme.fontMono
						font.pointSize: Theme.fontSizeBar
						color: Theme.textDim
					}

					// Preview pane: decoded image at full size or the full
					// text body.
					Rectangle {
						id: previewPane
						anchors.top: parent.top
						anchors.bottom: parent.bottom
						anchors.right: parent.right
						width: parent.width * 0.45
						color: Theme.bgCard
						border.color: Theme.border
						border.width: 1
						radius: Theme.roundingElement

						Image {
							anchors.fill: parent
							anchors.margins: Theme.paddingItem
							visible: win.currentIsImage && win.decodedId === (win.currentEntry?.id ?? "")
							source: visible ? "file://" + (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/clipboard-preview" : ""
							fillMode: Image.PreserveAspectFit
							asynchronous: true
							cache: false
						}

						Flickable {
							anchors.fill: parent
							anchors.margins: Theme.paddingItem
							visible: !win.currentIsImage
							clip: true
							contentWidth: width
							flickDeceleration: 600

							Text {
								width: parent.width
								wrapMode: Text.Wrap
								textFormat: Text.PlainText
								text: win.currentEntry ? win.currentEntry.preview : ""
								font.family: Theme.fontMono
								font.pixelSize: Theme.fontSizeSmall
								color: Theme.textMain
							}
						}
					}
				}
			}
		}
	}

	IpcHandler {
		target: "clipboard"

		function toggle(): void {
			win.toggle();
		}
		function open(): void {
			win.open();
		}
		function close(): void {
			win.close();
		}
	}
}
