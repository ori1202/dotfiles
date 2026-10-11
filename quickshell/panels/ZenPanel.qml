// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Zen mode panel for per-app kill timers. 2026-10-11.
import QtQuick
import qs
import qs.components
import qs.services

FocusScope {
    id: root

    readonly property var presets: [
        { "label": "15m", "duration": "15m" },
        { "label": "30m", "duration": "30m" },
        { "label": "1h", "duration": "1h" },
        { "label": "2h", "duration": "2h" },
        { "label": "3h", "duration": "3h" }
    ]

    function takeInitialFocus() {
        zenToggle.forceActiveFocus(Qt.TabFocusReason);
    }

    Component.onCompleted: ZenBridge.refreshClients()

    Connections {
        target: ShellState
        function onPanelChanged() {
            if (ShellState.panel === "zen")
                ZenBridge.refreshClients();
        }
    }

    implicitWidth: 360
    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: 12

        ActionTile {
            id: zenToggle
            width: parent.width
            icon: ZenBridge.enabled ? "ON" : "OFF"
            title: "Zen mode"
            subtitle: ZenBridge.enabled
                ? "Limits active — apps die when time runs out"
                : "Off — timers paused"
            active: ZenBridge.enabled
            expandable: false
            onClicked: ZenBridge.toggle()
        }

        ShellText {
            text: "Limit focused app"
            font.pixelSize: 12
            font.weight: Font.Bold
        }

        Flow {
            width: parent.width
            spacing: 7

            Repeater {
                model: root.presets

                IconButton {
                    required property var modelData
                    width: 52
                    height: 36
                    icon: modelData.label
                    accessibleName: "Limit focused app for " + modelData.label
                    backgroundColor: Theme.bg0
                    hoverBackgroundColor: Theme.primary
                    hoverForegroundColor: Theme.bgDim
                    onClicked: ZenBridge.addActive(modelData.duration)
                }
            }
        }

        ShellText {
            text: "Open apps"
            font.pixelSize: 12
            font.weight: Font.Bold
            visible: ZenBridge.clients.length > 0
        }

        Flow {
            width: parent.width
            spacing: 7
            visible: ZenBridge.clients.length > 0

            Repeater {
                model: ZenBridge.clients

                IconButton {
                    required property var modelData
                    width: Math.min(120, Math.max(64, modelData.length * 8 + 24))
                    height: 36
                    icon: modelData.length > 12 ? modelData.slice(0, 11) + "…" : modelData
                    accessibleName: "Limit " + modelData
                    backgroundColor: Theme.bg0
                    hoverBackgroundColor: Theme.primary
                    hoverForegroundColor: Theme.bgDim
                    onClicked: ZenBridge.add(modelData, "1h")
                }
            }
        }

        ShellText {
            text: "Active limits"
            font.pixelSize: 12
            font.weight: Font.Bold
        }

        Column {
            width: parent.width
            spacing: 7

            Repeater {
                model: ZenBridge.apps

                Rectangle {
                    required property var modelData
                    width: parent.width
                    height: 52
                    radius: Theme.radiusSmall
                    color: modelData.expired ? Theme.red : (modelData.running ? Theme.primaryContainer : Theme.bg0)

                    Row {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 88
                            spacing: 2

                            ShellText {
                                width: parent.width
                                text: modelData.class || "?"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }

                            ShellText {
                                width: parent.width
                                text: ZenBridge.remainingText(modelData.remaining)
                                      + " left · "
                                      + (modelData.running ? "open" : "closed")
                                color: Theme.muted
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36
                            height: 36
                            icon: "↺"
                            accessibleName: "Reset " + modelData.class
                            onClicked: ZenBridge.reset(modelData.class)
                        }

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36
                            height: 36
                            icon: "✕"
                            accessibleName: "Remove " + modelData.class
                            onClicked: ZenBridge.remove(modelData.class)
                        }
                    }
                }
            }

            ShellText {
                visible: ZenBridge.apps.length === 0
                text: "No limits yet — pick a preset or an open app"
                color: Theme.muted
                font.pixelSize: 11
            }
        }
    }
}
// LLM PROMPT [end]
