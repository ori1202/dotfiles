// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Zen desk in cyberpunk-lite dashboard style from reference UI. 2026-10-12.
import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

FocusScope {
    id: root

    // Dashboard style tokens (local to zen)
    readonly property color panelBg: "#161a1d"
    readonly property color panelBorder: "#2a3136"
    readonly property color insetBg: "#0f1214"
    readonly property color labelColor: "#6b756f"
    readonly property color softText: "#9aa39c"
    readonly property int panelRadius: 20
    readonly property int cardRadius: 14
    readonly property int pillRadius: 999
    readonly property int gap: 12
    readonly property int pad: 18

    readonly property var presets: [
        { "label": "15m", "duration": "15m" },
        { "label": "30m", "duration": "30m" },
        { "label": "1h", "duration": "1h" },
        { "label": "2h", "duration": "2h" },
        { "label": "3h", "duration": "3h" }
    ]

    property string selectedClient: ""
    property bool spaceEditing: false

    readonly property var chartColors: [
        Theme.primary,
        Theme.yellow,
        Theme.orange,
        Theme.blue,
        Theme.aqua,
        Theme.purple
    ]

    readonly property var todayTodos: {
        const today = ShellState.todayKey();
        const result = [];
        const todos = ShellState.todos || [];
        for (let i = 0; i < todos.length; i++) {
            const todo = todos[i];
            if (!todo)
                continue;
            const due = todo.dueDate || "";
            if (due && due !== today)
                continue;
            result.push(todo);
        }
        return result;
    }

    readonly property int openLimits: {
        let n = 0;
        for (let i = 0; i < ZenBridge.apps.length; i++) {
            if (ZenBridge.apps[i] && ZenBridge.apps[i].running)
                n += 1;
        }
        return n;
    }

    function takeInitialFocus() {
        zenPill.forceActiveFocus(Qt.TabFocusReason);
    }

    function limitSelected(duration) {
        if (selectedClient)
            ZenBridge.add(selectedClient, duration);
        else
            ZenBridge.addActive(duration);
    }

    function addTask() {
        const text = taskInput.text.trim();
        if (!text)
            return;
        ShellState.addTodo(text + " due:" + ShellState.todayKey());
        taskInput.clear();
    }

    function toggleTaskById(id) {
        const todos = ShellState.todos || [];
        for (let i = 0; i < todos.length; i++) {
            if (todos[i] && todos[i].id === id) {
                ShellState.toggleTodo(i);
                return;
            }
        }
    }

    function sectionLabel(text) {
        return String(text || "").toUpperCase();
    }

    Component.onCompleted: {
        ZenBridge.refreshStatus();
        ZenBridge.refreshClients();
        SpaceBridge.refreshStatus();
    }

    Connections {
        target: ShellState
        function onPanelChanged() {
            if (ShellState.panel === "zen") {
                ZenBridge.refreshClients();
                SpaceBridge.refreshStatus();
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    implicitWidth: 640
    implicitHeight: 720
    // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Inset zen content with 20% total padding (10% each side). 2026-10-12.
    readonly property real padX: Math.round(width * 0.1)
    readonly property real padY: Math.round(height * 0.1)
    // LLM PROMPT [end]

    // —— reusable bits ——
    component DashLabel: ShellText {
        color: root.labelColor
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 1.4
    }

    component ThinBar: Item {
        property real value: 0
        property color fill: Theme.foreground
        property color track: "#2a3136"
        width: parent ? parent.width : 120
        height: 3

        Rectangle {
            anchors.fill: parent
            radius: 2
            color: parent.track
        }
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.value))
            height: parent.height
            radius: 2
            color: parent.fill
        }
    }

    component Pill: Rectangle {
        property string label: ""
        property color tone: root.softText
        property color fill: root.insetBg
        property bool bordered: false
        signal activated()

        width: pillText.implicitWidth + 18
        height: 26
        radius: root.pillRadius
        color: fill
        border.width: bordered ? 1 : 0
        border.color: tone

        ShellText {
            id: pillText
            anchors.centerIn: parent
            text: parent.label
            color: parent.tone
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.activated()
        }
    }

    Column {
        anchors.fill: parent
        anchors.leftMargin: root.padX
        anchors.rightMargin: root.padX
        anchors.topMargin: root.padY
        anchors.bottomMargin: root.padY
        spacing: root.gap

        // TOP ROW — clock | space | status
        Row {
            width: parent.width
            height: Math.floor(parent.height * 0.34)
            spacing: root.gap

            // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Top-left panel shows clock plus focused-app usage chart. 2026-10-12.
            Rectangle {
                width: Math.floor((parent.width - root.gap * 2) * 0.30)
                height: parent.height
                radius: root.panelRadius
                color: root.panelBg
                border.width: 1
                border.color: root.panelBorder
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: root.pad
                    spacing: 10

                    Item {
                        width: parent.width
                        height: 40

                        ShellText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatDateTime(clock.date, "HH:mm")
                            color: Theme.shellForeground
                            font.pixelSize: 36
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                        }

                        Pill {
                            id: zenPill
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            label: ZenBridge.enabled ? "Zen on" : "Zen off"
                            fill: ZenBridge.enabled ? Theme.primaryContainer : root.insetBg
                            tone: ZenBridge.enabled ? Theme.primary : root.softText
                            bordered: ZenBridge.enabled
                            onActivated: ZenBridge.toggle()
                        }
                    }

                    DashLabel { text: "APP TIME TODAY" }

                    ShellText {
                        visible: ZenBridge.usageChart.length === 0
                        width: parent.width
                        text: "Focus apps to start logging"
                        color: root.labelColor
                        font.pixelSize: 11
                    }

                    ListView {
                        width: parent.width
                        height: parent.height - 70
                        clip: true
                        spacing: 8
                        model: ZenBridge.usageChart
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Column {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            spacing: 4

                            Row {
                                width: parent.width
                                spacing: 8

                                ShellText {
                                    width: parent.width - 52
                                    text: modelData.class
                                    elide: Text.ElideRight
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }

                                ShellText {
                                    text: modelData.label
                                    color: root.softText
                                    font.pixelSize: 10
                                }
                            }

                            ThinBar {
                                width: parent.width
                                value: modelData.share
                                fill: root.chartColors[index % root.chartColors.length]
                                track: "#24302a"
                            }
                        }
                    }
                }
            }
            // LLM PROMPT [end]

            // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Editable daily space checklist with add/rename/remove. 2026-10-12.
            Rectangle {
                width: Math.floor((parent.width - root.gap * 2) * 0.38)
                height: parent.height
                radius: root.panelRadius
                color: root.panelBg
                border.width: 1
                border.color: root.panelBorder
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: root.pad
                    spacing: 12

                    Row {
                        width: parent.width
                        spacing: 8

                        DashLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "DAILY SPACE"
                        }

                        Item { width: Math.max(4, parent.width - spacePills.width - 100); height: 1 }

                        Row {
                            id: spacePills
                            spacing: 6

                            Pill {
                                label: SpaceBridge.done + "/" + SpaceBridge.total
                                tone: Theme.primary
                                fill: Theme.primaryContainer
                            }
                            Pill {
                                label: SpaceBridge.unlocked ? "Clear" : "Locked"
                                tone: SpaceBridge.unlocked ? Theme.primary : Theme.red
                                fill: root.insetBg
                                bordered: true
                                onActivated: SpaceBridge.toggle()
                            }
                            Pill {
                                label: root.spaceEditing ? "Done" : "Edit"
                                tone: root.spaceEditing ? Theme.primary : root.softText
                                fill: root.spaceEditing ? Theme.primaryContainer : root.insetBg
                                bordered: root.spaceEditing
                                onActivated: root.spaceEditing = !root.spaceEditing
                            }
                        }
                    }

                    ThinBar {
                        width: parent.width
                        value: SpaceBridge.total > 0 ? SpaceBridge.done / SpaceBridge.total : 0
                        fill: SpaceBridge.unlocked ? Theme.primary : Theme.orange
                        track: "#24302a"
                    }

                    ListView {
                        id: spaceTaskList
                        width: parent.width
                        height: parent.height - (root.spaceEditing ? 100 : 56)
                        clip: true
                        spacing: 8
                        model: SpaceBridge.tasks
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: spaceRow
                            required property var modelData
                            width: ListView.view.width
                            height: root.spaceEditing ? 48 : 44
                            radius: root.cardRadius
                            color: root.insetBg
                            border.width: 1
                            border.color: modelData.done ? Theme.primaryContainer : root.panelBorder

                            Row {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 5
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: modelData.done ? Theme.primary : "transparent"
                                    border.width: 1
                                    border.color: modelData.done ? Theme.primary : root.labelColor
                                    visible: !root.spaceEditing

                                    ShellText {
                                        anchors.centerIn: parent
                                        text: modelData.done ? "✓" : ""
                                        color: Theme.bgDim
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: SpaceBridge.toggleTask(modelData.id)
                                    }
                                }

                                TextInput {
                                    id: spaceLabelInput
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - (root.spaceEditing ? 40 : 28)
                                    text: modelData.label || modelData.id
                                    readOnly: !root.spaceEditing
                                    color: modelData.done && !root.spaceEditing ? root.softText : Theme.foreground
                                    selectionColor: Theme.primaryContainer
                                    selectedTextColor: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    clip: true
                                    selectByMouse: root.spaceEditing

                                    onEditingFinished: {
                                        if (!root.spaceEditing)
                                            return;
                                        const next = text.trim();
                                        if (next && next !== (modelData.label || ""))
                                            SpaceBridge.renameTask(modelData.id, next);
                                        else
                                            text = modelData.label || modelData.id;
                                    }

                                    Keys.onReturnPressed: {
                                        editingFinished();
                                        focus = false;
                                    }
                                    Keys.onEnterPressed: {
                                        editingFinished();
                                        focus = false;
                                    }
                                }

                                Pill {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.spaceEditing
                                    label: "✕"
                                    tone: Theme.red
                                    bordered: true
                                    onActivated: SpaceBridge.removeTask(modelData.id)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !root.spaceEditing
                                z: -1
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SpaceBridge.toggleTask(modelData.id)
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        visible: root.spaceEditing

                        Rectangle {
                            width: parent.width - 52
                            height: 36
                            radius: root.pillRadius
                            color: root.insetBg
                            border.width: 1
                            border.color: root.panelBorder

                            TextInput {
                                id: spaceAddInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.foreground
                                selectionColor: Theme.primaryContainer
                                selectedTextColor: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                clip: true

                                ShellText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "New checklist item…"
                                    visible: !parent.text
                                    color: root.labelColor
                                    font.pixelSize: 12
                                }

                                Keys.onReturnPressed: {
                                    SpaceBridge.addTask(text);
                                    clear();
                                }
                                Keys.onEnterPressed: {
                                    SpaceBridge.addTask(text);
                                    clear();
                                }
                            }
                        }

                        Pill {
                            anchors.verticalCenter: parent.verticalCenter
                            label: "+"
                            tone: Theme.primary
                            fill: Theme.primaryContainer
                            onActivated: {
                                SpaceBridge.addTask(spaceAddInput.text);
                                spaceAddInput.clear();
                            }
                        }
                    }
                }
            }
            // LLM PROMPT [end]

            // Focus / selection
            Rectangle {
                width: Math.floor((parent.width - root.gap * 2) * 0.32)
                height: parent.height
                radius: root.panelRadius
                color: root.panelBg
                border.width: 1
                border.color: root.panelBorder
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: root.pad
                    spacing: 12

                    DashLabel { text: "FOCUS TARGET" }

                    ShellText {
                        width: parent.width
                        text: selectedClient || "Focused window"
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }

                    ShellText {
                        width: parent.width
                        text: selectedClient
                            ? "Presets will limit this app"
                            : "Presets limit whatever is focused"
                        color: root.softText
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }

                    Item { width: 1; height: 4 }

                    DashLabel { text: "OPEN APPS" }

                    Flow {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: ZenBridge.clients

                            Pill {
                                required property var modelData
                                label: modelData.length > 14 ? modelData.slice(0, 13) + "…" : modelData
                                fill: root.selectedClient === modelData ? Theme.primaryContainer : root.insetBg
                                tone: root.selectedClient === modelData ? Theme.primary : root.softText
                                bordered: root.selectedClient === modelData
                                onActivated: root.selectedClient = (root.selectedClient === modelData ? "" : modelData)
                            }
                        }

                        ShellText {
                            visible: ZenBridge.clients.length === 0
                            text: "No open apps"
                            color: root.labelColor
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }

        // MIDDLE — limits | today
        Row {
            width: parent.width
            height: Math.floor(parent.height * 0.48)
            spacing: root.gap

            Rectangle {
                width: Math.floor((parent.width - root.gap) * 0.58)
                height: parent.height
                radius: root.panelRadius
                color: root.panelBg
                border.width: 1
                border.color: root.panelBorder
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: root.pad
                    spacing: 12

                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: 3
                            height: 14
                            radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.primary
                        }

                        DashLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "ACTIVE LIMITS"
                        }

                        Item { width: 8; height: 1 }

                        Pill {
                            label: openLimits + " open"
                            tone: Theme.primary
                            fill: Theme.primaryContainer
                        }
                        Pill {
                            label: (ZenBridge.apps.length || 0) + " total"
                            tone: root.softText
                            fill: root.insetBg
                        }

                        Item { width: parent.width - 320; height: 1 }

                        Pill {
                            label: "Reset all"
                            tone: root.softText
                            fill: root.insetBg
                            onActivated: ZenBridge.reset("all")
                        }
                    }

                    ListView {
                        id: limitsList
                        width: parent.width
                        height: parent.height - 36
                        clip: true
                        spacing: 8
                        model: ZenBridge.apps
                        boundsBehavior: Flickable.StopAtBounds

                        ShellText {
                            anchors.centerIn: parent
                            visible: limitsList.count === 0
                            text: "No active limits — use a duration below"
                            color: root.labelColor
                            font.pixelSize: 12
                        }

                        delegate: Rectangle {
                            id: limitCard
                            required property var modelData
                            width: ListView.view.width
                            height: 72
                            radius: root.cardRadius
                            color: root.insetBg
                            border.width: 1
                            border.color: modelData.expired ? Theme.red : (modelData.running ? Theme.primaryContainer : root.panelBorder)

                            readonly property real progress: {
                                const dur = Math.max(1, Number(modelData.duration) || 1);
                                const rem = Math.max(0, Number(modelData.remaining) || 0);
                                return Math.max(0, Math.min(1, rem / dur));
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                Row {
                                    width: parent.width
                                    spacing: 8

                                    Column {
                                        width: parent.width - 84
                                        spacing: 3

                                        ShellText {
                                            width: parent.width
                                            text: modelData.class || "?"
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                        }

                                        ShellText {
                                            width: parent.width
                                            text: ZenBridge.remainingText(modelData.remaining)
                                                  + " left of "
                                                  + ZenBridge.remainingText(modelData.duration)
                                                  + (modelData.running ? "  ·  open" : "  ·  closed")
                                                  + (modelData.expired ? "  ·  expired" : "")
                                            color: modelData.expired ? Theme.red : root.softText
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Pill {
                                        anchors.verticalCenter: parent.verticalCenter
                                        label: "↺"
                                        onActivated: ZenBridge.reset(modelData.class)
                                    }
                                    Pill {
                                        anchors.verticalCenter: parent.verticalCenter
                                        label: "✕"
                                        tone: Theme.red
                                        bordered: true
                                        onActivated: ZenBridge.remove(modelData.class)
                                    }
                                }

                                ThinBar {
                                    width: parent.width
                                    value: limitCard.progress
                                    fill: modelData.expired ? Theme.red : Theme.primary
                                    track: "#24302a"
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: Math.floor((parent.width - root.gap) * 0.42)
                height: parent.height
                radius: root.panelRadius
                color: root.panelBg
                border.width: 1
                border.color: root.panelBorder
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: root.pad
                    spacing: 12

                    DashLabel { text: "TODAY’S TASKS" }

                    Rectangle {
                        width: parent.width
                        height: 40
                        radius: root.pillRadius
                        color: root.insetBg
                        border.width: 1
                        border.color: root.panelBorder

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 8
                            spacing: 8

                            TextInput {
                                id: taskInput
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 44
                                color: Theme.foreground
                                selectionColor: Theme.primaryContainer
                                selectedTextColor: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                clip: true

                                ShellText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Add a task…"
                                    visible: !parent.text
                                    color: root.labelColor
                                    font.pixelSize: 12
                                }

                                Keys.onReturnPressed: root.addTask()
                                Keys.onEnterPressed: root.addTask()
                            }

                            Pill {
                                anchors.verticalCenter: parent.verticalCenter
                                label: "+"
                                tone: Theme.primary
                                fill: Theme.primaryContainer
                                onActivated: root.addTask()
                            }
                        }
                    }

                    ListView {
                        id: todoList
                        width: parent.width
                        height: parent.height - 72
                        clip: true
                        spacing: 8
                        model: root.todayTodos
                        boundsBehavior: Flickable.StopAtBounds

                        ShellText {
                            anchors.centerIn: parent
                            visible: todoList.count === 0
                            text: "No tasks for today"
                            color: root.labelColor
                            font.pixelSize: 12
                        }

                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: 44
                            radius: root.cardRadius
                            color: root.insetBg
                            border.width: 1
                            border.color: root.panelBorder

                            Row {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 5
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: modelData.done ? Theme.primary : "transparent"
                                    border.width: 1
                                    border.color: modelData.done ? Theme.primary : root.labelColor

                                    ShellText {
                                        anchors.centerIn: parent
                                        text: modelData.done ? "✓" : ""
                                        color: Theme.bgDim
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleTaskById(modelData.id)
                                    }
                                }

                                ShellText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 30
                                    text: modelData.text || ""
                                    elide: Text.ElideRight
                                    font.pixelSize: 12
                                    font.strikeout: !!modelData.done
                                    color: modelData.done ? root.softText : Theme.foreground
                                }
                            }
                        }
                    }
                }
            }
        }

        // BOTTOM — system pills
        Rectangle {
            width: parent.width
            height: Math.floor(parent.height * 0.18) - root.gap
            radius: root.panelRadius
            color: root.panelBg
            border.width: 1
            border.color: root.panelBorder

            Column {
                anchors.fill: parent
                anchors.margins: root.pad
                spacing: 10

                DashLabel { text: "DURATION PRESETS" }

                Flow {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: root.presets

                        Pill {
                            required property var modelData
                            label: modelData.label
                            fill: root.insetBg
                            tone: Theme.foreground
                            bordered: true
                            onActivated: root.limitSelected(modelData.duration)
                        }
                    }

                    Pill {
                        label: "Reset space"
                        tone: root.softText
                        onActivated: SpaceBridge.reset()
                    }

                    Pill {
                        label: "Close"
                        tone: root.softText
                        onActivated: ShellState.close()
                    }
                }
            }
        }
    }
}
// LLM PROMPT [end]
