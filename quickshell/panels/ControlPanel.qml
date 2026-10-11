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
        if (!wiredDevice)
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

    // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Download current song via MusicDownloads status-aware helper. 2026-10-11.
    function downloadCurrentTrack() {
        MusicDownloads.download();
    }
    // LLM PROMPT [end]

    function scrollDetailList(list, event) {
        const rawDelta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y * 0.6;
        const minimum = list.originY;
        const maximum = Math.max(minimum, minimum + list.contentHeight - list.height);
        list.contentY = Math.max(minimum, Math.min(maximum, list.contentY - rawDelta * detailScrollFactor));
        event.accepted = true;
    }

    function startWifiScanner() {
        wifiError = "";
        if (!wifiDevice || !Networking.wifiEnabled)
            return ;

        wifiDevice.scannerEnabled = true;
        wifiRefreshPending = true;
        wifiRefreshTimer.restart();
    }

    function restartWifiScanner() {
        if (!wifiDevice || !Networking.wifiEnabled || wifiRefreshPending)
            return ;

        wifiError = "";
        wifiRefreshPending = true;
        wifiDevice.scannerEnabled = false;
        Qt.callLater(() => {
            if (root.wifiDevice && root.expandedSection === "wifi" && Networking.wifiEnabled)
                root.wifiDevice.scannerEnabled = true;

            wifiRefreshTimer.restart();
        });
    }

    function stopWifiScanner() {
        wifiRefreshTimer.stop();
        wifiRefreshPending = false;
        if (wifiDevice && wifiDevice.scannerEnabled)
            wifiDevice.scannerEnabled = false;
    }

    function startBluetoothDiscovery() {
        if (!adapter || !adapter.enabled)
            return ;

        adapter.discovering = true;
        bluetoothScanTimer.restart();
    }

    function stopBluetoothDiscovery() {
        bluetoothScanTimer.stop();
        if (adapter && adapter.discovering)
            adapter.discovering = false;

    }

    function selectWifi(network) {
        if (!network || network.stateChanging)
            return ;

        if (network.connected) {
            network.disconnect();
            return ;
        }
        wifiError = "";
        if (!network.known && wifiUsesPsk(network.security)) {
            pendingWifiNetwork = network;
            Qt.callLater(() => {
                return wifiPasswordInput.forceActiveFocus(Qt.TabFocusReason);
            });
            return ;
        }
        network.connect();
    }

    function connectPendingWifi() {
        if (!pendingWifiNetwork || !wifiPasswordInput.text)
            return ;

        wifiError = "";
        pendingWifiNetwork.connectWithPsk(wifiPasswordInput.text);
        wifiPasswordInput.clear();
        pendingWifiNetwork = null;
    }

    function wifiUsesPsk(security) {
        return security === WifiSecurityType.WpaPsk || security === WifiSecurityType.Wpa2Psk || security === WifiSecurityType.Sae;
    }

    function wifiSecurityLabel(security) {
        switch (security) {
        case WifiSecurityType.Open:
            return "Open network";
        case WifiSecurityType.Sae:
            return "WPA3";
        case WifiSecurityType.Wpa2Psk:
            return "WPA2";
        case WifiSecurityType.WpaPsk:
            return "WPA";
        case WifiSecurityType.Owe:
            return "Enhanced Open";
        case WifiSecurityType.Wpa2Eap:
            return "WPA2 Enterprise";
        case WifiSecurityType.WpaEap:
            return "WPA Enterprise";
        case WifiSecurityType.Wpa3SuiteB192:
            return "WPA3 Enterprise";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:
            return "WEP";
        case WifiSecurityType.Leap:
            return "LEAP";
        default:
            return "Secured";
        }
    }

    function wifiConnectionFailed(network, reason) {
        if (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout)
            wifiError = "Authentication failed for " + network.name;
        else if (reason === ConnectionFailReason.WifiNetworkLost)
            wifiError = "Network lost while connecting";
        else
            wifiError = "Could not connect to " + network.name;
    }

    function activateBluetoothDevice(device) {
        if (device.connected) {
            device.disconnect();
        } else if (device.paired || device.bonded) {
            device.connect();
        } else {
            device.trusted = true;
            device.pair();
        }
    }

    function bluetoothIcon(device) {
        const iconName = (device.icon || "").toLowerCase();
        if (iconName.indexOf("head") >= 0 || iconName.indexOf("audio") >= 0)
            return "󰋋";

        if (iconName.indexOf("mouse") >= 0)
            return "󰍽";

        if (iconName.indexOf("keyboard") >= 0)
            return "󰌌";

        return "󰂯";
    }

    function wifiSignalPercent(signal) {
        const value = Number(signal);
        if (!Number.isFinite(value))
            return null;

        return Math.round(Math.max(0, Math.min(1, value)) * 100);
    }

    function wifiSignalIcon(signal) {
        const strength = Number(signal);
        if (!Number.isFinite(strength))
            return "󰤯";

        if (strength >= 0.7)
            return "󰤨";

        if (strength >= 0.4)
            return "󰤢";

        return "󰤟";
    }

    function formatDuration(seconds) {
        if (!Number.isFinite(seconds) || seconds < 0)
            return "0:00";

        const minutes = Math.floor(seconds / 60);
        return minutes + ":" + String(Math.floor(seconds % 60)).padStart(2, "0");
    }

    implicitWidth: 492
    implicitHeight: content.implicitHeight
    onWifiDeviceChanged: {
        if (root.wifiDevice && root.expandedSection === "wifi")
            root.startWifiScanner();
    }
    Component.onDestruction: root.stopWifiScanner()
    Keys.onEscapePressed: (event) => {
        if (root.expandedSection) {
            root.closeDetails();
            event.accepted = true;
        }
    }

    PwObjectTracker {
        objects: root.audioSinks
    }

    PwObjectTracker {
        objects: root.audioSources
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

        // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Timer, zen, and notes as a matching control-center row. 2026-10-11.
        Row {
            id: utilityActions
            width: parent.width
            height: 58
            spacing: 7

            ActionTile {
                width: (parent.width - 14) / 3
                icon: TimerBridge.running ? (TimerBridge.paused ? "󰏤" : "󰔟") : "󰔛"
                title: "Timer"
                subtitle: TimerBridge.running
                    ? TimerBridge.remainingText
                    : "Presets"
                active: TimerBridge.running
                expandable: false
                onClicked: ShellState.setPanel("timer")
            }

            ActionTile {
                width: (parent.width - 14) / 3
                icon: ZenBridge.enabled ? "ZEN" : "zen"
                title: "Zen"
                subtitle: ZenBridge.enabled
                    ? ((ZenBridge.apps.length || 0) + " limit(s)")
                    : "App limits"
                active: ZenBridge.enabled
                expandable: false
                onClicked: ShellState.setPanel("zen")
            }

            ActionTile {
                width: (parent.width - 14) / 3
                icon: "NOTE"
                title: "Notes"
                subtitle: NotesState.notes.length > 0
                    ? (NotesState.notes.length + " file(s)")
                    : "~/notes"
                active: NotesState.activePath.length > 0
                expandable: false
                onClicked: ShellState.setPanel("notes")
            }
        }
        // LLM PROMPT [end]

        Row {
            id: quickActions

            width: parent.width
            height: 58
            spacing: 7

            ActionTile {
                id: ethernetTile

                width: (parent.width - 14) / 3
                icon: root.wiredDevice && root.wiredDevice.connected ? "󰈀" : "󰈂"
                title: "Ethernet"
                subtitle: root.ethernetSubtitle
                active: !!(root.wiredDevice && root.wiredDevice.connected)
                expandable: false
                onClicked: root.toggleEthernet()
            }

            ActionTile {
                id: audioTile

                width: (parent.width - 14) / 3
                icon: root.source && root.source.audio && root.source.audio.muted ? "󰍭" : "󰍬"
                title: "Input Audio"
                subtitle: root.source ? (root.source.description || root.source.nickname || "Default input") : "No input"
                active: root.source && root.source.audio && !root.source.audio.muted
                expandable: true
                expanded: root.expandedSection === "audio"
                detailAccessibleName: "Show audio inputs"
                onClicked: root.toggleAudio()
                onDetailClicked: root.toggleSection("audio")
            }

            ActionTile {
                id: cpuTile

                width: (parent.width - 14) / 3
                icon: "󰍛"
                title: "CPU " + SystemStats.cpuTempText
                subtitle: SystemStats.cpuSubtitle
                active: SystemStats.cpuTemp >= 80 || SystemStats.cpuUsage >= 85
                expandable: false
                onClicked: Quickshell.execDetached(["omarchy-launch-or-focus-tui", "btop"])
            }

        }

        Row {
            id: systemActions

            width: parent.width
            height: 58
            spacing: 7

            ActionTile {
                id: bluetoothTile

                width: (parent.width - 14) / 3
                icon: "󰂯"
                title: "Bluetooth"
                subtitle: root.connectedDevices.length > 0 ? root.connectedDevices[0].name : (root.adapter && root.adapter.enabled ? "On" : "Off")
                active: root.adapter && root.adapter.enabled
                expandable: true
                expanded: root.expandedSection === "bluetooth"
                detailAccessibleName: "Show Bluetooth devices"
                onClicked: root.toggleBluetooth()
                onDetailClicked: root.toggleSection("bluetooth")
            }

            ActionTile {
                id: outputAudioTile

                width: (parent.width - 14) / 3
                icon: root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾"
                title: "Output Audio"
                subtitle: root.sink ? (root.sink.description || root.sink.nickname || "Default output") : "No output"
                active: root.sink && root.sink.audio && !root.sink.audio.muted
                expandable: true
                expanded: root.expandedSection === "output"
                detailAccessibleName: "Show audio outputs"
                onClicked: root.toggleOutputAudio()
                onDetailClicked: root.toggleSection("output")
            }

            ActionTile {
                id: gpuTile

                width: (parent.width - 14) / 3
                icon: "󰢮"
                title: "GPU " + SystemStats.gpuTempText
                subtitle: SystemStats.gpuSubtitle
                active: SystemStats.gpuAvailable && (SystemStats.gpuTemp >= 80 || SystemStats.gpuUsage >= 85)
                expandable: false
                onClicked: {
                    if (!SystemStats.gpuAvailable)
                        return;
                    Quickshell.execDetached(["sh", "-c",
                        "if command -v nvtop >/dev/null; then omarchy-launch-or-focus-tui nvtop; else omarchy-launch-or-focus-tui btop; fi"]);
                }
            }

        }

        Rectangle {
            id: devicePicker

            parent: root
            readonly property bool audioMode: root.displayedSection === "audio" || root.displayedSection === "output"
            readonly property bool nightLightMode: false
            readonly property bool compactMode: nightLightMode
            readonly property real availableHeight: root.height - y

            x: compactMode ? root.width - width : 0
            y: systemActions.y + systemActions.height + content.spacing
            z: 20
            width: compactMode ? 320 : root.width
            height: nightLightMode ? Math.min(92, availableHeight) : availableHeight
            radius: Theme.radius
            color: Theme.bg0
            clip: true
            enabled: root.expandedSection !== ""
            visible: opacity > 0
            opacity: root.expandedSection ? 1 : 0

            Rectangle {
                anchors.top: parent.top
                x: {
                    const sourceTile = root.displayedSection === "audio" ? audioTile : outputAudioTile;
                    const centeredX = sourceTile.x + sourceTile.width / 2 - devicePicker.x - width / 2;
                    return Math.max(Theme.radius, Math.min(parent.width - width - Theme.radius, centeredX));
                }
                width: 42
                height: 2
                radius: 1
                visible: devicePicker.compactMode
                color: Theme.primary
            }

            Item {
                id: pickerHeader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                height: 30

                Column {
                    anchors.left: parent.left
                    anchors.right: scanButton.visible ? scanButton.left : (audioSettingsButton.visible ? audioSettingsButton.left : (powerButton.visible ? powerButton.left : parent.right))
                    anchors.rightMargin: scanButton.visible || audioSettingsButton.visible || powerButton.visible ? 8 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    ShellText {
                        width: parent.width
                        text: root.displayedSection === "wifi" ? "Wi-Fi networks" : (root.displayedSection === "audio" ? "Audio input" : (root.displayedSection === "output" ? "Audio output" : (root.displayedSection === "nightlight" ? ShellState.nightLightTemperature + " K" : "Bluetooth devices")))
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }

                    ShellText {
                        width: parent.width
                        text: {
                            if (root.displayedSection === "wifi")
                                return root.wifiError || (root.wifiRefreshPending ? "Refreshing…" : root.wifiNetworks.length + " available");

                            if (root.displayedSection === "audio")
                                return root.audioSources.length + " available";

                            if (root.displayedSection === "output")
                                return root.audioSinks.length + " available";

                            if (root.displayedSection === "nightlight")
                                return "";

                            return root.adapter && root.adapter.discovering ? "Looking for devices…" : root.bluetoothDevices.length + " available";
                        }
                        color: root.wifiError && root.displayedSection === "wifi" ? Theme.red : Theme.muted
                        visible: text.length > 0
                        elide: Text.ElideRight
                        font.pixelSize: 10
                    }

                }

                IconButton {
                    id: powerButton

                    anchors.right: scanButton.visible ? scanButton.left : (audioSettingsButton.visible ? audioSettingsButton.left : parent.right)
                    anchors.rightMargin: scanButton.visible || audioSettingsButton.visible ? 5 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 25
                    height: 25
                    visible: root.displayedSection === "audio" || root.displayedSection === "output" || root.displayedSection === "nightlight"
                    icon: root.displayedSection === "audio" ? (root.source && root.source.audio && root.source.audio.muted ? "󰍭" : "󰍬") : (root.displayedSection === "output" ? (root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾") : "󰐥")
                    accessibleName: {
                        if (root.displayedSection === "wifi")
                            return Networking.wifiEnabled ? "Turn Wi-Fi off" : "Turn Wi-Fi on";

                        if (root.displayedSection === "audio")
                            return root.source && root.source.audio && root.source.audio.muted ? "Unmute microphone" : "Mute microphone";

                        if (root.displayedSection === "output")
                            return root.sink && root.sink.audio && root.sink.audio.muted ? "Unmute output" : "Mute output";

                        if (root.displayedSection === "nightlight")
                            return Backend.nightLightStatus === "on" ? "Turn Night Light off" : "Turn Night Light on";

                        return root.adapter && root.adapter.enabled ? "Turn Bluetooth off" : "Turn Bluetooth on";
                    }
                    foregroundColor: {
                        if (root.displayedSection === "wifi")
                            return Networking.wifiEnabled ? Theme.primary : Theme.muted;

                        if (root.displayedSection === "audio")
                            return root.source && root.source.audio && !root.source.audio.muted ? Theme.primary : Theme.muted;

                        if (root.displayedSection === "output")
                            return root.sink && root.sink.audio && !root.sink.audio.muted ? Theme.primary : Theme.muted;

                        if (root.displayedSection === "nightlight")
                            return Backend.nightLightStatus === "on" ? Theme.primary : Theme.muted;

                        return root.adapter && root.adapter.enabled ? Theme.primary : Theme.muted;
                    }
                    onClicked: {
                        if (root.displayedSection === "wifi")
                            root.toggleWifi();
                        else if (root.displayedSection === "audio" && root.source && root.source.audio)
                            root.source.audio.muted = !root.source.audio.muted;
                        else if (root.displayedSection === "output" && root.sink && root.sink.audio)
                            root.sink.audio.muted = !root.sink.audio.muted;
                        else if (root.displayedSection === "nightlight")
                            Backend.toggleNightLight();
                        else if (root.adapter)
                            root.adapter.enabled = !root.adapter.enabled;
                    }
                }

                // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Open system audio settings (pavucontrol) from audio menus. 2026-10-11.
                IconButton {
                    id: audioSettingsButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 25
                    height: 25
                    visible: root.displayedSection === "audio" || root.displayedSection === "output"
                    icon: "󰒓"
                    accessibleName: "Open audio settings"
                    onClicked: {
                        ShellState.close();
                        Quickshell.execDetached(["pavucontrol"]);
                    }
                }
                // LLM PROMPT [end]

                IconButton {
                    id: scanButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 25
                    height: 25
                    visible: root.displayedSection === "wifi" || root.displayedSection === "bluetooth"
                    enabled: root.displayedSection === "wifi" ? Networking.wifiEnabled && root.wifiDevice && !root.wifiRefreshPending : root.adapter && root.adapter.enabled && !root.adapter.discovering
                    icon: "󰑐"
                    accessibleName: root.displayedSection === "wifi" ? "Scan for Wi-Fi networks" : "Scan for Bluetooth devices"
                    foregroundColor: enabled ? Theme.foreground : Theme.mutedDark
                    onClicked: {
                        if (root.displayedSection === "wifi")
                            root.restartWifiScanner();
                        else
                            root.startBluetoothDiscovery();
                    }
                }

            }

            StyledSlider {
                id: nightLightSlider

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pickerHeader.bottom
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: 4
                visible: root.displayedSection === "nightlight"
                enabled: visible
                filled: true
                icon: "󰖔"
                accessibleName: "Night Light temperature"
                value: (ShellState.nightLightTemperature - 2500) / 3500
                onMoved: (value) => Backend.setNightLightTemperature(2500 + value * 3500)
            }

            StyledSlider {
                id: inputVolumeSlider

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pickerHeader.bottom
                anchors.leftMargin: 7
                anchors.rightMargin: 7
                anchors.topMargin: 5
                visible: root.displayedSection === "audio"
                enabled: visible && root.source && root.source.audio
                filled: true
                icon: root.source && root.source.audio && root.source.audio.muted ? "󰍭" : "󰍬"
                accessibleName: "Input volume"
                value: root.source && root.source.audio ? root.source.audio.volume : 0
                valueText: Math.round(value * 100) + "%"
                onMoved: (value) => {
                    if (root.source && root.source.audio) {
                        root.source.audio.volume = value;
                        root.source.audio.muted = false;
                    }
                }
            }

            StyledSlider {
                id: outputVolumeSlider

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pickerHeader.bottom
                anchors.leftMargin: 7
                anchors.rightMargin: 7
                anchors.topMargin: 5
                visible: root.displayedSection === "output"
                enabled: visible && root.sink && root.sink.audio
                filled: true
                icon: root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾"
                accessibleName: "Output volume"
                value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                valueText: Math.round(value * 100) + "%"
                onMoved: (value) => {
                    if (root.sink && root.sink.audio) {
                        root.sink.audio.volume = value;
                        root.sink.audio.muted = false;
                    }
                }
            }

            Row {
                id: wifiLists

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pickerHeader.bottom
                anchors.bottom: wifiPasswordRow.top
                anchors.leftMargin: 7
                anchors.rightMargin: 7
                anchors.topMargin: 5
                anchors.bottomMargin: wifiPasswordRow.height > 0 ? 5 : 0
                visible: root.displayedSection === "wifi"
                spacing: 4

                component WifiDelegate: ConnectionRow {
                    required property var modelData
                    readonly property var network: modelData

                    width: ListView.view.width
                    height: 42
                    icon: root.wifiSignalIcon(network.signalStrength)
                    title: network.name
                    subtitle: root.wifiSecurityLabel(network.security) + "  ·  " + root.wifiSignalPercent(network.signalStrength) + "%"
                    titleFontSize: 11
                    subtitleFontSize: 9
                    actionFontSize: 9
                    active: network.connected
                    busy: network.stateChanging
                    actionText: network.connected ? "Disconnect" : (!network.known && root.wifiUsesPsk(network.security) ? "Password" : "Connect")
                    secondaryActionVisible: network.known
                    secondaryActionName: "Forget " + network.name
                    onClicked: root.selectWifi(network)
                    onSecondaryClicked: {
                        if (root.pendingWifiNetwork === network) {
                            root.pendingWifiNetwork = null;
                            wifiPasswordInput.clear();
                        }
                        network.forget();
                    }

                    Connections {
                        function onConnectionFailed(reason) {
                            root.wifiConnectionFailed(network, reason);
                        }

                        function onConnectedChanged() {
                            if (network.connected) {
                                root.wifiError = "";
                                root.pendingWifiNetwork = null;
                                wifiPasswordInput.clear();
                            }
                        }

                        target: network
                    }
                }

                ListView {
                    id: knownWifiList

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    clip: true
                    spacing: 4
                    model: root.knownWifiNetworks
                    delegate: WifiDelegate {}

                    WheelHandler {
                        target: null
                        onWheel: (event) => root.scrollDetailList(knownWifiList, event)
                    }
                }

                ListView {
                    id: availableWifiList

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    clip: true
                    spacing: 4
                    model: root.availableWifiNetworks
                    delegate: WifiDelegate {}

                    WheelHandler {
                        target: null
                        onWheel: (event) => root.scrollDetailList(availableWifiList, event)
                    }
                }
            }

            Rectangle {
                id: wifiPasswordRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: pendingWifiNetwork ? 7 : 0
                height: pendingWifiNetwork ? 39 : 0
                visible: height > 0 && root.displayedSection === "wifi"
                radius: Theme.radiusSmall
                color: Theme.bg1
                border.width: wifiPasswordInput.activeFocus ? 1 : 0
                border.color: Theme.primary

                TextInput {
                    id: wifiPasswordInput

                    anchors.left: parent.left
                    anchors.right: wifiConnectButton.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    activeFocusOnTab: visible
                    Keys.onReturnPressed: root.connectPendingWifi()
                    Keys.onEnterPressed: root.connectPendingWifi()

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !parent.text
                        text: "Password for " + (root.pendingWifiNetwork ? root.pendingWifiNetwork.name : "network")
                        color: Theme.mutedDark
                        font.pixelSize: 9
                    }

                }

                FocusScope {
                    id: wifiConnectButton

                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 67
                    activeFocusOnTab: visible
                    Keys.onReturnPressed: root.connectPendingWifi()
                    Keys.onEnterPressed: root.connectPendingWifi()
                    Keys.onSpacePressed: root.connectPendingWifi()

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: Theme.primary
                    }

                    ShellText {
                        anchors.centerIn: parent
                        text: "Connect"
                        color: Theme.bgDim
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.connectPendingWifi()
                    }

                }

            }

            ListView {
                id: audioList

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: inputVolumeSlider.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 7
                anchors.topMargin: 5
                visible: root.displayedSection === "audio"
                clip: true
                spacing: 4
                model: root.audioSources

                delegate: ConnectionRow {
                    required property var modelData
                    readonly property bool isDefault: root.source && modelData.id === root.source.id

                    width: audioList.width
                    height: 42
                    icon: "󰍬"
                    title: modelData.description || modelData.nickname || modelData.name
                    subtitle: modelData.nickname && modelData.nickname !== title ? modelData.nickname : "Audio input"
                    active: isDefault
                    actionText: isDefault ? "Selected" : "Select"
                    onClicked: Pipewire.preferredDefaultAudioSource = modelData
                }

            }

            ListView {
                id: outputAudioList

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: outputVolumeSlider.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 7
                anchors.topMargin: 5
                visible: root.displayedSection === "output"
                clip: true
                spacing: 4
                model: root.audioSinks

                delegate: ConnectionRow {
                    required property var modelData
                    readonly property bool isDefault: root.sink && modelData.id === root.sink.id

                    width: outputAudioList.width
                    height: 42
                    icon: "󰕾"
                    title: modelData.description || modelData.nickname || modelData.name
                    subtitle: modelData.nickname && modelData.nickname !== title ? modelData.nickname : "Audio output"
                    active: isDefault
                    actionText: isDefault ? "Selected" : "Select"
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }

            }

            Row {
                id: bluetoothLists

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pickerHeader.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 7
                anchors.topMargin: 5
                anchors.bottomMargin: 0
                visible: root.displayedSection === "bluetooth"
                spacing: 4

                component BluetoothDelegate: ConnectionRow {
                    required property var modelData
                    readonly property var device: modelData

                    width: ListView.view.width
                    height: 42
                    icon: root.bluetoothIcon(device)
                    title: device.name || device.deviceName || device.address
                    subtitle: device.batteryAvailable ? "Battery " + Math.round(device.battery * 100) + "%" : (device.paired ? "Paired" : "Available")
                    titleFontSize: 11
                    subtitleFontSize: 9
                    actionFontSize: 9
                    active: device.connected
                    busy: device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting
                    actionText: device.connected ? "Disconnect" : (device.paired || device.bonded ? "Connect" : "Pair")
                    secondaryActionVisible: device.paired || device.bonded
                    secondaryActionName: "Remove " + (device.name || device.deviceName || device.address)
                    onClicked: root.activateBluetoothDevice(device)
                    onSecondaryClicked: device.forget()
                }

                ListView {
                    id: knownBluetoothList

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    clip: true
                    spacing: 4
                    model: root.knownBluetoothDevices
                    delegate: BluetoothDelegate {}

                    WheelHandler {
                        target: null
                        onWheel: (event) => root.scrollDetailList(knownBluetoothList, event)
                    }
                }

                ListView {
                    id: availableBluetoothList

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    clip: true
                    spacing: 4
                    model: root.availableBluetoothDevices
                    delegate: BluetoothDelegate {}

                    WheelHandler {
                        target: null
                        onWheel: (event) => root.scrollDetailList(availableBluetoothList, event)
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animationNormal
                    easing.type: Easing.OutCubic
                }

            }

        }

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
