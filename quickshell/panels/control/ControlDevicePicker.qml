// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Extracted expandable control-center device picker overlay. 2026-10-13.
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import qs
import qs.components

Rectangle {
    id: root

    // ControlPanel host API
    property Item host: null
    property Item anchorRow: null
    property Item audioTile: null
    property real contentSpacing: 8


    parent: host
    readonly property bool audioMode: host.displayedSection === "audio" || host.displayedSection === "output" || host.displayedSection === "mixer"
    readonly property bool nightLightMode: false
    readonly property bool compactMode: nightLightMode
    // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Size picker from host height to avoid self height binding loop. 2026-10-13.
    readonly property real availableHeight: (host ? host.height : 0) - y

    x: compactMode ? (host ? host.width : width) - width : 0
    y: anchorRow ? (anchorRow.y + anchorRow.height + contentSpacing) : 0
    z: 20
    width: compactMode ? 320 : (host ? host.width : 0)
    height: nightLightMode ? Math.min(92, availableHeight) : availableHeight
    // LLM PROMPT [end]
    radius: Theme.radius
    color: Theme.bg0
    clip: true
    enabled: host.expandedSection !== ""
    visible: opacity > 0
    opacity: host.expandedSection ? 1 : 0

    Rectangle {
        anchors.top: parent.top
        x: {
            const sourceTile = root.audioTile;
            const centeredX = sourceTile.x + sourceTile.width / 2 - root.x - width / 2;
            return Math.max(Theme.radius, Math.min(parent.width - width - Theme.radius, centeredX));
        }
        width: 42
        height: 2
        radius: 1
        visible: root.compactMode
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
                text: host.displayedSection === "wifi" ? "Wi-Fi networks" : (host.displayedSection === "mixer" ? "Audio mixer" : (host.displayedSection === "audio" ? "Audio input" : (host.displayedSection === "output" ? "Audio output" : (host.displayedSection === "nightlight" ? ShellState.nightLightTemperature + " K" : "Bluetooth devices"))))
                font.pixelSize: 12
                font.weight: Font.Bold
            }

            ShellText {
                width: parent.width
                text: {
                    if (host.displayedSection === "wifi")
                        return host.wifiError || (host.wifiRefreshPending ? "Refreshing…" : host.wifiNetworks.length + " available");

                    if (host.displayedSection === "mixer")
                        return mixerPanel.summaryText;

                    if (host.displayedSection === "audio")
                        return host.audioSources.length + " available";

                    if (host.displayedSection === "output")
                        return host.audioSinks.length + " available";

                    if (host.displayedSection === "nightlight")
                        return "";

                    return host.adapter && host.adapter.discovering ? "Looking for devices…" : host.bluetoothDevices.length + " available";
                }
                color: host.wifiError && host.displayedSection === "wifi" ? Theme.red : Theme.muted
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
            visible: host.displayedSection === "audio" || host.displayedSection === "output" || host.displayedSection === "mixer" || host.displayedSection === "nightlight"
            icon: host.displayedSection === "audio" ? (host.source && host.source.audio && host.source.audio.muted ? "󰍭" : "󰍬") : ((host.displayedSection === "output" || host.displayedSection === "mixer") ? (host.sink && host.sink.audio && host.sink.audio.muted ? "󰝟" : "󰕾") : "󰐥")
            accessibleName: {
                if (host.displayedSection === "wifi")
                    return Networking.wifiEnabled ? "Turn Wi-Fi off" : "Turn Wi-Fi on";

                if (host.displayedSection === "audio")
                    return host.source && host.source.audio && host.source.audio.muted ? "Unmute microphone" : "Mute microphone";

                if (host.displayedSection === "output" || host.displayedSection === "mixer")
                    return host.sink && host.sink.audio && host.sink.audio.muted ? "Unmute output" : "Mute output";

                if (host.displayedSection === "nightlight")
                    return Backend.nightLightStatus === "on" ? "Turn Night Light off" : "Turn Night Light on";

                return host.adapter && host.adapter.enabled ? "Turn Bluetooth off" : "Turn Bluetooth on";
            }
            foregroundColor: {
                if (host.displayedSection === "wifi")
                    return Networking.wifiEnabled ? Theme.primary : Theme.muted;

                if (host.displayedSection === "audio")
                    return host.source && host.source.audio && !host.source.audio.muted ? Theme.primary : Theme.muted;

                if (host.displayedSection === "output" || host.displayedSection === "mixer")
                    return host.sink && host.sink.audio && !host.sink.audio.muted ? Theme.primary : Theme.muted;

                if (host.displayedSection === "nightlight")
                    return Backend.nightLightStatus === "on" ? Theme.primary : Theme.muted;

                return host.adapter && host.adapter.enabled ? Theme.primary : Theme.muted;
            }
            onClicked: {
                if (host.displayedSection === "wifi")
                    host.toggleWifi();
                else if (host.displayedSection === "audio" && host.source && host.source.audio)
                    host.source.audio.muted = !host.source.audio.muted;
                else if ((host.displayedSection === "output" || host.displayedSection === "mixer") && host.sink && host.sink.audio)
                    host.sink.audio.muted = !host.sink.audio.muted;
                else if (host.displayedSection === "nightlight")
                    Backend.toggleNightLight();
                else if (host.adapter)
                    host.adapter.enabled = !host.adapter.enabled;
            }
        }

        // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Open system audio settings (pavucontrol) from audio menus. 2026-10-11.
        IconButton {
            id: audioSettingsButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 25
            height: 25
            visible: host.displayedSection === "audio" || host.displayedSection === "output" || host.displayedSection === "mixer"
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
            visible: host.displayedSection === "wifi" || host.displayedSection === "bluetooth"
            enabled: host.displayedSection === "wifi" ? Networking.wifiEnabled && host.wifiDevice && !host.wifiRefreshPending : host.adapter && host.adapter.enabled && !host.adapter.discovering
            icon: "󰑐"
            accessibleName: host.displayedSection === "wifi" ? "Scan for Wi-Fi networks" : "Scan for Bluetooth devices"
            foregroundColor: enabled ? Theme.foreground : Theme.mutedDark
            onClicked: {
                if (host.displayedSection === "wifi")
                    host.restartWifiScanner();
                else
                    host.startBluetoothDiscovery();
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
        visible: host.displayedSection === "nightlight"
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
        visible: host.displayedSection === "audio"
        enabled: visible && host.source && host.source.audio
        filled: true
        icon: host.source && host.source.audio && host.source.audio.muted ? "󰍭" : "󰍬"
        accessibleName: "Input volume"
        value: host.source && host.source.audio ? host.source.audio.volume : 0
        valueText: Math.round(value * 100) + "%"
        onMoved: (value) => {
            if (host.source && host.source.audio) {
                host.source.audio.volume = value;
                host.source.audio.muted = false;
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
        visible: host.displayedSection === "output"
        enabled: visible && host.sink && host.sink.audio
        filled: true
        icon: host.sink && host.sink.audio && host.sink.audio.muted ? "󰝟" : "󰕾"
        accessibleName: "Output volume"
        value: host.sink && host.sink.audio ? host.sink.audio.volume : 0
        valueText: Math.round(value * 100) + "%"
        onMoved: (value) => {
            if (host.sink && host.sink.audio) {
                host.sink.audio.volume = value;
                host.sink.audio.muted = false;
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
        visible: host.displayedSection === "wifi"
        spacing: 4

        component WifiDelegate: ConnectionRow {
            required property var modelData
            readonly property var network: modelData

            width: ListView.view.width
            height: 42
            icon: host.wifiSignalIcon(network.signalStrength)
            title: network.name
            subtitle: host.wifiSecurityLabel(network.security) + "  ·  " + host.wifiSignalPercent(network.signalStrength) + "%"
            titleFontSize: 11
            subtitleFontSize: 9
            actionFontSize: 9
            active: network.connected
            busy: network.stateChanging
            actionText: network.connected ? "Disconnect" : (!network.known && host.wifiUsesPsk(network.security) ? "Password" : "Connect")
            secondaryActionVisible: network.known
            secondaryActionName: "Forget " + network.name
            onClicked: host.selectWifi(network)
            onSecondaryClicked: {
                if (host.pendingWifiNetwork === network) {
                    host.pendingWifiNetwork = null;
                    wifiPasswordInput.clear();
                }
                network.forget();
            }

            Connections {
                function onConnectionFailed(reason) {
                    host.wifiConnectionFailed(network, reason);
                }

                function onConnectedChanged() {
                    if (network.connected) {
                        host.wifiError = "";
                        host.pendingWifiNetwork = null;
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
            model: host.knownWifiNetworks
            delegate: WifiDelegate {}

            WheelHandler {
                target: null
                onWheel: (event) => host.scrollDetailList(knownWifiList, event)
            }
        }

        ListView {
            id: availableWifiList

            width: (parent.width - parent.spacing) / 2
            height: parent.height
            clip: true
            spacing: 4
            model: host.availableWifiNetworks
            delegate: WifiDelegate {}

            WheelHandler {
                target: null
                onWheel: (event) => host.scrollDetailList(availableWifiList, event)
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
        visible: height > 0 && host.displayedSection === "wifi"
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
            Keys.onReturnPressed: host.connectPendingWifi()
            Keys.onEnterPressed: host.connectPendingWifi()

            ShellText {
                anchors.verticalCenter: parent.verticalCenter
                visible: !parent.text
                text: "Password for " + (host.pendingWifiNetwork ? host.pendingWifiNetwork.name : "network")
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
            Keys.onReturnPressed: host.connectPendingWifi()
            Keys.onEnterPressed: host.connectPendingWifi()
            Keys.onSpacePressed: host.connectPendingWifi()

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
                onClicked: host.connectPendingWifi()
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
        visible: host.displayedSection === "audio"
        clip: true
        spacing: 4
        model: host.audioSources

        delegate: ConnectionRow {
            required property var modelData
            readonly property bool isDefault: host.source && modelData.id === host.source.id

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
        visible: host.displayedSection === "output"
        clip: true
        spacing: 4
        model: host.audioSinks

        delegate: ConnectionRow {
            required property var modelData
            readonly property bool isDefault: host.sink && modelData.id === host.sink.id

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

    // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Embed extracted AudioMixerPanel in device picker. 2026-10-13.
    AudioMixerPanel {
        id: mixerPanel

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: pickerHeader.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 7
        anchors.topMargin: 5
        visible: host.displayedSection === "mixer"
        detailScrollFactor: host.detailScrollFactor
    }
    // LLM PROMPT [end]


    Row {
        id: bluetoothLists

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: pickerHeader.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 7
        anchors.topMargin: 5
        anchors.bottomMargin: 0
        visible: host.displayedSection === "bluetooth"
        spacing: 4

        component BluetoothDelegate: ConnectionRow {
            required property var modelData
            readonly property var device: modelData

            width: ListView.view.width
            height: 42
            icon: host.bluetoothIcon(device)
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
            onClicked: host.activateBluetoothDevice(device)
            onSecondaryClicked: device.forget()
        }

        ListView {
            id: knownBluetoothList

            width: (parent.width - parent.spacing) / 2
            height: parent.height
            clip: true
            spacing: 4
            model: host.knownBluetoothDevices
            delegate: BluetoothDelegate {}

            WheelHandler {
                target: null
                onWheel: (event) => host.scrollDetailList(knownBluetoothList, event)
            }
        }

        ListView {
            id: availableBluetoothList

            width: (parent.width - parent.spacing) / 2
            height: parent.height
            clip: true
            spacing: 4
            model: host.availableBluetoothDevices
            delegate: BluetoothDelegate {}

            WheelHandler {
                target: null
                onWheel: (event) => host.scrollDetailList(availableBluetoothList, event)
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

// LLM PROMPT [end]
