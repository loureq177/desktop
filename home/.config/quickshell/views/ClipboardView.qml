import ".."
import "../widgets"
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

CenterModal {
	id: win

	panel: "clipboard"
	searchIcon: "clipboard"
	searchPlaceholder: win.placeholderFor(win.entries.length, "copied items")
	scope: "clipboard"

	onSearchQueryChanged: {
		win.query = searchQuery;
		win.refilter();
	}
	onSearchAccepted: win.activate()
	onSearchStepped: delta => win.move(delta)

	property string query: ""
	property var entries: []
	property var filtered: []
	property int currentIndex: 0
	property string decodedText: ""
	property string textReqId: ""
	property string imgReqId: ""
	property string decodedId: ""
	// Counts preview requests: a decode restarted mid-flight still reports the
	// output of the one it replaced, which belongs to an older request.
	property int textSeq: 0
	property int textStartedSeq: -1
	property bool listFailed: false

	readonly property var currentEntry: filtered.length > 0 && currentIndex < filtered.length ? filtered[currentIndex] : null
	readonly property bool currentIsImage: currentEntry !== null && imageInfo(currentEntry.preview) !== null
	readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR")

	// cliphist lists an image as "[[ binary data 12 KiB png 640x480 ]]":
	// [size, unit, format, dimensions], or null for text.
	function imageInfo(preview) {
		var m = (preview || "").match(/binary data (\d+(?:\.\d+)?) ([KMG]?i?B) (png|jpe?g|webp|gif|bmp) (\d+x\d+)/);
		return m ? m.slice(1) : null;
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
		previewFlick.contentY = 0;
		previewTimer.restart();
	}

	function paste(entry) {
		if (!entry)
			return;
		var img = imageInfo(entry.preview);
		var args = [Quickshell.env("HOME") + "/.local/bin/clipboard-insert", String(entry.id)];
		if (img)
			args.push("image/" + img[2].toLowerCase().replace("jpg", "jpeg"));
		Panels.close("clipboard");
		Quickshell.execDetached(args);
	}

	function activate() {
		paste(filtered[currentIndex]);
	}

	onOpened: {
		win.listFailed = false;
		listLoader.running = true;
	}

	onShownChanged: {
		if (shown)
			return;
		decodeProc.running = false;
		Quickshell.execDetached(["rm", "-f", win.runDir + "/clipboard-preview"]);
		win.decodedText = "";
		win.decodedId = "";
		win.textReqId = "";
		win.imgReqId = "";
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
		previewFlick.contentY = 0;
	}

	Timer {
		id: previewTimer
		interval: 1
		onTriggered: {
			win.decodedId = "";
			win.decodedText = "";
			win.textReqId = "";
			win.imgReqId = "";
			decodeProc.running = false;
			textDecodeProc.running = false;
			var e = win.currentEntry;
			if (!e)
				return;
			if (win.currentIsImage) {
				win.imgReqId = String(e.id);
				decodeProc.running = true;
			} else {
				win.textReqId = String(e.id);
				win.textSeq++;
				textDecodeProc.running = true;
			}
		}
	}

	Process {
		id: decodeProc
		command: {
			var e = win.currentEntry;
			if (!e || !win.currentIsImage)
				return ["true"];
			return ["sh", "-c", 'cliphist decode "$1" > "$XDG_RUNTIME_DIR/clipboard-preview"', "sh", String(e.id)];
		}
		onExited: function (exitCode) {
			var reqId = win.imgReqId;
			if (exitCode === 0 && reqId !== "" && win.currentEntry && String(win.currentEntry.id) === reqId)
				win.decodedId = reqId;
		}
	}

	Process {
		id: textDecodeProc
		command: {
			if (!win.currentEntry || win.currentIsImage || win.textReqId === "")
				return ["true"];
			return ["cliphist", "decode", win.textReqId];
		}
		onStarted: win.textStartedSeq = win.textSeq
		stdout: StdioCollector {
			onStreamFinished: {
				var reqId = win.textReqId;
				if (win.textStartedSeq !== win.textSeq)
					return;
				if (reqId !== "" && win.currentEntry && String(win.currentEntry.id) === reqId) {
					win.decodedText = String(this.text || "");
					win.decodedId = reqId;
					previewFlick.contentY = 0;
				}
			}
		}
	}

	Process {
		id: listLoader
		command: ["cliphist", "list"]
		onExited: function (exitCode) {
			win.listFailed = (exitCode !== 0);
		}
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

	Item {
		id: contentBox
		anchors.fill: parent

		ListView {
			id: list
			anchors.top: parent.top
			anchors.bottom: parent.bottom
			anchors.left: parent.left
			width: parent.width * 0.42 - Theme.paddingItem
			clip: true
			model: win.filtered

			WheelScroll {
				flickable: list
			}

			delegate: Rectangle {
				id: row
				required property var modelData
				required property int index

				readonly property string preview: row.modelData?.preview ?? ""
				readonly property var image: win.imageInfo(row.preview)
				readonly property bool isImage: image !== null
				readonly property string thumbPath: row.isImage ? win.runDir + "/clipboard-thumbs/" + String(row.modelData.id) : ""

				width: list.width
				height: Theme.rowHeight
				clip: true
				color: "transparent"
				radius: Theme.roundingElement

				property bool thumbReady: false

				SelectionHighlight {
					selected: row.index === win.currentIndex
				}

				Process {
					id: thumbLoader
					running: row.isImage
					command: [
						"sh", "-c",
						'f="$1"; [ -s "$f" ] || { mkdir -p "$2" && cliphist decode "$3" | magick - -thumbnail 120x80 "$f"; }',
						"sh",
						row.thumbPath,
						win.runDir + "/clipboard-thumbs",
						String(row.modelData.id)
					]
					onExited: function (exitCode) {
						row.thumbReady = (exitCode === 0);
					}
				}

				RowLayout {
					anchors.fill: parent
					anchors.leftMargin: 12
					anchors.rightMargin: 12
					spacing: 12

					Rectangle {
						visible: row.isImage
						Layout.preferredWidth: 48
						Layout.preferredHeight: Theme.rowIcon
						Layout.alignment: Qt.AlignVCenter
						radius: Theme.roundingSubtle
						color: Theme.bgHover
						clip: true

						Image {
							id: thumbImg
							anchors.fill: parent
							visible: row.thumbReady
							source: row.thumbReady ? "file://" + row.thumbPath : ""
							fillMode: Image.PreserveAspectCrop
							asynchronous: true
							sourceSize.width: 120
							sourceSize.height: 80
						}
					}

					Item {
						visible: !row.isImage
						Layout.preferredWidth: Theme.rowIcon
						Layout.preferredHeight: Theme.rowIcon

						LineIcon {
							anchors.centerIn: parent
							name: "text"
							size: 20
							color: row.index === win.currentIndex ? Theme.accentBlue : Theme.textDim
						}
					}

					Text {
						Layout.fillWidth: true
						Layout.alignment: Qt.AlignVCenter
						textFormat: Text.PlainText
						font.family: Theme.fontFamily
						font.pixelSize: Theme.fontSize
						color: Theme.textMain
						elide: Text.ElideRight
						text: row.isImage ? "Image (" + row.image[2].toUpperCase() + " " + row.image[3] + ", " + row.image[0] + " " + row.image[1] + ")"
							: row.preview.replace(/\s+/g, " ")
					}
				}

				HoverSelect {
					enabled: !list.moving
					onSelected: win.currentIndex = row.index
				}

				MouseArea {
					anchors.fill: parent
					onClicked: {
						win.currentIndex = row.index;
						win.activate();
					}
				}
			}
		}

		Text {
			visible: win.filtered.length === 0
			anchors.centerIn: list
			font.family: Theme.fontFamily
			font.pixelSize: Theme.fontSizeSmall
			color: Theme.textDim
			text: win.listFailed ? "cliphist failed — is it installed?" : (win.entries.length === 0 ? "No clipboard entries" : "No match")
		}

		Rectangle {
			id: previewPane
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
				id: previewImg
				anchors.fill: parent
				anchors.margins: 12
				visible: win.currentIsImage && win.decodedId === (win.currentEntry ? win.currentEntry.id : "")
				source: visible ? "file://" + win.runDir + "/clipboard-preview" : ""
				fillMode: Image.PreserveAspectFit
				asynchronous: true
				cache: false
				mipmap: true
			}

			Flickable {
				id: previewFlick
				anchors.fill: parent
				anchors.margins: 14
				visible: !win.currentIsImage
				contentWidth: width
				contentHeight: previewText.implicitHeight
				clip: true
				flickableDirection: Flickable.VerticalFlick

				ScrollBar.vertical: ThinScrollBar {}

				WheelScroll {
					flickable: previewFlick
				}

				Text {
					id: previewText
					width: previewFlick.width - ((previewFlick.ScrollBar.vertical && previewFlick.ScrollBar.vertical.visible) ? 10 : 0)
					wrapMode: Text.WrapAtWordBoundaryOrAnywhere
					textFormat: Text.PlainText
					text: {
						var e = win.currentEntry;
						if (!e)
							return "";
						if (win.decodedId === String(e.id))
							return win.decodedText;
						return e.preview;
					}
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeSmall
					color: Theme.textMain
				}
			}
		}
	}
}
