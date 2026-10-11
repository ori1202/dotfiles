// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Timer panel with presets, controls, and always-on-top toggle. 2026-10-10.
import QtQuick
import qs
import qs.components
import qs.services

FocusScope {
    id: root

    readonly property var presets: [
        { "label": "1m", "duration": "1m" },
        { "label": "5m", "duration": "5m" },
        { "label": "10m", "duration": "10m" },
        { "label": "15m", "duration": "15m" },
        { "label": "25m", "duration": "25m" },
        { "label": "45m", "duration": "45m" }
    ]

    function takeInitialFocus() {
        if (TimerBridge.running) {
            stopButton.forceActiveFocus(Qt.TabFocusReason);
            return;
        }
        if (presetRepeater.count > 0) {
            const item = presetRepeater.itemAt(0);
            if (item)
                item.forceActiveFocus(Qt.TabFocusReason);
        }
    }

    function startPreset(duration) {
        TimerBridge.start(duration, "");
    }

    implicitWidth: 320
    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: 12

        Row {
            width: parent.width
            height: 36
            spacing: 10

            ShellText {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰔟"
                font.pixelSize: 18
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40
                spacing: 2

                ShellText {
                    text: TimerBridge.running ? (TimerBridge.label || "Timer") : "Timer"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                ShellText {
                    text: TimerBridge.running
                        ? ((TimerBridge.paused ? "Paused · " : "") + TimerBridge.remainingText)
                        : "Pick a preset to start"
                    color: Theme.muted
                    font.pixelSize: 11
                }
            }
        }

        Flow {
            width: parent.width
            spacing: 7

            Repeater {
                id: presetRepeater
                model: root.presets

                IconButton {
                    required property var modelData
                    width: 48
                    height: 36
                    icon: modelData.label
                    accessibleName: "Start " + modelData.label + " timer"
                    backgroundColor: Theme.bg0
                    hoverBackgroundColor: Theme.primary
                    hoverForegroundColor: Theme.bgDim
                    onClicked: root.startPreset(modelData.duration)
                }
            }
        }

        Row {
            width: parent.width
            spacing: 7
            visible: TimerBridge.running || TimerBridge.paused

            IconButton {
                id: pauseButton
                width: (parent.width - 14) / 3
                height: 40
                icon: TimerBridge.paused ? "▶" : "⏸"
                accessibleName: TimerBridge.paused ? "Resume timer" : "Pause timer"
                onClicked: TimerBridge.paused ? TimerBridge.resume() : TimerBridge.pause()
            }

            IconButton {
                id: stopButton
                width: (parent.width - 14) / 3
                height: 40
                icon: "■"
                accessibleName: "Stop timer"
                onClicked: TimerBridge.stop()
            }

            IconButton {
                width: (parent.width - 14) / 3
                height: 40
                icon: "+1m"
                accessibleName: "Add one minute"
                onClicked: {
                    const next = Math.max(1, TimerBridge.remaining + 60);
                    TimerBridge.start(String(next) + "s", TimerBridge.label || "");
                }
            }
        }

        ActionTile {
            width: parent.width
            icon: ShellState.timerAlwaysOnTop ? "󰔟" : "󰔛"
            title: "Always on top"
            subtitle: ShellState.timerAlwaysOnTop
                ? "Timer stays above windows"
                : "Windows can cover the timer"
            active: ShellState.timerAlwaysOnTop
            expandable: false
            onClicked: ShellState.timerAlwaysOnTop = !ShellState.timerAlwaysOnTop
        }
    }
}
// LLM PROMPT [end]
