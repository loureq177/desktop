import "../.."
import "../../widgets"
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls

// The clipboard history (cliphist), newest first: a card an entry, showing what it holds,
// the first lines of a text or the image itself. Tab opens the picked one whole, in place
// of the list; Enter pastes it, the card's X or Delete deletes it, Clear all under the list.
LauncherPane {
	id: pane

	property var entries: []
	property bool failed: false
	// The list is in, its first cards' contents with it: nothing jumps once shown.
	property bool loaded: false
	// The cards' contents by id: { text, lines, chars } for a text, { image: true } once
	// the image is in thumbDir.
	property var snippets: ({})
	// The picked entry whole, in place of the list.
	property bool expanded: false

	icon: "clipboard"
	placeholder: "Search copied items…"
	preferredHeight: Theme.listHeight

	readonly property var items: entries.filter(e => e.preview.toLowerCase().includes(query.trim().toLowerCase()))
	readonly property alias count: list.count
	readonly property var current: items[list.currentIndex] ?? null
	readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
	readonly property string previewPath: runtimeDir + "/clipboard-preview"
	readonly property string thumbDir: runtimeDir + "/clipboard-cards"
	readonly property alias wipeArmed: wipeConfirm.armed

	// What `current` holds whole, once decoded into previewPath: the image shown
	// from there, the text read back. Only while expanded.
	property string decodedId: ""
	property string decodedText: ""

	// cliphist lists an image as "[[ binary data 12 KiB png 640x480 ]]":
	// [size, unit, format, dimensions], or null for text.
	function imageInfo(preview: string): var {
		var m = preview.match(/binary data (\d+(?:\.\d+)?) ([KMG]?i?B) (png|jpe?g|webp|gif|bmp) (\d+x\d+)/);
		return m ? m.slice(1) : null;
	}

	// A text as a card shows it: tabs as spaces, no blank lines around it.
	function tidy(text: string): string {
		return text.replace(/\t/g, "    ").replace(/^\s*\n/, "").replace(/\s+$/, "");
	}

	function link(text: string): string {
		var m = text.trim().match(/^https?:\/\/([^\/\s]+)\S*$/);
		return m ? m[1].replace(/^www\./, "") : "";
	}

	// The card's small line: what it is, how big.
	function meta(entry: var, snip: var): string {
		var img = imageInfo(entry.preview);
		if (img)
			return img[2].toUpperCase() + " · " + img[3].replace("x", "×") + " · " + img[0] + " " + img[1];
		if (!snip)
			return "";
		var host = link(snip.text);
		if (host !== "")
			return "Link · " + host;
		if (snip.lines > 1)
			return snip.lines + " lines · " + snip.chars + " characters";
		return snip.chars === 1 ? "1 character" : snip.chars + " characters";
	}

	function kindIcon(entry: var, snip: var): string {
		if (imageInfo(entry.preview))
			return "image";
		return snip && link(snip.text) !== "" ? "globe" : "text";
	}

	function opened(): void {
		failed = false;
		listProc.running = true;
	}

	// The window shut, or another list took its place: the decoded files go (the texts'
	// first lines stay), and the next time starts at the newest entry, the list.
	function closed(): void {
		wipeConfirm.reset();
		decoder.running = false;
		decodedId = "";
		expanded = false;
		list.currentIndex = 0;
		var texts = {};
		for (const id in snippets)
			if (!snippets[id].image)
				texts[id] = snippets[id];
		snippets = texts;
		Quickshell.execDetached(["rm", "-rf", previewPath, thumbDir]);
	}

	function step(delta: int, repeat: bool): void {
		list.step(delta, repeat);
	}

	// Tab: the picked entry whole, or back to the list.
	function tab(delta: int, repeat: bool): void {
		if (!repeat && current)
			expanded = !expanded;
	}

	function back(): bool {
		if (!expanded)
			return false;
		expanded = false;
		return true;
	}

	function activate(): void {
		list.activate();
	}

	function removeValue(): void {
		if (current)
			remove(current);
	}

	// Drops one entry; the card the keyboard is on stays.
	function remove(entry: var): void {
		Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", entry.id]);
		var keep = list.currentIndex;
		entries = entries.filter(e => e.id !== entry.id);
		list.currentIndex = Math.min(keep, list.count - 1);
		if (list.count === 0)
			expanded = false;
	}

	// The first click arms it, the second wipes the history.
	function wipe(): void {
		if (!wipeConfirm.ask("wipe"))
			return;
		Quickshell.execDetached(["cliphist", "wipe"]);
		entries = [];
		expanded = false;
	}

	onQueryChanged: list.currentIndex = 0
	onCurrentChanged: Qt.callLater(decoder.decode)
	onExpandedChanged: Qt.callLater(decoder.decode)

	Confirm {
		id: wipeConfirm
	}

	// Nothing copied yet is no failure: cliphist has no database until the first copy.
	// The first cards' contents come before the list shows them, so no card grows in sight.
	Process {
		id: listProc
		command: ["cliphist", "list"]
		onExited: code => pane.failed = code !== 0 && !listErr.text.includes("store something first")
		stderr: StdioCollector {
			id: listErr
		}
		stdout: StdioCollector {
			onStreamFinished: {
				var all = this.text.split("\n").filter(l => l.includes("\t")).map(l => {
					var tab = l.indexOf("\t");
					return { id: l.substring(0, tab), preview: l.substring(tab + 1) };
				});
				snipper.then = () => {
					pane.entries = all;
					pane.loaded = true;
				};
				all.slice(0, 12).forEach(e => pane.want(e));
				if (!snipper.running && snipper.wanted.length === 0)
					snipper.then();
			}
		}
	}

	// A card's contents, asked once it is made.
	function want(entry: var): void {
		if (snippets[entry.id] !== undefined || snipper.wanted.some(w => w.id === entry.id))
			return;
		snipper.wanted = snipper.wanted.concat([entry]);
		Qt.callLater(snipper.next);
	}

	// The cards' contents, a batch at a time: a text's first 1200 bytes with its line and
	// character counts, an image into thumbDir.
	Process {
		id: snipper

		property var wanted: []
		property var batch: []
		// Run once the batch in hand is in (the list waiting for its first cards).
		property var then: null

		function next(): void {
			if (running || wanted.length === 0)
				return;
			batch = wanted.slice(0, 16);
			wanted = wanted.slice(16);
			command = ["sh", "-c", 'dir=$1; shift; mkdir -p "$dir"; for e; do id=${e#i}; '
				+ 'if [ "$e" != "$id" ]; then cliphist decode "$id" > "$dir/$id"; printf "\\036%s\\037i\\037\\037" "$id"; '
				+ 'else f="$dir/$id.txt"; cliphist decode "$id" > "$f"; '
				+ 'printf "\\036%s\\037%s\\037%s\\037" "$id" "$(awk "END { print NR }" "$f")" "$(wc -m < "$f")"; '
				+ 'head -c 1200 "$f"; rm -f "$f"; fi; done', "sh", pane.thumbDir]
				.concat(batch.map(e => (pane.imageInfo(e.preview) ? "i" : "") + e.id));
			running = true;
		}

		onExited: {
			var got = Object.assign({}, pane.snippets);
			for (const rec of snipOut.text.split("\x1e").slice(1)) {
				const parts = rec.split("\x1f");
				if (parts.length < 4)
					continue;
				got[parts[0]] = parts[1] === "i" ? { image: true } : { text: parts.slice(3).join("\x1f"), lines: Number(parts[1]), chars: Number(parts[2]) };
			}
			// One that failed is not asked again.
			for (const e of batch)
				if (got[e.id] === undefined)
					got[e.id] = { text: "", lines: 0, chars: 0 };
			pane.snippets = got;
			batch = [];
			if (then && wanted.length === 0) {
				const done = then;
				then = null;
				done();
			}
			Qt.callLater(next);
		}

		stdout: StdioCollector {
			id: snipOut
		}
	}

	// One decode at a time, of the picked entry while it is open whole; images go to
	// previewPath and load off the GUI thread. Not a FileView: its text() after reload() is stale.
	Process {
		id: decoder

		property string entryId: ""
		property bool image: false

		function decode(): void {
			var e = pane.current;
			if (running || !pane.visible || !pane.expanded || !e || e.id === pane.decodedId)
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
		anchors.right: parent.right
		anchors.bottomMargin: 6
		spacing: 6
		wrap: true
		highlightOver: true
		model: pane.loaded ? pane.items : []
		opacity: pane.expanded ? 0 : 1
		visible: opacity > 0
		cacheBuffer: 600

		Behavior on opacity {
			NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
		}

		onActivated: index => {
			var entry = pane.items[index];
			var img = pane.imageInfo(entry.preview);
			Panels.close("launcher");
			Quickshell.execDetached([Commands.bin + "clipboard-insert", entry.id].concat(img ? ["image/" + img[2].toLowerCase().replace("jpg", "jpeg")] : []));
		}

		delegate: ListRow {
			id: card

			required property var modelData
			readonly property var image: pane.imageInfo(modelData.preview)
			readonly property var snip: pane.snippets[modelData.id] ?? null

			height: body.height + 24
			color: Theme.glass(Theme.bgMain)
			border.color: Theme.tileBorder
			border.width: 1

			Component.onCompleted: pane.want(modelData)

			Column {
				id: body
				x: 14
				y: 12
				width: parent.width - 28
				spacing: 8

				// The text as it was copied, its first lines; clear of the corner's buttons
				// whether they show or not, so a card keeps its height under the pointer.
				StyledText {
					visible: !card.image
					width: parent.width - tools.width
					text: card.snip ? pane.tidy(card.snip.text) : card.modelData.preview
					textFormat: Text.PlainText
					wrapMode: Text.WrapAtWordBoundaryOrAnywhere
					maximumLineCount: 4
					elide: Text.ElideRight
					mono: true
					font.pixelSize: Theme.fontSizeSmall
				}

				// The image itself, small.
				Rectangle {
					readonly property var size: card.image ? card.image[3].split("x").map(Number) : [1, 1]
					visible: card.image !== null
					height: 104
					width: Math.min(parent.width - tools.width, height * size[0] / Math.max(1, size[1]))
					radius: Theme.roundingSubtle
					color: Theme.glass(Theme.bgCard)
					clip: true

					Image {
						anchors.fill: parent
						source: card.snip?.image ? "file://" + pane.thumbDir + "/" + card.modelData.id : ""
						fillMode: Image.PreserveAspectCrop
						sourceSize.height: parent.height * 2
						asynchronous: true
						cache: false
						smooth: true
					}
				}

				Row {
					spacing: 6

					LineIcon {
						anchors.verticalCenter: parent.verticalCenter
						name: pane.kindIcon(card.modelData, card.snip)
						size: 13
						color: card.selected ? Theme.accentBlue : Theme.textDim
					}

					StyledText {
						anchors.verticalCenter: parent.verticalCenter
						text: pane.meta(card.modelData, card.snip)
						font.pixelSize: Theme.fontSizeTiny
						color: Theme.textDim
					}
				}
			}

			// In the corner, as on a notification: the whole entry, and away with it.
			Row {
				id: tools
				anchors.top: parent.top
				anchors.right: parent.right
				anchors.margins: 6
				spacing: 2
				opacity: card.hovered || card.selected ? 1 : 0
				visible: opacity > 0

				IconButton {
					icon: "maximize-2"
					iconSize: 14
					outlined: false
					implicitWidth: 28
					implicitHeight: 28
					onClicked: {
						card.view.currentIndex = card.index;
						pane.expanded = true;
					}
				}

				CloseButton {
					onClicked: pane.remove(card.modelData)
				}
			}
		}
	}

	// The whole history, on a second click.
	Item {
		id: clearBar
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.bottom: parent.bottom
		height: pane.entries.length > 0 && !pane.expanded ? 34 : 0
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
		visible: list.count === 0 && (pane.loaded || pane.failed)
		anchors.centerIn: list
		font.pixelSize: Theme.fontSizeSmall
		color: Theme.textDim
		text: pane.failed ? "cliphist failed — is it installed?" : pane.entries.length === 0 ? "No clipboard entries" : "Nothing matches"
	}

	// The picked entry whole, where the list was: Tab, Esc or its X go back, Up and Down
	// go through the others as they are.
	Rectangle {
		id: whole
		readonly property bool decoded: pane.current !== null && pane.decodedId === pane.current.id
		readonly property bool isImage: pane.current !== null && pane.imageInfo(pane.current.preview) !== null
		readonly property var snip: pane.current ? pane.snippets[pane.current.id] ?? null : null

		anchors.fill: parent
		color: Theme.glass(Theme.bgMain)
		border.color: Theme.tileBorder
		border.width: 1
		radius: Theme.roundingElement
		clip: true
		opacity: pane.expanded && pane.current ? 1 : 0
		scale: pane.expanded ? 1 : 0.98
		visible: opacity > 0

		Behavior on opacity {
			NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
		}
		Behavior on scale {
			NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
		}

		Row {
			id: head
			x: 16
			y: 12
			spacing: 8

			LineIcon {
				anchors.verticalCenter: parent.verticalCenter
				name: pane.current ? pane.kindIcon(pane.current, whole.snip) : "text"
				size: 15
				color: Theme.accentBlue
			}

			StyledText {
				anchors.verticalCenter: parent.verticalCenter
				text: !pane.current ? "" : [pane.meta(pane.current, whole.snip), pane.count > 1 ? (list.currentIndex + 1) + " of " + pane.count : ""].filter(t => t !== "").join(" · ")
				font.pixelSize: Theme.fontSizeSmall
				color: Theme.textDim
			}
		}

		Row {
			anchors.top: parent.top
			anchors.right: parent.right
			anchors.margins: 6
			spacing: 2

			CloseButton {
				icon: "x"
				danger: false
				onClicked: pane.expanded = false
			}
		}

		Image {
			anchors.fill: parent
			anchors.margins: 16
			anchors.topMargin: 48
			visible: whole.isImage && whole.decoded
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
			id: wholeFlick
			anchors.fill: parent
			anchors.margins: 16
			anchors.topMargin: 48
			visible: !whole.isImage
			contentWidth: width
			contentHeight: wholeText.implicitHeight
			clip: true
			flickableDirection: Flickable.VerticalFlick

			ScrollBar.vertical: ThinScrollBar {}

			WheelScroll {
				flickable: wholeFlick
			}

			StyledText {
				id: wholeText
				width: wholeFlick.width - (wholeFlick.ScrollBar.vertical.visible ? 10 : 0)
				wrapMode: Text.WrapAtWordBoundaryOrAnywhere
				textFormat: Text.PlainText
				text: (!pane.current ? "" : whole.decoded ? pane.decodedText : whole.snip?.text ?? pane.current.preview).replace(/\t/g, "    ")
				onTextChanged: wholeFlick.contentY = 0
				mono: true
				font.pixelSize: Theme.fontSizeSmall
			}
		}
	}
}
