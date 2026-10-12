// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: QML bridge to space daemon for daily checklist game locks. 2026-10-12.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
	id: root

	property bool enabled: true
	property bool unlocked: false
	property string day: ""
	property int done: 0
	property int total: 0
	property var tasks: []
	property var locks: []

	readonly property string summaryText: unlocked
		? ("Clear · " + done + "/" + total)
		: ("Locked · " + done + "/" + total)

	signal updated()

	function applyPayload(obj) {
		if (!obj)
			return;
		enabled = obj.enabled !== undefined ? !!obj.enabled : enabled;
		unlocked = !!obj.unlocked;
		day = obj.day || day;
		done = Number(obj.done) || 0;
		total = Number(obj.total) || 0;
		if (Array.isArray(obj.tasks))
			tasks = obj.tasks.slice();
		if (Array.isArray(obj.locks))
			locks = obj.locks.slice();
		updated();
	}

	function handleLine(line) {
		const trimmed = (line || "").trim();
		if (!trimmed)
			return;
		try {
			applyPayload(JSON.parse(trimmed));
		} catch (e) {
			ShellState.logWarn("SpaceBridge parse error:", e, trimmed);
		}
	}

	function refreshStatus() {
		if (ShellState.performanceMode)
			return;
		statusProc.running = true;
	}

	// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Freeze space subscribe Process during performance mode. 2026-10-12.
	Process {
		id: subProc
		running: !ShellState.performanceMode
		command: ["space", "subscribe"]
		stdout: SplitParser {
			onRead: line => root.handleLine(line)
		}
		onExited: () => {
			if (ShellState.performanceMode)
				return;
			reconnectTimer.restart();
			root.refreshStatus();
		}
	}

	Timer {
		id: reconnectTimer
		interval: 800
		repeat: false
		onTriggered: {
			if (ShellState.performanceMode)
				return;
			if (!subProc.running)
				subProc.running = true;
		}
	}
	// LLM PROMPT [end]

	Process {
		id: statusProc
		command: ["space", "--json", "status"]
		stdout: StdioCollector {
			onStreamFinished: {
				const trimmed = (text || "").trim();
				if (!trimmed)
					return;
				try {
					const obj = JSON.parse(trimmed);
					if (obj && obj.ok !== false)
						root.applyPayload(obj);
				} catch (e) {
				}
			}
		}
	}

	function toggle() {
		if (ShellState.performanceMode)
			return;
		Quickshell.execDetached(["space", "toggle"]);
	}

	function toggleTask(taskId) {
		if (ShellState.performanceMode)
			return;
		Quickshell.execDetached(["space", "toggle-task", String(taskId)]);
	}

	function setTask(taskId, done) {
		if (ShellState.performanceMode)
			return;
		Quickshell.execDetached(["space", "set-task", String(taskId), done ? "true" : "false"]);
	}

	// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Add/rename/remove daily space checklist tasks. 2026-10-12.
	function addTask(label) {
		if (ShellState.performanceMode)
			return;
		const text = String(label || "").trim();
		if (!text)
			return;
		Quickshell.execDetached(["space", "add-task", text]);
	}

	function renameTask(taskId, label) {
		if (ShellState.performanceMode)
			return;
		const text = String(label || "").trim();
		if (!taskId || !text)
			return;
		Quickshell.execDetached(["space", "rename-task", String(taskId), text]);
	}

	function removeTask(taskId) {
		if (ShellState.performanceMode || !taskId)
			return;
		Quickshell.execDetached(["space", "remove-task", String(taskId)]);
	}
	// LLM PROMPT [end]

	function reset() {
		if (ShellState.performanceMode)
			return;
		Quickshell.execDetached(["space", "reset"]);
	}

	function openNotes() {
		ShellState.setPanel("notes");
	}

	Component.onCompleted: {
		if (!ShellState.performanceMode)
			root.refreshStatus();
	}
}
// LLM PROMPT [end]
