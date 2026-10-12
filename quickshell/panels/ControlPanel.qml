import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets
import qs
import qs.components
import qs.services
import "control"

FocusScope {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Use MusicDownloads preferred player (Firefox YouTube Music first). 2026-10-11.
    readonly property var player: MusicDownloads.activePlayer
    // LLM PROMPT [end]
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var wifiDevice: Networking.devices.values.find((device) => {
        return device.type === DeviceType.Wifi;
    }) || null
    readonly property var wifiNetworks: wifiDevice ? wifiDevice.networks.values.slice().sort((left, right) => {
        if (left.connected !== right.connected)
            return left.connected ? -1 : 1;

        return right.signalStrength - left.signalStrength;
    }) : []
    readonly property var connectedWifi: wifiNetworks.find((network) => {
        return network.connected;
    }) || null
    readonly property var knownWifiNetworks: wifiNetworks.filter((network) => network.known)
    readonly property var availableWifiNetworks: wifiNetworks.filter((network) => !network.known)

    readonly property var wiredDevice: Networking.devices.values.find((device) => {
        return device.type === DeviceType.Wired;
    }) || null
    readonly property string ethernetSubtitle: {
        if (!wiredDevice)
            return "No adapter";
        if (!wiredDevice.hasLink)
            return "No cable";
        if (!wiredDevice.connected)
            return "Disconnected";
        const speed = wiredDevice.linkSpeed ? (wiredDevice.linkSpeed + " Mb/s") : "Linked";
        const addr = wiredDevice.address || "";
        return addr ? (speed + " · " + addr) : speed;
    }
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
    readonly property var bluetoothDevices: adapter ? adapter.devices.values.filter((device) => {
        return device.name || device.deviceName;
    }).slice().sort((left, right) => {
        if (left.connected !== right.connected)
            return left.connected ? -1 : 1;

        if (left.paired !== right.paired)
            return left.paired ? -1 : 1;

        return (left.name || left.deviceName).localeCompare(right.name || right.deviceName);
    }) : []
    readonly property var knownBluetoothDevices: bluetoothDevices.filter((device) => device.paired || device.bonded)
    readonly property var availableBluetoothDevices: bluetoothDevices.filter((device) => !device.paired && !device.bonded)
    readonly property var connectedDevices: adapter ? adapter.devices.values.filter((device) => {
        return device.connected;
    }) : []
    readonly property real batteryLevel: UPower.displayDevice ? UPower.displayDevice.percentage : 0
    readonly property bool batteryCharging: UPower.displayDevice && (!UPower.onBattery || UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.PendingCharge)
    property string expandedSection: ""
    property string displayedSection: ""
    property var pendingWifiNetwork: null
    property string wifiError: ""
    property bool wifiRefreshPending: false
    readonly property real detailScrollFactor: 2

    function toggleSection(section) {
        const nextSection = expandedSection === section ? "" : section;
        if (expandedSection === "wifi" && nextSection !== "wifi")
            stopWifiScanner();

        if (expandedSection === "bluetooth" && nextSection !== "bluetooth")
            stopBluetoothDiscovery();

        expandedSection = nextSection;
        if (nextSection) {
            sectionCloseTimer.stop();
            displayedSection = nextSection;
        } else {
            sectionCloseTimer.restart();
        }
        pendingWifiNetwork = null;
        if (nextSection === "wifi")
            startWifiScanner();
        else if (nextSection === "bluetooth")
            startBluetoothDiscovery();
    }

    function closeDetails() {
        if (!expandedSection)
            return ;

        toggleSection(expandedSection);
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function toggleEthernet() {
        if (ShellState.performanceMode || !wiredDevice)
            return;

        const iface = wiredDevice.name;
        if (wiredDevice.connected) {
            Quickshell.execDetached(["nmcli", "device", "disconnect", iface]);
            return;
        }

        // Profile NAME can be blank; prefer UUID so reconnect still works.
        Quickshell.execDetached(["sh", "-c",
            `uuid=$(nmcli -t -f UUID,TYPE,DEVICE connection show | awk -F: -v d='${iface}' '$2=="802-3-ethernet" && ($3==d || $3=="") { print $1; exit }'); ` +
            `if [ -n "$uuid" ]; then nmcli connection up uuid "$uuid"; else nmcli device connect '${iface}'; fi`]);
    }

    function toggleAudio() {
        if (source && source.audio)
            source.audio.muted = !source.audio.muted;
    }

    function toggleOutputAudio() {
        if (sink && sink.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleBluetooth() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }

    Timer {
        id: wifiRefreshTimer

        interval: 1000
        onTriggered: root.wifiRefreshPending = false
    }

    Timer {
        id: bluetoothScanTimer

        interval: 12000
        onTriggered: root.stopBluetoothDiscovery()
    }

    Timer {
        id: sectionCloseTimer

        interval: Theme.animationNormal
        onTriggered: {
            if (!root.expandedSection)
                root.displayedSection = "";
        }
    }

    Connections {
        function onWifiEnabledChanged() {
            if (Networking.wifiEnabled && root.expandedSection === "wifi")
                Qt.callLater(() => root.startWifiScanner());
            else if (!Networking.wifiEnabled)
                root.stopWifiScanner();
        }

        target: Networking
    }

    Connections {
        function onEnabledChanged() {
            if (root.adapter && root.adapter.enabled && root.expandedSection === "bluetooth")
                root.startBluetoothDiscovery();

        }

        target: root.adapter
    }

    Connections {
        function onPanelChanged() {
            if (ShellState.panel === "control")
                Backend.refreshQuickControls();

            if (ShellState.panel !== "control") {
                root.closeDetails();
                root.stopBluetoothDiscovery();
            }
        }

        target: ShellState
    }

    Timer {
        interval: 1000
        running: root.player && root.player.isPlaying
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Column {
        id: content

        width: parent.width
        spacing: 8

        PanelHeader {
            title: "Control Center"
            showCloseButton: false
            onCloseRequested: ShellState.close()
        }

        // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Compact 1x7 icon-only row including performance mode. 2026-10-12.
        Row {
            id: quickActions

            width: parent.width
            height: 40
            spacing: 7

            readonly property real tileWidth: (width - spacing * 6) / 7

            ActionTile {
                width: quickActions.tileWidth
                height: parent.height
                iconOnly: true
                icon: TimerBridge.running ? (TimerBridge.paused ? "󰏤" : "󰔟") : "󰔛"
                title: "Timer"
                subtitle: TimerBridge.running ? TimerBridge.remainingText : "Presets"
                active: TimerBridge.running
                expandable: false
                onClicked: ShellState.setPanel("timer")
            }

            ActionTile {
                width: quickActions.tileWidth
                height: parent.height
                iconOnly: true
                icon: "󰸮"
                title: "Zen"
                subtitle: ZenBridge.enabled ? ((ZenBridge.apps.length || 0) + " limit(s)") : "App limits"
                active: ZenBridge.enabled
                expandable: false
                onClicked: ShellState.setPanel("zen")
            }

            ActionTile {
                width: quickActions.tileWidth
                height: parent.height
                iconOnly: true
                icon: "󰜏"
                title: "Performance"
                subtitle: ShellState.performanceMode ? "No IO · low latency" : "Full monitoring"
                active: ShellState.performanceMode
                expandable: false
                onClicked: ShellState.togglePerformanceMode()
            }

            ActionTile {
                id: ethernetTile

                width: quickActions.tileWidth
                height: parent.height
                iconOnly: true
                icon: root.wiredDevice && root.wiredDevice.connected ? "󰈀" : "󰈂"
                title: "Ethernet"
                subtitle: root.ethernetSubtitle
                active: !!(root.wiredDevice && root.wiredDevice.connected)
                expandable: false
                onClicked: root.toggleEthernet()
            }

            ActionTile {
                id: gpuTile

                width: quickActions.tileWidth
                height: parent.height
                iconOnly: true
                icon: "󰢮"
                title: "GPU"
                subtitle: SystemStats.gpuSubtitle
                active: SystemStats.gpuAvailable && (SystemStats.gpuTemp >= 80 || SystemStats.gpuUsage >= 85)
                expandable: false
                onClicked: {
                    if (!SystemStats.gpuAvailable || ShellState.performanceMode)
                        return;
                    Quickshell.execDetached(["sh", "-c",
                        "if command -v nvtop >/dev/null; then omarchy-launch-or-focus-tui nvtop; else omarchy-launch-or-focus-tui btop; fi"]);
                }
            }

            ActionTile {
                id: cpuTile

                width: quickActions.tileWidth
                height: parent.height
                iconOnly: true
                icon: "󰍫"
                title: "CPU"
                subtitle: SystemStats.cpuSubtitle
                active: SystemStats.cpuTemp >= 80 || SystemStats.cpuUsage >= 85
                expandable: false
                onClicked: {
                    if (ShellState.performanceMode)
                        return;
                    Quickshell.execDetached(["omarchy-launch-or-focus-tui", "btop"]);
                }
            }

            ActionTile {
                id: audioTile

                width: quickActions.tileWidth
                height: parent.height
                iconOnly: true
                icon: root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾"
                title: "Audio Mixer"
                subtitle: root.sink ? (root.sink.description || root.sink.nickname || "System audio") : "Volumes & devices"
                active: root.expandedSection === "mixer" || (root.sink && root.sink.audio && !root.sink.audio.muted)
                expandable: true
                expanded: root.expandedSection === "mixer"
                detailAccessibleName: "Show audio mixer"
                onClicked: root.toggleSection("mixer")
                onDetailClicked: root.toggleSection("mixer")
            }

        }

        // LLM PROMPT [end]

        // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Use extracted ControlDevicePicker overlay. 2026-10-13.
        ControlDevicePicker {
            id: devicePicker

            host: root
            anchorRow: quickActions
            audioTile: audioTile
            contentSpacing: content.spacing
        }
        // LLM PROMPT [end]

        StyledSlider {
            id: volumeSlider

            width: parent.width
            enabled: root.expandedSection === ""
            filled: true
            icon: root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾"
            accessibleName: "Volume"
            value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
            valueText: Math.round(value * 100) + "%"
            onMoved: (value) => {
                if (root.sink && root.sink.audio) {
                    root.sink.audio.volume = value;
                    root.sink.audio.muted = false;
                }
            }
        }

            Rectangle {
            id: mediaCard

            width: parent.width
            height: 142
            radius: Theme.radius
            clip: true
            enabled: root.expandedSection === ""

            Image {
                id: mediaArtwork

                anchors.fill: parent
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                opacity: status === Image.Ready ? 0.26 : 0
                layer.enabled: status === Image.Ready

                layer.effect: MultiEffect {
                    autoPaddingEnabled: false
                    maskEnabled: true

                    maskSource: Rectangle {
                        width: mediaArtwork.width
                        height: mediaArtwork.height
                        radius: Theme.radius
                        layer.enabled: mediaArtwork.status === Image.Ready
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animationNormal
                    }

                }

            }

            Column {
                anchors.left: parent.left
                anchors.right: controls.left
                anchors.top: parent.top
                anchors.bottom: progress.top
                anchors.margins: 12
                spacing: 3

                ShellText {
                    text: root.sink ? "󰕾  " + (root.sink.description || "Default output") : "󰝟  No audio output"
                    color: Theme.muted
                    font.pixelSize: 9
                    elide: Text.ElideRight
                    width: parent.width
                }

                Item {
                    width: 1
                    height: 2
                }

                ShellText {
                    width: parent.width
                    text: root.player ? (root.player.trackTitle || "Unknown title") : "Nothing playing"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                ShellText {
                    width: parent.width
                    text: root.player ? (root.player.trackArtist || root.player.identity || "Unknown artist") : "Open a media player to begin"
                    color: Theme.muted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Visible Save/Auto download controls for YouTube Music. 2026-10-11.
                Row {
                    spacing: 6

                    Rectangle {
                        width: saveLabel.implicitWidth + 14
                        height: 22
                        radius: 11
                        color: MusicDownloads.downloaded ? Theme.primary : Theme.bg0
                        opacity: (!MusicDownloads.canDownload && !MusicDownloads.downloaded) ? 0.45 : 1

                        ShellText {
                            id: saveLabel
                            anchors.centerIn: parent
                            text: MusicDownloads.downloaded ? "Saved" : (MusicDownloads.downloading ? "Saving…" : "Save")
                            color: MusicDownloads.downloaded ? Theme.bgDim : Theme.foreground
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: MusicDownloads.canDownload && !MusicDownloads.downloading && !MusicDownloads.downloaded
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.downloadCurrentTrack()
                        }
                    }

                    Rectangle {
                        width: autoLabel.implicitWidth + 14
                        height: 22
                        radius: 11
                        color: MusicDownloads.autoDownload ? Theme.primary : Theme.bg0
                        border.width: MusicDownloads.autoDownload ? 0 : 1
                        border.color: Theme.mutedDark

                        ShellText {
                            id: autoLabel
                            anchors.centerIn: parent
                            text: MusicDownloads.autoDownload ? "Auto on" : "Auto"
                            color: MusicDownloads.autoDownload ? Theme.bgDim : Theme.foreground
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MusicDownloads.toggleAutoDownload()
                        }
                    }
                }
                // LLM PROMPT [end]

            }

            Row {
                id: controls

                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                IconButton {
                    width: 28
                    height: 28
                    icon: "󰒮"
                    accessibleName: "Previous track"
                    onClicked: {
                        if (root.player && root.player.canGoPrevious)
                            root.player.previous();

                    }
                }

                IconButton {
                    width: 42
                    height: 42
                    icon: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                    accessibleName: root.player && root.player.isPlaying ? "Pause" : "Play"
                    backgroundColor: Theme.foreground
                    foregroundColor: Theme.bgDim
                    onClicked: {
                        if (root.player && root.player.canTogglePlaying)
                            root.player.togglePlaying();

                    }
                }

                IconButton {
                    width: 28
                    height: 28
                    icon: "󰒭"
                    accessibleName: "Next track"
                    onClicked: {
                        if (root.player && root.player.canGoNext)
                            root.player.next();

                    }
                }

            }

            Row {
                id: progress

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                height: 12
                spacing: 8

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.player ? root.formatDuration(root.player.position) : "0:00"
                    color: Theme.muted
                    font.pixelSize: 8
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 68
                    height: 3
                    radius: 2
                    color: Qt.rgba(0.83, 0.78, 0.67, 0.25)

                    Rectangle {
                        width: parent.width * (root.player && root.player.length > 0 ? Math.min(1, root.player.position / root.player.length) : 0)
                        height: parent.height
                        radius: parent.radius
                        color: Theme.foreground
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.player && root.player.positionSupported && root.player.length > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onPressed: (mouse) => {
                            root.player.position = root.player.length * mouse.x / width;
                        }
                    }

                }

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.player ? root.formatDuration(root.player.length) : "0:00"
                    color: Theme.muted
                    font.pixelSize: 8
                }

            }

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: Theme.primaryContainer
                }

                GradientStop {
                    position: 1
                    color: Theme.bgYellow
                }

            }

        }

        Row {
            id: trayRow

            width: parent.width
            height: 31
            spacing: 5
            visible: trayRepeater.count > 0
            enabled: root.expandedSection === ""
            layoutDirection: Qt.RightToLeft

            Repeater {
                id: trayRepeater

                model: SystemTray.items

                delegate: IconButton {
                    required property var modelData

                    width: 26
                    height: 26
                    accessibleName: modelData.title || modelData.id
                    onClicked: modelData.activate()

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 16
                        source: modelData.icon
                    }

                }

            }

        }

    }

}
