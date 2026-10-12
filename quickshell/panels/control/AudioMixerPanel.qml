// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Extracted per-app audio mixer with Pipewire stream grouping and desktop icons. 2026-10-13.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs
import qs.components

Item {
    id: root

    property real detailScrollFactor: 2

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property var audioSinks: Pipewire.nodes.values.filter((node) => {
        return node.isSink && !node.isStream && node.audio;
    }).slice().sort((left, right) => {
        if (sink && left.id === sink.id)
            return -1;
        if (sink && right.id === sink.id)
            return 1;
        return (left.description || left.nickname || left.name).localeCompare(right.description || right.nickname || right.name);
    })

    readonly property var audioSources: Pipewire.nodes.values.filter((node) => {
        return !node.isSink && !node.isStream && node.audio;
    }).slice().sort((left, right) => {
        if (source && left.id === source.id)
            return -1;
        if (source && right.id === source.id)
            return 1;
        return (left.description || left.nickname || left.name).localeCompare(right.description || right.nickname || right.name);
    })

    readonly property var audioPlaybackStreams: Pipewire.nodes.values.filter((node) => {
        return node.isStream && node.isSink && node.audio;
    })
    readonly property var audioRecordingStreams: Pipewire.nodes.values.filter((node) => {
        return node.isStream && !node.isSink && node.audio;
    })
    readonly property var audioPlaybackApps: root.groupStreams(root.audioPlaybackStreams, false)
    readonly property var audioRecordingApps: root.groupStreams(root.audioRecordingStreams, true)
    readonly property int appCount: audioPlaybackApps.length + audioRecordingApps.length
    readonly property string summaryText: appCount + " apps · " + audioSinks.length + " outputs · " + audioSources.length + " inputs"

    function streamAppKey(node) {
        if (!node)
            return "app";
        const props = node.properties || {};
        return props["application.name"] || props["application.process.binary"] || node.nickname || node.description || node.name || String(node.id);
    }

    function isGenericIcon(name) {
        const n = String(name || "").toLowerCase();
        return !n
            || n === "application-x-executable"
            || n === "audio-x-generic"
            || n === "audio-card"
            || n === "multimedia-player"
            || n.startsWith("applications-");
    }

    function iconExists(name) {
        return !!(name && Quickshell.iconPath(name, true));
    }

    function appNameMatches(candidate, appName, binary) {
        if (!candidate)
            return false;

        const c = String(candidate).toLowerCase();
        const cNorm = c.replace(/[^a-z0-9]+/g, "");
        const probes = [appName, binary].filter((value) => !!value).map((value) => String(value).toLowerCase());

        for (let i = 0; i < probes.length; i++) {
            const probe = probes[i];
            const probeNorm = probe.replace(/[^a-z0-9]+/g, "");
            if (!probeNorm)
                continue;
            if (cNorm === probeNorm || cNorm.includes(probeNorm) || probeNorm.includes(cNorm))
                return true;

            const parts = c.split(/[\s\-_]+/).filter((part) => !!part);
            const acronym = parts.map((part) => part[0]).join("");
            if (acronym === probeNorm || acronym === probe)
                return true;
        }

        return false;
    }

    function desktopIconFor(appName, binary) {
        const probes = [appName, binary].filter((value) => !!value);
        for (let i = 0; i < probes.length; i++) {
            const probe = String(probes[i]);
            const entry = DesktopEntries.byId(probe) || DesktopEntries.heuristicLookup(probe);
            if (entry && entry.icon && root.iconExists(entry.icon))
                return entry.icon;
        }

        const apps = DesktopEntries.applications.values;
        for (let i = 0; i < apps.length; i++) {
            const entry = apps[i];
            if (!entry || !entry.icon)
                continue;
            if (!root.appNameMatches(entry.name, appName, binary)
                && !root.appNameMatches(entry.id, appName, binary)
                && !root.appNameMatches(entry.startupClass, appName, binary))
                continue;
            if (root.iconExists(entry.icon))
                return entry.icon;
        }

        return "";
    }

    function streamIconName(node) {
        if (!node)
            return "application-x-executable";

        const props = node.properties || {};
        const appName = props["application.name"] || "";
        const binary = props["application.process.binary"] || "";
        const pipewireIcon = props["application.icon-name"] || "";

        const desktopIcon = root.desktopIconFor(appName, binary);
        if (desktopIcon)
            return desktopIcon;

        if (pipewireIcon && !root.isGenericIcon(pipewireIcon) && root.iconExists(pipewireIcon))
            return pipewireIcon;

        if (binary && root.iconExists(binary))
            return binary;

        if (appName && root.iconExists(String(appName).toLowerCase()))
            return String(appName).toLowerCase();

        return "application-x-executable";
    }

    function groupStreams(streams, isInput) {
        const groups = {};
        const order = [];
        for (let i = 0; i < streams.length; i++) {
            const node = streams[i];
            const key = root.streamAppKey(node);
            if (!groups[key]) {
                groups[key] = {
                    key: key,
                    icon: root.streamIconName(node),
                    isInput: !!isInput,
                    nodes: []
                };
                order.push(key);
            }
            groups[key].nodes.push(node);
            const icon = root.streamIconName(node);
            if (icon && !root.isGenericIcon(icon) && (root.isGenericIcon(groups[key].icon) || !groups[key].icon))
                groups[key].icon = icon;
        }
        return order.map((key) => groups[key]);
    }

    function setGroupVolume(nodes, value) {
        for (let i = 0; i < nodes.length; i++) {
            const audio = nodes[i] && nodes[i].audio;
            if (audio) {
                audio.volume = value;
                audio.muted = false;
            }
        }
    }

    function toggleGroupMute(nodes) {
        let allMuted = true;
        for (let i = 0; i < nodes.length; i++) {
            const audio = nodes[i] && nodes[i].audio;
            if (audio && !audio.muted) {
                allMuted = false;
                break;
            }
        }
        for (let i = 0; i < nodes.length; i++) {
            const audio = nodes[i] && nodes[i].audio;
            if (audio)
                audio.muted = !allMuted;
        }
    }

    PwObjectTracker {
        objects: root.audioSinks
    }

    PwObjectTracker {
        objects: root.audioSources
    }

    PwObjectTracker {
        objects: root.audioPlaybackStreams
    }

    PwObjectTracker {
        objects: root.audioRecordingStreams
    }

    clip: true

    Flickable {
        id: mixerFlickable

        anchors.fill: parent
        contentWidth: width
        contentHeight: mixerColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: mixerColumn

            width: parent.width
            spacing: 8

            ShellText {
                text: "System"
                font.pixelSize: 11
                font.weight: Font.Bold
            }

            StyledSlider {
                width: parent.width
                enabled: root.sink && root.sink.audio
                filled: true
                icon: root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾"
                accessibleName: "Output volume"
                value: root.sink && root.sink.audio ? Math.min(1, root.sink.audio.volume) : 0
                valueText: Math.round(value * 100) + "%"
                onMoved: (value) => {
                    if (root.sink && root.sink.audio) {
                        root.sink.audio.volume = value;
                        root.sink.audio.muted = false;
                    }
                }
            }

            StyledSlider {
                width: parent.width
                enabled: root.source && root.source.audio
                filled: true
                icon: root.source && root.source.audio && root.source.audio.muted ? "󰍭" : "󰍬"
                accessibleName: "Input volume"
                value: root.source && root.source.audio ? Math.min(1, root.source.audio.volume) : 0
                valueText: Math.round(value * 100) + "%"
                onMoved: (value) => {
                    if (root.source && root.source.audio) {
                        root.source.audio.volume = value;
                        root.source.audio.muted = false;
                    }
                }
            }

            ShellText {
                text: "Applications"
                font.pixelSize: 11
                font.weight: Font.Bold
            }

            ShellText {
                width: parent.width
                visible: root.appCount === 0
                text: "No apps playing or recording audio"
                color: Theme.muted
                font.pixelSize: 11
            }

            Repeater {
                model: root.audioPlaybackApps.concat(root.audioRecordingApps)

                delegate: Row {
                    id: appRow

                    required property var modelData

                    readonly property var nodes: modelData.nodes
                    readonly property bool allMuted: {
                        const list = appRow.nodes;
                        if (!list || list.length === 0)
                            return true;
                        for (let i = 0; i < list.length; i++) {
                            const audio = list[i] && list[i].audio;
                            if (audio && !audio.muted)
                                return false;
                        }
                        return true;
                    }
                    readonly property real groupVolume: {
                        const list = appRow.nodes;
                        let sum = 0;
                        let count = 0;
                        if (!list)
                            return 0;
                        for (let i = 0; i < list.length; i++) {
                            const audio = list[i] && list[i].audio;
                            if (audio) {
                                sum += audio.volume;
                                count++;
                            }
                        }
                        return count ? Math.min(1, sum / count) : 0;
                    }

                    width: mixerColumn.width
                    spacing: 8
                    height: 40

                    Item {
                        width: 28
                        height: 28
                        anchors.verticalCenter: parent.verticalCenter

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 22
                            source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                        }
                    }

                    StyledSlider {
                        width: parent.width - 28 - muteBtn.width - parent.spacing * 2
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: appRow.nodes && appRow.nodes.length > 0
                        filled: true
                        icon: ""
                        accessibleName: modelData.key + " volume"
                        value: appRow.groupVolume
                        valueText: Math.round(value * 100) + "%"
                        onMoved: (value) => root.setGroupVolume(appRow.nodes, value)
                    }

                    IconButton {
                        id: muteBtn
                        width: 26
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        icon: modelData.isInput
                            ? (appRow.allMuted ? "󰍭" : "󰍬")
                            : (appRow.allMuted ? "󰝟" : "󰕾")
                        accessibleName: appRow.allMuted ? "Unmute app" : "Mute app"
                        foregroundColor: appRow.allMuted ? Theme.muted : Theme.primary
                        onClicked: root.toggleGroupMute(appRow.nodes)
                    }
                }
            }

            ShellText {
                text: "Devices"
                font.pixelSize: 11
                font.weight: Font.Bold
            }

            Row {
                width: parent.width
                spacing: 7

                Column {
                    width: (parent.width - parent.spacing) / 2
                    spacing: 4

                    ShellText {
                        text: "Output"
                        font.pixelSize: 10
                        color: Theme.muted
                    }

                    Repeater {
                        model: root.audioSinks

                        delegate: ConnectionRow {
                            required property var modelData
                            readonly property bool isDefault: root.sink && modelData.id === root.sink.id
                            width: parent ? parent.width : 0
                            height: 38
                            icon: "󰕾"
                            title: modelData.description || modelData.nickname || modelData.name
                            subtitle: isDefault ? "Default" : "Output"
                            active: isDefault
                            actionText: isDefault ? "Selected" : "Select"
                            onClicked: Pipewire.preferredDefaultAudioSink = modelData
                        }
                    }
                }

                Column {
                    width: (parent.width - parent.spacing) / 2
                    spacing: 4

                    ShellText {
                        text: "Input"
                        font.pixelSize: 10
                        color: Theme.muted
                    }

                    Repeater {
                        model: root.audioSources

                        delegate: ConnectionRow {
                            required property var modelData
                            readonly property bool isDefault: root.source && modelData.id === root.source.id
                            width: parent ? parent.width : 0
                            height: 38
                            icon: "󰍬"
                            title: modelData.description || modelData.nickname || modelData.name
                            subtitle: isDefault ? "Default" : "Input"
                            active: isDefault
                            actionText: isDefault ? "Selected" : "Select"
                            onClicked: Pipewire.preferredDefaultAudioSource = modelData
                        }
                    }
                }
            }
        }

        WheelHandler {
            target: null
            onWheel: (event) => {
                const rawDelta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y * 0.6;
                const maximum = Math.max(0, mixerFlickable.contentHeight - mixerFlickable.height);
                mixerFlickable.contentY = Math.max(0, Math.min(maximum, mixerFlickable.contentY - rawDelta * root.detailScrollFactor));
            }
        }
    }
}
// LLM PROMPT [end]
