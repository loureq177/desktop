pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// The default output and input. Their `audio` holds the volume (0..1) and
// mute, with real values once the node is `ready`.
Singleton {
	id: root

	readonly property PwNode sink: Pipewire.defaultAudioSink
	readonly property PwNode source: Pipewire.defaultAudioSource
	readonly property bool ready: sink?.ready ?? false
	readonly property bool muted: sink?.audio?.muted ?? false
	// Percent.
	readonly property int volume: Math.round(Math.min(1, sink?.audio?.volume ?? 0) * 100)
	readonly property string icon: muted ? "volume-x" : volume <= 1 ? "volume" : volume <= 50 ? "volume-1" : "volume-2"

	function setVolume(percent: real): void {
		if (!sink?.audio)
			return;
		sink.audio.volume = Math.max(0, Math.min(100, Math.round(percent))) / 100;
		volumeSound.restart();
	}

	function toggleMute(): void {
		if (sink?.audio)
			sink.audio.muted = !sink.audio.muted;
	}

	PwObjectTracker {
		objects: [root.sink, root.source].filter(n => n)
	}

	// One click once a drag or a run of key presses settles.
	Timer {
		id: volumeSound
		interval: 120
		onTriggered: {
			if (!root.muted)
				Quickshell.execDetached(["canberra-gtk-play", "-i", "audio-volume-change"]);
		}
	}
}
