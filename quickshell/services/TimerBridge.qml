pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
	id: root

	property bool running: false
	property bool paused: false
	property string label: ""
	property int duration: 0
	property int remaining: 0
	property string lastEvent: ""

	readonly property string remainingText: {
		const s = Math.max(0, remaining);
		const h = Math.floor(s / 3600);
		const m = Math.floor((s % 3600) / 60);
		const sec = s % 60;
		if (h > 0)
			return `${h}:${String(m).padStart(2, "0")}:${String(sec).padStart(2, "0")}`;
		return `${m}:${String(sec).padStart(2, "0")}`;
	}

	signal tick(int remaining)
	signal started()
	signal stopped()
	signal done()
	signal updated()

	function applyPayload(obj) {
		if (!obj)
			return;
		running = !!obj.running;
		paused = !!obj.paused;
		label = obj.label || "";
		duration = obj.duration || 0;
		remaining = obj.remaining || 0;
		lastEvent = obj.event || lastEvent;
		updated();

		if (obj.event === "tick" || obj.event === "status" || obj.event === "started" || obj.event === "resumed" || obj.event === "paused")
			tick(remaining);
		if (obj.event === "started")
			started();
		if (obj.event === "stopped")
			stopped();
		if (obj.event === "done")
			done();
	}

	function handleLine(line) {
		const trimmed = (line || "").trim();
		if (!trimmed)
			return;
		try {
			applyPayload(JSON.parse(trimmed));
		} catch (e) {
			ShellState.logWarn("TimerBridge parse error:", e, trimmed);
		}
	}

	// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Freeze timer subscribe Process during performance mode. 2026-10-12.
	Process {
		id: subProc
		running: !ShellState.performanceMode
		command: ["timer", "subscribe"]
		stdout: SplitParser {
			onRead: line => root.handleLine(line)
		}
	}
	// LLM PROMPT [end]

	function start(duration, label) {
		if (ShellState.performanceMode)
			return;
		const cmd = ["timer", "start", String(duration)];
		if (label)
			cmd.push("-l", String(label));
		// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Use execDetached for timer CLI actions. 2026-10-10.
		Quickshell.execDetached(cmd);
	}

	function stop() {
		if (ShellState.performanceMode)
			return;
		Quickshell.execDetached(["timer", "stop"]);
	}

	function pause() {
		if (ShellState.performanceMode)
			return;
		Quickshell.execDetached(["timer", "pause"]);
	}

	function resume() {
		if (ShellState.performanceMode)
			return;
		Quickshell.execDetached(["timer", "resume"]);
		// LLM PROMPT [end]
	}
}
