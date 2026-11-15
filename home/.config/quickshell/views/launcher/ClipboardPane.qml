import "../.."
import "../../widgets"
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls

// The clipboard history (cliphist), newest first, the picked entry in full beside it;
// Enter pastes it, the row's X or Delete deletes it, Clear all under the list.
LauncherPane {
	id: pane

	property var entries: []
	property bool failed: false

	icon: "clipboard"
	placeholder: "Search copied items…"
	preferredHeight: Theme.listHeight

	readonly property var items: entries.filter(e => e.preview.toLowerCase().includes(query.trim().toLowerCase()))
	readonly property alias count: list.count
	readonly property var current: items[list.currentIndex] ?? null
	readonly property string previewPath: Quickshell.env("XDG_RUNTIME_DIR") + "/clipboard-preview"
	readonly property alias wipeArmed: wipeConfirm.armed

	// What `current` holds, once decoded into previewPath: the image shown
	// from there, the text read back.
	property string decodedId: ""
	property string decodedText: ""

	// cliphist lists an image as "[[ binary data 12 KiB png 640x480 ]]":
	// [size, unit, format, dimensions], or null for text.
	function imageInfo(preview: string): var {
		var m = preview.match(/binary data (\d+(?:\.\d+)?) ([KMG]?i?B) (png|jpe?g|webp|gif|bmp) (\d+x\d+)/);
		return m ? m.slice(1) : null;
	}

	function opened(): void {
		failed = false;
		listProc.running = true;
	}

	// The window shut, or another list took its place: the decoded preview
	// goes, and the next time starts at the newest entry.
	function closed(): void {
		wipeConfirm.reset();
		decoder.running = false;
		decodedId = "";
		list.currentIndex = 0;
		Quickshell.execDetached(["rm", "-f", previewPath]);
	}

	function step(delta: int, repeat: bool): void {
		list.step(delta, repeat);
	}

	function activate(): void {
		list.activate();
	}

	function removeValue(): void {
		if (current)
			remove(current);
	}

	// Drops one entry; the row the keyboard is on stays.
	function remove(entry: var): void {
		Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", entry.id]);
		var keep = list.currentIndex;
		entries = entries.filter(e => e.id !== entry.id);
		list.currentIndex = Math.min(keep, list.count - 1);
	}

	// The first click arms it, the second wipes the history.
	function wipe(): void {
		if (!wipeConfirm.ask("wipe"))
			return;
		Quickshell.execDetached(["cliphist", "wipe"]);
		entries = [];
	}

	onQueryChanged: list.currentIndex = 0
	onCurrentChanged: Qt.callLater(decoder.decode)

	Confirm {
		id: wipeConfirm
	}

	// Nothing copied yet is no failure: cliphist has no database until the first copy.
	Process {
		id: listProc
		command: ["cliphist", "list"]
		onExited: code => pane.failed = code !== 0 && !listErr.text.includes("store something first")
		stderr: StdioCollector {
			id: listErr
		}
		stdout: StdioCollector {
			onStreamFinished: pane.entries = this.text.split("\n").filter(l => l.includes("\t")).map(l => {
				var tab = l.indexOf("\t");
				return { id: l.substring(0, tab), preview: l.substring(tab + 1) };
			})
		}
	}

	// One decode at a time; images go to previewPath and load off the GUI thread. Not a
	// FileView: its text() after reload() is stale.
	Process {
		id: decoder

		property string entryId: ""
		property bool image: false

		function decode(): void {
			var e = pane.current;
			if (running || !pane.visible || !e || e.id === pane.decodedId)
				return;
			entryId = e.id;
			image = pane.imageInfo(e.preview) !== null;
			command = image ? ["sh", "-c", 'cliphist decode "$1" > "$2"', "sh", e.id, pane.previewPath] : ["cliphist", "decode", e.id];
			running = true;
		}

		onExited: code => {
			if (code === 0 && entryId === pane.current?.id) {
				pane.decodedText = image ? "" : decodedOut.text;
				pane.decodedId = entryId;
			}
			Qt.callLater(decode);
		}

		stdout: StdioCollector {
			id: decodedOut
		}
	}

	SelectList {
		id: list
		anchors.top: parent.top
		anchors.bottom: clearBar.top
		anchors.left: parent.left
		width: parent.width * 0.42 - Theme.paddingItem
		wrap: true
		model: pane.items
		onActivated: index => {
			var entry = pane.items[index];
			var img = pane.imageInfo(entry.preview);
			Panels.close("launcher");
			Quickshell.execDetached([Commands.bin + "clipboard-insert", entry.id].concat(img ? ["image/" + img[2].toLowerCase().replace("jpg", "jpeg")] : []));
		}

		delegate: ListRow {
			id: row

			required property var modelData
			readonly property var image: pane.imageInfo(modelData.preview)

			height: Theme.rowHeight

			Row {
				anchors.fill: parent
				anchors.leftMargin: 12
				anchors.rightMargin: 8
				spacing: 12

				// What kind of entry it is.
				LineIcon {
					anchors.verticalCenter: parent.verticalCenter
					width: Theme.rowIcon
					name: row.image ? "image" : "text"
					size: 20
					color: row.selected ? Theme.accentBlue : Theme.textDim
				}

				StyledText {
					anchors.verticalCenter: parent.verticalCenter
					width: parent.width - x - remove.width - parent.spacing
					elide: Text.ElideRight
					textFormat: Text.PlainText
					text: row.image ? "Image (" + row.image[2].toUpperCase() + " " + row.image[3] + ", " + row.image[0] + " " + row.image[1] + ")"
						: row.modelData.preview.replace(/\s+/g, " ")
				}

				// At the row's end, as on a notification: deletes it.
				CloseButton {
					id: remove
					anchors.verticalCenter: parent.verticalCenter
					opacity: row.hovered || row.selected ? 1 : 0
					onClicked: pane.remove(row.modelData)
				}
			}
		}
	}

	// The whole history, on a second click.
	Item {
		id: clearBar
		anchors.left: list.left
		anchors.right: list.right
		anchors.bottom: parent.bottom
		height: pane.entries.length > 0 ? 40 : 0
		visible: height > 0

		TextButton {
			anchors.left: parent.left
			anchors.leftMargin: 4
			anchors.bottom: parent.bottom
			icon: pane.wipeArmed ? "triangle-alert" : "list-x"
			text: pane.wipeArmed ? "Click again to clear all" : "Clear all"
			danger: pane.wipeArmed
			onClicked: pane.wipe()
		}
	}

	StyledText {
		visible: list.count === 0
		anchors.centerIn: list
		font.pixelSize: Theme.fontSizeSmall
		color: Theme.textDim
		text: pane.failed ? "cliphist failed — is it installed?" : pane.entries.length === 0 ? "No clipboard entries" : "Nothing matches"
	}

	Rectangle {
		id: preview
		readonly property bool decoded: pane.current !== null && pane.decodedId === pane.current.id
		readonly property bool isImage: pane.current !== null && pane.imageInfo(pane.current.preview) !== null

		anchors.top: parent.top
		anchors.bottom: parent.bottom
		anchors.right: parent.right
		width: parent.width * 0.58 - Theme.paddingItem
		color: Theme.glass(Theme.bgMain)
		border.color: Theme.tileBorder
		border.width: 1
		radius: Theme.roundingElement
		clip: true

		Image {
			anchors.fill: parent
			anchors.margins: 12
			visible: preview.isImage && preview.decoded
			source: visible ? "file://" + pane.previewPath : ""
			fillMode: Image.PreserveAspectFit
			// Decoded no larger than shown: a screenshot is a big texture.
			sourceSize.width: width
			sourceSize.height: height
			asynchronous: true
			cache: false
			mipmap: true
		}

		Flickable {
			id: previewFlick
			anchors.fill: parent
			anchors.margins: 14
			visible: !preview.isImage
			contentWidth: width
			contentHeight: previewText.implicitHeight
			clip: true
			flickableDirection: Flickable.VerticalFlick

			ScrollBar.vertical: ThinScrollBar {}

			WheelScroll {
				flickable: previewFlick
			}

			StyledText {
				id: previewText
				width: previewFlick.width - (previewFlick.ScrollBar.vertical.visible ? 10 : 0)
				wrapMode: Text.WrapAtWordBoundaryOrAnywhere
				textFormat: Text.PlainText
				text: !pane.current ? "" : preview.decoded ? pane.decodedText : pane.current.preview
				onTextChanged: previewFlick.contentY = 0
				mono: true
				font.pixelSize: Theme.fontSizeSmall
			}
		}
	}
}
