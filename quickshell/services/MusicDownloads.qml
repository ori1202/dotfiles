// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Prefer Firefox YouTube Music MPRIS player for download status/actions. 2026-10-11.
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import qs

Singleton {
	id: root

	readonly property string helper: Quickshell.shellPath("scripts/download-track")

	function playerUrl(player) {
		if (!player || !player.metadata)
			return "";
		const meta = player.metadata;
		return meta["xesam:url"] || meta["xesam:Url"] || "";
	}

	function isYoutubeMusicUrl(url) {
		return /(?:^https?:\/\/)?(?:www\.)?music\.youtube\.com\b/i.test(String(url || ""));
	}

	function isFirefoxPlayer(player) {
		if (!player)
			return false;
		const identity = String(player.identity || "");
		const desktop = String(player.desktopEntry || "");
		const dbusName = String(player.dbusName || "");
		return /firefox/i.test(identity) || /firefox/i.test(desktop) || /firefox/i.test(dbusName);
	}

	// Prefer Firefox music.youtube.com when present so any YT Music track can download.
	readonly property var activePlayer: {
		const players = Mpris.players.values;
		let ytPlaying = null;
		let ytAny = null;
		let firefoxPlaying = null;
		let playing = null;
		for (let i = 0; i < players.length; i++) {
			const p = players[i];
			const url = root.playerUrl(p);
			const yt = root.isYoutubeMusicUrl(url);
			const ff = root.isFirefoxPlayer(p);
			if (yt && p.isPlaying && !ytPlaying)
				ytPlaying = p;
			if (yt && !ytAny)
				ytAny = p;
			if (ff && p.isPlaying && !firefoxPlaying)
				firefoxPlaying = p;
			if (p.isPlaying && !playing)
				playing = p;
		}
		return ytPlaying || ytAny || firefoxPlaying || playing || (players.length > 0 ? players[0] : null);
	}

	readonly property var player: activePlayer
	readonly property string trackUrl: root.playerUrl(player)
	readonly property string trackTitle: player ? (player.trackTitle || "") : ""
	readonly property string trackArtist: player ? (player.trackArtist || "") : ""
	readonly property bool isYoutubeMusic: root.isYoutubeMusicUrl(trackUrl)
	readonly property bool canDownload: !!player && root.isYoutubeMusic && !!trackUrl

	property bool downloaded: false
	property string downloadedPath: ""
	property bool downloading: false
	property string statusText: ""
	property string lastAutoKey: ""
	readonly property bool autoDownload: ShellState.musicAutoDownload
	readonly property string trackKey: trackUrl + "|" + trackTitle + "|" + trackArtist

	function setAutoDownload(on) {
		ShellState.musicAutoDownload = !!on;
		if (on)
			root.maybeAutoDownload();
	}

	function toggleAutoDownload() {
		root.setAutoDownload(!root.autoDownload);
	}

	function refresh() {
		// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Skip music status/download Processes in performance mode. 2026-10-12.
		if (ShellState.performanceMode || statusProcess.running)
			return;
		// LLM PROMPT [end]
		statusProcess.exec([
			helper, "status",
			"--url", trackUrl,
			"--title", trackTitle,
			"--artist", trackArtist
		]);
	}

	function download() {
		if (ShellState.performanceMode || downloading || downloaded || !canDownload)
			return;
		downloading = true;
		statusText = "Downloading…";
		downloadProcess.exec([
			helper, "download",
			"--url", trackUrl,
			"--title", trackTitle,
			"--artist", trackArtist
		]);
	}

	function maybeAutoDownload() {
		if (ShellState.performanceMode || !autoDownload || !isYoutubeMusic || !canDownload || downloaded || downloading)
			return;
		if (trackKey === lastAutoKey || !trackUrl)
			return;
		lastAutoKey = trackKey;
		root.download();
	}

	Connections {
		target: root.player
		enabled: !!root.player && !ShellState.performanceMode
		function onTrackTitleChanged() { root.refresh(); }
		function onTrackArtistChanged() { root.refresh(); }
		function onMetadataChanged() { root.refresh(); }
		function onIsPlayingChanged() { root.refresh(); }
	}

	Connections {
		target: Mpris.players
		enabled: !ShellState.performanceMode
		function onValuesChanged() { root.refresh(); }
	}

	Process {
		id: statusProcess
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					const result = JSON.parse(text || "{}");
					root.downloaded = !!result.downloaded;
					root.downloadedPath = result.path || "";
					root.statusText = root.downloaded ? "Downloaded" : "";
					root.maybeAutoDownload();
				} catch (error) {
					root.downloaded = false;
					root.downloadedPath = "";
				}
			}
		}
	}

	Process {
		id: downloadProcess
		stdout: StdioCollector {
			onStreamFinished: {
				root.downloading = false;
				try {
					const result = JSON.parse(text || "{}");
					root.downloaded = !!result.downloaded;
					root.downloadedPath = result.path || "";
					root.statusText = root.downloaded ? "Downloaded" : (result.error || "Failed");
				} catch (error) {
					root.statusText = "Failed";
				}
			}
		}
		stderr: StdioCollector {
			onStreamFinished: {
				if (text.trim() && root.downloading) {
					root.downloading = false;
					root.statusText = "Failed";
				}
			}
		}
		onExited: (code) => {
			root.downloading = false;
			if (code === 0)
				root.refresh();
		}
	}

	Component.onCompleted: {
		if (!ShellState.performanceMode)
			refresh();
	}
}
// LLM PROMPT [end]
