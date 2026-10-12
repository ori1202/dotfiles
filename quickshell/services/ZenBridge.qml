// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: QML bridge to zend for zen-mode app limits. 2026-10-11.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
	id: root

	property bool enabled: false
	property var apps: []
	property var clients: []
	// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Expose daily focused-app usage from zend. 2026-10-12.
	property var usage: []
	// LLM PROMPT [end]

	signal updated()

	function applyPayload(obj) {
		if (!obj)
			return;
		enabled = !!obj.enabled;
		if (Array.isArray(obj.apps))
			apps = obj.apps.slice();
		if (Array.isArray(obj.clients))
			clients = obj.clients;
		if (Array.isArray(obj.usage))
			usage = obj.usage.slice();
		updated();
	}

	readonly property int usageTotal: {
		let total = 0;
		for (let i = 0; i < usage.length; i++)
			total += Math.max(0, Number(usage[i].seconds) || 0);
		return total;
	}

	readonly property var usageChart: {
		const rows = [];
		const total = Math.max(1, usageTotal);
		const limit = Math.min(6, usage.length);
		for (let i = 0; i < limit; i++) {
			const item = usage[i];
			const seconds = Math.max(0, Number(item.seconds) || 0);
			rows.push({
				"class": item.class || "?",
				"seconds": seconds,
				"share": seconds / total,
				"label": remainingText(seconds)
			});
		}
		return rows;
	}

	function handleLine(line) {
		const trimmed = (line || "").trim();
		if (!trimmed)
			return;
		try {
			applyPayload(JSON.parse(trimmed));
		} catch (e) {
			ShellState.logWarn("ZenBridge parse error:", e, trimmed);
		}
	}

	function refreshStatus() {
		if (ShellState.performanceMode)
			return;
		statusProc.running = true;
	}

	function reconnectSubscribe() {
		if (ShellState.performanceMode)
			return;
		if (subProc.running)
			subProc.running = false;
		reconnectTimer.restart();
	}

	// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Freeze zen subscribe Process during performance mode. 2026-10-12.
	Process {
		id: subProc
		running: !ShellState.performanceMode
		command: ["zen", "subscribe"]
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
		command: ["zen", "--json", "status"]
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
					// CLI may print human text; ignore — subscribe will update.
				}
			}
		}
	}

	function toggle() {
		if (ShellState.performanceMode)
			return;
		Quickshell.execDetached(["zen", "toggle"]);
	}

	function setEnabled(on) {
		if (ShellState.performanceMode)
			return;
		Quickshell.execDetached(["zen", on ? "on" : "off"]);
	}

	function add(appClass, duration) {
		if (ShellState.performanceMode)
			return;
		Quickshell.execDetached(["zen", "add", String(appClass), String(duration)]);
	}

	function addActive(duration) {
		if (ShellState.performanceMode)
			return;
		Quickshell.execDetached(["zen", "add-active", String(duration)]);
	}

	function remove(appClass) {
		if (ShellState.performanceMode)
			return;
		Quickshell.execDetached(["zen", "remove", String(appClass)]);
	}

	function reset(appClass) {
		if (ShellState.performanceMode)
			return;
		Quickshell.execDetached(["zen", "reset", String(appClass || "all")]);
	}

	function refreshClients() {
		if (ShellState.performanceMode)
			return;
		clientsProc.running = true;
	}

	Process {
		id: clientsProc
		command: ["zen", "clients"]
		stdout: StdioCollector {
			onStreamFinished: {
				const lines = text.split(/\n/).map(s => s.trim()).filter(s => s.length > 0);
				root.clients = lines;
				root.updated();
			}
		}
	}

	function remainingText(seconds) {
		const s = Math.max(0, Number(seconds) || 0);
		const h = Math.floor(s / 3600);
		const m = Math.floor((s % 3600) / 60);
		const sec = Math.floor(s % 60);
		if (h > 0)
			return `${h}:${String(m).padStart(2, "0")}:${String(sec).padStart(2, "0")}`;
		return `${m}:${String(sec).padStart(2, "0")}`;
	}

	Component.onCompleted: {
		if (!ShellState.performanceMode)
			root.refreshStatus();
	}
}
// LLM PROMPT [end]
