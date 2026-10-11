// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: QML bridge to zend for zen-mode app limits. 2026-10-11.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
	id: root

	property bool enabled: false
	property var apps: []
	property var clients: []

	signal updated()

	function applyPayload(obj) {
		if (!obj)
			return;
		enabled = !!obj.enabled;
		apps = Array.isArray(obj.apps) ? obj.apps : apps;
		if (Array.isArray(obj.clients))
			clients = obj.clients;
		updated();
	}

	function handleLine(line) {
		const trimmed = (line || "").trim();
		if (!trimmed)
			return;
		try {
			applyPayload(JSON.parse(trimmed));
		} catch (e) {
			console.warn("ZenBridge parse error:", e, trimmed);
		}
	}

	Process {
		id: subProc
		running: true
		command: ["zen", "subscribe"]
		stdout: SplitParser {
			onRead: line => root.handleLine(line)
		}
	}

	function toggle() {
		Quickshell.execDetached(["zen", "toggle"]);
	}

	function setEnabled(on) {
		Quickshell.execDetached(["zen", on ? "on" : "off"]);
	}

	function add(appClass, duration) {
		Quickshell.execDetached(["zen", "add", String(appClass), String(duration)]);
	}

	function addActive(duration) {
		Quickshell.execDetached(["zen", "add-active", String(duration)]);
	}

	function remove(appClass) {
		Quickshell.execDetached(["zen", "remove", String(appClass)]);
	}

	function reset(appClass) {
		Quickshell.execDetached(["zen", "reset", String(appClass || "all")]);
	}

	function refreshClients() {
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
}
// LLM PROMPT [end]
