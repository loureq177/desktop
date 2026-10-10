import ".."
import "../widgets"
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

CenterModal {
	id: win

	searchTitle: "Clip"
	searchPlaceholder: "Search..."

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
	property bool listFailed: false

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
		previewFlick.contentY = 0;
		previewTimer.restart();
	}

	function paste(entry) {
		if (!entry)
			return;
		var mime = "";
		var m = (entry.preview || "").match(/binary data \d+(?:\.\d+)? [KMG]?i?B (png|jpe?g|webp|gif|bmp) \d+x\d+/);
		if (m) {
			var ext = m[1].toLowerCase();
			if (ext === "jpg")
				ext = "jpeg";
			mime = "image/" + ext;
		}
		win.close();
		if (mime !== "")
			Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/clipboard-insert", String(entry.id), mime]);
		else
			Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/clipboard-insert", String(entry.id)]);
	}

	function activate() {
		paste(filtered[currentIndex]);
	}

	function open() {
		query = "";
		win.listFailed = false;
		searchBar.clear();
		listLoader.running = true;
		win.shown = true;
		searchBar.focusInput();
	}

	function close() {
		win.shown = false;
		decodeProc.running = false;
		Quickshell.execDetached(["rm", "-f", Quickshell.env("XDG_RUNTIME_DIR") + "/clipboard-preview"]);
		win.decodedText = "";
		win.decodedId = "";
		win.textReqId = "";
		win.imgReqId = "";
	}

	function toggle() {
		if (win.shown)
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
		stdout: StdioCollector {
			onStreamFinished: {
				var reqId = win.textReqId;
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
			boundsBehavior: Flickable.DragAndOvershootBounds
			flickDeceleration: Theme.flickDecel
			maximumFlickVelocity: Theme.maxFlickVel
			spacing: 2
			model: win.filtered

			delegate: Rectangle {
				id: row
				required property var modelData
				required property int index

				readonly property string preview: row.modelData?.preview ?? ""
				readonly property bool isImage: {
					return / binary data (\d+(?:\.\d+)?) [KMG]?i?B (png|jpe?g|webp|gif|bmp) (\d+x\d+)/.test(row.preview);
				}
				readonly property string thumbPath: row.isImage ? (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/clipboard-thumbs/" + String(row.modelData.id) : ""

				width: list.width
				height: 52
				clip: true
				color: row.index === win.currentIndex ? Theme.selectionBg : "transparent"
				border.color: row.index === win.currentIndex ? Theme.selectionBorder : "transparent"
				border.width: 1
				radius: Theme.roundingElement

				property bool thumbReady: false

				Behavior on color { ColorAnimation { duration: 100 } }

				Process {
					id: thumbLoader
					running: row.isImage
					command: [
						"sh", "-c",
						'f="$1"; [ -s "$f" ] || { mkdir -p "$2" && cliphist decode "$3" | magick - -thumbnail 120x80 "$f"; }',
						"sh",
						row.thumbPath,
						(Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/clipboard-thumbs",
						String(row.modelData.id)
					]
					onExited: function (exitCode) {
						row.thumbReady = (exitCode === 0);
					}
				}

				RowLayout {
					anchors.fill: parent
					anchors.leftMargin: 10
					anchors.rightMargin: 10
					spacing: 10

					Rectangle {
						visible: row.isImage
						Layout.preferredWidth: 56
						Layout.preferredHeight: 34
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

					Text {
						visible: !row.isImage
						Layout.alignment: Qt.AlignVCenter
						text: "󰅌"
						font.family: Theme.fontFamily
						font.pixelSize: 14
						color: row.index === win.currentIndex ? Theme.accentBlue : Theme.textDim
					}

					Text {
						Layout.fillWidth: true
						Layout.alignment: Qt.AlignVCenter
						textFormat: Text.PlainText
						font.family: Theme.fontMono
						font.pixelSize: 13
						color: row.index === win.currentIndex ? Theme.accentBlue : Theme.textMain
						elide: Text.ElideRight
						text: {
							var p = row.preview;
							if (row.isImage) {
								var m = p.match(/binary data (\d+(?:\.\d+)?) ([KMG]?i?B) (png|jpe?g|webp|gif|bmp) (\d+x\d+)/);
								if (m)
									return "Image (" + m[3].toUpperCase() + " " + m[4] + ", " + m[1] + " " + m[2] + ")";
								return "Image";
							}
							return p.replace(/\s+/g, " ");
						}
					}
				}

				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					onEntered: {
						if (!list.moving && !list.flicking)
							win.currentIndex = row.index;
					}
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
			font.family: Theme.fontMono
			font.pointSize: Theme.fontSizeBar
			color: Theme.textDim
			text: win.listFailed ? "cliphist failed — is it installed?" : (win.entries.length === 0 ? "No clipboard entries" : "No match")
		}

		Rectangle {
			id: previewPane
			anchors.top: parent.top
			anchors.bottom: parent.bottom
			anchors.right: parent.right
			width: parent.width * 0.58 - Theme.paddingItem
			color: Theme.bgCard
			border.color: Theme.border
			border.width: 1
			radius: Theme.roundingElement
			clip: true

			Image {
				id: previewImg
				anchors.fill: parent
				anchors.margins: 12
				visible: win.currentIsImage && win.decodedId === (win.currentEntry ? win.currentEntry.id : "")
				source: visible ? "file://" + (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/clipboard-preview" : ""
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
				boundsBehavior: Flickable.DragAndOvershootBounds
				flickableDirection: Flickable.VerticalFlick
				flickDeceleration: Theme.flickDecel
				maximumFlickVelocity: Theme.maxFlickVel

				ScrollBar.vertical: ScrollBar {
					visible: previewFlick.contentHeight > previewFlick.height
					policy: ScrollBar.AsNeeded
					contentItem: Rectangle {
						implicitWidth: 4
						radius: Theme.roundingSubtle
						color: parent.hovered || parent.pressed ? Theme.textDim : Theme.border
					}
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
					font.pixelSize: 16
					color: Theme.textMain
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
