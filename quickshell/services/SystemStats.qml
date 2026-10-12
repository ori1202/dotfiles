pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
	id: root

	property real cpuTemp: 0
	property int cpuUsage: 0
	property int cpuCores: 0
	property int memUsed: 0
	property int memTotal: 0
	property int memPct: 0
	property real gpuTemp: 0
	property int gpuUsage: 0
	property int gpuMemUsed: 0
	property int gpuMemTotal: 0
	property string gpuName: ""
	property bool gpuAvailable: false
	property bool ready: false

	readonly property string cpuTempText: ready && cpuTemp > 0 ? Math.round(cpuTemp) + "°C" : "--"
	readonly property string gpuTempText: gpuAvailable ? Math.round(gpuTemp) + "°C" : "--"
	readonly property string cpuSubtitle: ShellState.performanceMode
		? "Paused"
		: (ready ? (cpuUsage + "% · " + memPct + "% RAM") : "Reading…")
	readonly property string gpuSubtitle: ShellState.performanceMode
		? "Paused"
		: (gpuAvailable ? (gpuUsage + "% · " + gpuMemUsed + "/" + gpuMemTotal + " MiB") : "No GPU sensor")

	function refresh() {
		if (ShellState.performanceMode)
			return;
		if (!statsProc.running)
			statsProc.running = true;
	}

	// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Stop sys-stats Process polling while performance mode is on. 2026-10-12.
	Process {
		id: statsProc
		command: [Quickshell.shellPath("scripts/sys-stats.sh")]
		running: !ShellState.performanceMode
		stdout: SplitParser {
			onRead: data => {
				if (ShellState.performanceMode)
					return;
				try {
					const obj = JSON.parse(String(data).trim());
					root.cpuTemp = Number(obj.cpuTemp) || 0;
					root.cpuUsage = Number(obj.cpuUsage) || 0;
					root.cpuCores = Number(obj.cpuCores) || 0;
					root.memUsed = Number(obj.memUsed) || 0;
					root.memTotal = Number(obj.memTotal) || 0;
					root.memPct = Number(obj.memPct) || 0;
					root.gpuTemp = Number(obj.gpuTemp) || 0;
					root.gpuUsage = Number(obj.gpuUsage) || 0;
					root.gpuMemUsed = Number(obj.gpuMemUsed) || 0;
					root.gpuMemTotal = Number(obj.gpuMemTotal) || 0;
					root.gpuName = obj.gpuName || "";
					root.gpuAvailable = obj.gpuTemp !== null && obj.gpuTemp !== undefined;
					root.ready = true;
				} catch (e) {
					ShellState.logWarn("SystemStats parse error:", e);
				}
			}
		}
	}

	Timer {
		interval: 2000
		running: !ShellState.performanceMode
		repeat: true
		onTriggered: root.refresh()
	}
	// LLM PROMPT [end]
}
