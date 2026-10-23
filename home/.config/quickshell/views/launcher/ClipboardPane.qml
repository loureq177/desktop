import "../.."
import "../../widgets"
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls

// The clipboard history (cliphist): what was copied, newest first, and what
// the row picked holds in full beside it. Enter pastes it into the focused
// window; the icon of a row deletes it.
LauncherPane {
	id: pane

	property var entries: []
	property bool failed: false

	icon: "clipboard"
	placeholder: "Search " + entries.length + " copied items..."
	preferredHeight: Theme.windowHeight

	readonly property var items: entries.filter(e => e.preview.toLowerCase().includes(query.trim().toLowerCase()))
	readonly property alias count: list.count
	readonly property var current: items[list.currentIndex] ?? null
	readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR")
	readonly property string thumbDir: runDir + "/clipboard-thumbs"
	readonly property string previewPath: runDir + "/clipboard-preview"
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

	function step(delta: int): void {
		list.step(delta);
	}

	function activate(): void {
		list.activate();
	}

	// Drops one entry, its thumbnail with it; the row the keyboard is on stays.
	function remove(entry: var): void {
		Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete; rm -f "$2"', "sh", entry.id, thumbDir + "/" + entry.id]);
		var keep = list.currentIndex;
		entries = entries.filter(e => e.id !== entry.id);
		list.currentIndex = Math.min(keep, list.count - 1);
	}

	// The first click arms it, the second wipes the history.
	function wipe(): void {
		if (!wipeConfirm.ask("wipe"))
			return;
		Quickshell.execDetached(["sh", "-c", 'cliphist wipe; rm -rf "$1"', "sh", thumbDir]);
		entries = [];
	}

	onQueryChanged: list.currentIndex = 0
	onCurrentChanged: Qt.callLater(decoder.decode)
	onVisibleChanged: {
		if (!visible)
			closed();
	}

	Confirm {
		id: wipeConfirm
	}

	Process {
		id: listProc
		command: ["cliphist", "list"]
		onExited: code => pane.failed = code !== 0
		stdout: StdioCollector {
			onStreamFinished: pane.entries = this.text.split("\n").filter(l => l.includes("\t")).map(l => {
				var tab = l.indexOf("\t");
				return { id: l.substring(0, tab), preview: l.substring(tab + 1) };
			})
		}
	}

	// One decode at a time; the entry picked meanwhile is decoded next.
	Process {
		id: decoder

		property string entryId: ""

		function decode(): void {
			var e = pane.current;
			if (running || !pane.visible || !e || e.id === pane.decodedId)
				return;
			entryId = e.id;
			command = ["sh", "-c", 'cliphist decode "$1" > "$2"', "sh", e.id, pane.previewPath];
			running = true;
		}

		onExited: code => {
			if (code === 0 && entryId === pane.current?.id) {
				previewFile.reload();
				pane.decodedText = pane.imageInfo(pane.current.preview) ? "" : previewFile.text();
				pane.decodedId = entryId;
			}
			Qt.callLater(decode);
		}
	}

	FileView {
		id: previewFile
		path: pane.previewPath
		blockLoading: true
		printErrors: false
	}

	SelectList {
		id: list
		anchors.top: parent.top
		anchors.bottom: parent.bottom
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
			readonly property string thumbPath: pane.thumbDir + "/" + modelData.id
			property bool thumbReady: false

			height: Theme.rowHeight

			Process {
				running: row.image !== null
				command: ["sh", "-c", '[ -s "$1" ] || { mkdir -p "$2" && cliphist decode "$3" | magick - -thumbnail 120x80 "$1"; }', "sh", row.thumbPath, pane.thumbDir, row.modelData.id]
				onExited: code => row.thumbReady = code === 0
			}

			Row {
				anchors.fill: parent
				anchors.leftMargin: 12
				anchors.rightMargin: 12
				spacing: 12

				// The thumbnail or the text icon; under the pointer, the X that
				// deletes the entry.
				Item {
					readonly property bool armed: deleteArea.containsMouse
					anchors.verticalCenter: parent.verticalCenter
					width: row.image ? 48 : Theme.rowIcon
					height: Theme.rowIcon

					Image {
						anchors.fill: parent
						visible: row.thumbReady
						opacity: parent.armed ? 0.35 : 1
						source: row.thumbReady ? "file://" + row.thumbPath : ""
						fillMode: Image.PreserveAspectCrop
						asynchronous: true
						sourceSize: Qt.size(120, 80)

						Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
					}

					LineIcon {
						visible: !row.image
						anchors.centerIn: parent
						name: "text"
						size: 20
						color: row.selected ? Theme.accentBlue : Theme.textDim
						opacity: parent.armed ? 0 : 1

						Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
					}

					Rectangle {
						anchors.fill: parent
						radius: Theme.roundingSubtle
						color: Theme.alpha(Theme.critical, 0.16)
						opacity: parent.armed ? 1 : 0

						Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

						LineIcon {
							anchors.centerIn: parent
							name: "x"
							size: 18
							color: Theme.critical
						}
					}

					MouseArea {
						id: deleteArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: pane.remove(row.modelData)
					}
				}

				StyledText {
					anchors.verticalCenter: parent.verticalCenter
					width: parent.width - x
					elide: Text.ElideRight
					textFormat: Text.PlainText
					text: row.image ? "Image (" + row.image[2].toUpperCase() + " " + row.image[3] + ", " + row.image[0] + " " + row.image[1] + ")"
						: row.modelData.preview.replace(/\s+/g, " ")
				}
			}
		}
	}

	StyledText {
		visible: list.count === 0
		anchors.centerIn: list
		font.pixelSize: Theme.fontSizeSmall
		color: Theme.textDim
		text: pane.failed ? "cliphist failed — is it installed?" : pane.entries.length === 0 ? "No clipboard entries" : "No match"
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
