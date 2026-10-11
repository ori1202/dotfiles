pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
	id: root

	readonly property real maxVolume: 1.5

	PwObjectTracker {
		objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
	}

	readonly property var sink: Pipewire.defaultAudioSink
	readonly property var source: Pipewire.defaultAudioSource

	readonly property real volume: sink?.audio?.volume ?? 0
	readonly property bool muted: sink?.audio?.muted ?? false
	readonly property int volumePercent: Math.round(volume * 100)

	readonly property real micVolume: source?.audio?.volume ?? 0
	readonly property bool micMuted: source?.audio?.muted ?? false
	readonly property int micPercent: Math.round(micVolume * 100)

	readonly property bool overamplified: !muted && volume > 1.0

	signal volumeBumped()
	signal micBumped()

	Connections {
		target: root.sink?.audio ?? null
		function onVolumeChanged() { root.volumeBumped(); }
		function onMutedChanged() { root.volumeBumped(); }
	}

	Connections {
		target: root.source?.audio ?? null
		function onVolumeChanged() { root.micBumped(); }
		function onMutedChanged() { root.micBumped(); }
	}

	function setVolume(v) {
		if (!sink?.audio)
			return;
		sink.audio.volume = Math.max(0, Math.min(maxVolume, v));
	}

	function changeVolume(delta) {
		setVolume(volume + delta);
	}

	function toggleMute() {
		if (!sink?.audio)
			return;
		sink.audio.muted = !sink.audio.muted;
	}

	function setMicVolume(v) {
		if (!source?.audio)
			return;
		source.audio.volume = Math.max(0, Math.min(1.0, v));
	}

	function changeMicVolume(delta) {
		setMicVolume(micVolume + delta);
	}

	function toggleMicMute() {
		if (!source?.audio)
			return;
		source.audio.muted = !source.audio.muted;
	}
}
