import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import qs.components
import qs.panels
// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Import Calendar service for date right-click. 2026-10-10.
import qs.services
// LLM PROMPT [end]

PanelWindow {
    id: window

    readonly property int contentPadding: 14
    readonly property int collapsedHeight: 32
    readonly property int cornerWing: 16
    readonly property int canvasWidth: 552
    readonly property int canvasHeight: 600
    readonly property int requestedTopPadding: ShellState.panel === "launcher" ? 10 : contentPadding
    readonly property int requestedBottomPadding: ShellState.panel === "launcher" ? 4 : contentPadding
    readonly property int displayedTopPadding: displayedPanel === "launcher" ? 10 : contentPadding
    readonly property int displayedBottomPadding: displayedPanel === "launcher" ? 4 : contentPadding
    readonly property real targetVisualWidth: ShellState.targetWidth + cornerWing * 2
    readonly property real targetVisualHeight: ShellState.expanded ? panelContentHeight + requestedTopPadding + requestedBottomPadding : collapsedHeight
    readonly property real panelContentHeight: ShellState.expanded ? Math.max(ShellState.panelHeights[ShellState.panel] || 0, requestedPanel ? requestedPanel.implicitHeight : 0) : 0
    property bool contentRevealed: false
    property bool clockRevealed: true
    property string displayedPanel: "control"
    readonly property Item activePanel: {
        const panels = {
            "control": controlPanel,
            "launcher": launcherPanel,
            "clipboard": clipboardPanel,
            "todo": todoPanel,
            "notes": quickNotesPanel,
            "theme": themePanel,
            "wallpaper": wallpaperPanel,
            "capture": capturePanel,
            "power": powerPanel,
            // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Map calendar panel into notch active/requested lookups. 2026-10-10.
            "calendar": calendarPanel
            // LLM PROMPT [end]
            ,
            // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Map timer panel into notch active lookup. 2026-10-10.
            "timer": timerPanel
            // LLM PROMPT [end]
            ,
            // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Map zen panel into notch active lookup. 2026-10-11.
            "zen": zenPanel
            // LLM PROMPT [end]
        };
        return panels[displayedPanel] || null;
    }
    readonly property Item requestedPanel: {
        const panels = {
            "control": controlPanel,
            "launcher": launcherPanel,
            "clipboard": clipboardPanel,
            "todo": todoPanel,
            "notes": quickNotesPanel,
            "theme": themePanel,
            "wallpaper": wallpaperPanel,
            "capture": capturePanel,
            "power": powerPanel,
            // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Map calendar panel into notch requested lookup. 2026-10-10.
            "calendar": calendarPanel
            // LLM PROMPT [end]
            ,
            // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Map timer panel into notch requested lookup. 2026-10-10.
            "timer": timerPanel
            // LLM PROMPT [end]
            ,
            // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Map zen panel into notch requested lookup. 2026-10-11.
            "zen": zenPanel
            // LLM PROMPT [end]
        };
        return panels[ShellState.panel] || null;
    }

    function focusInitialControl() {
        if (!ShellState.expanded || !activePanel)
            return ;

        if (typeof activePanel.takeInitialFocus === "function") {
            activePanel.takeInitialFocus();
            return ;
        }
        activePanel.forceActiveFocus(Qt.TabFocusReason);
        const firstControl = activePanel.nextItemInFocusChain(true);
        if (firstControl && firstControl !== activePanel)
            firstControl.forceActiveFocus(Qt.TabFocusReason);

    }

    function moveFocus(forward) {
        const current = window.activeFocusItem;
        if (!current) {
            focusInitialControl();
            return ;
        }
        const target = current.nextItemInFocusChain(forward);
        if (target)
            target.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);

    }

    margins.left: Math.round((screen.width - canvasWidth) / 2)
    implicitWidth: canvasWidth
    implicitHeight: canvasHeight
    color: "transparent"
    aboveWindows: true
    focusable: ShellState.expanded
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left: true
    }

    Connections {
        function onPanelChanged() {
            window.contentRevealed = ShellState.expanded;
            if (ShellState.expanded) {
                clockRevealTimer.stop();
                window.clockRevealed = false;
                window.displayedPanel = ShellState.panel;
                focusTimer.restart();
            } else {
                clockRevealTimer.restart();
            }
        }

        target: ShellState
    }

    FocusScope {
        id: notchSurface

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: window.targetVisualWidth
        height: window.targetVisualHeight
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                ShellState.close();
                event.accepted = true;
                return ;
            }
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                window.moveFocus(true);
                event.accepted = true;
                return ;
            }
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                window.moveFocus(false);
                event.accepted = true;
                return ;
            }
        }

        Rectangle {
            id: notchBody

            x: window.cornerWing
            y: -15
            width: parent.width - window.cornerWing * 2
            height: parent.height + 15
            radius: Theme.radius
            color: Theme.shellBackground
        }

        Shape {
            x: 0
            width: window.cornerWing
            height: window.cornerWing
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                id: leftShoulderPath

                readonly property real size: window.cornerWing

                strokeWidth: 0
                fillColor: Theme.shellBackground
                startX: 0
                startY: 0

                PathLine {
                    x: leftShoulderPath.size
                    y: 0
                }

                PathLine {
                    x: leftShoulderPath.size
                    y: leftShoulderPath.size
                }

                PathCubic {
                    control1X: leftShoulderPath.size
                    control1Y: leftShoulderPath.size * 0.448
                    control2X: leftShoulderPath.size * 0.552
                    control2Y: 0
                    x: 0
                    y: 0
                }

            }

        }

        Shape {
            x: parent.width - width
            width: window.cornerWing
            height: window.cornerWing
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                id: rightShoulderPath

                readonly property real size: window.cornerWing

                strokeWidth: 0
                fillColor: Theme.shellBackground
                startX: rightShoulderPath.size
                startY: 0

                PathLine {
                    x: 0
                    y: 0
                }

                PathLine {
                    x: 0
                    y: rightShoulderPath.size
                }

                PathCubic {
                    control1X: 0
                    control1Y: rightShoulderPath.size * 0.448
                    control2X: rightShoulderPath.size * 0.448
                    control2Y: 0
                    x: rightShoulderPath.size
                    y: 0
                }

            }

        }

        Row {
            anchors.left: notchBody.left
            anchors.right: notchBody.right
            anchors.top: parent.top
            height: window.collapsedHeight
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            visible: opacity > 0
            opacity: window.clockRevealed ? 1 : 0

            ShellText {
                width: parent.width / 2
                height: parent.height
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                rightPadding: 6
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.shellForeground
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            ShellText {
                width: parent.width / 2
                height: parent.height
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                leftPadding: 6
                text: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"][clock.date.getDay()] + " " + Qt.formatDateTime(clock.date, "d/M")
                color: Theme.shellForeground
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 90
                    easing.type: Easing.OutCubic
                }

            }

        }

        // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Left/right click opens panels; empty left-click or hover-off collapses. 2026-10-10.
        HoverHandler {
            id: notchHover
            onHoveredChanged: {
                if (hovered) {
                    closeHoverTimer.stop();
                } else if (ShellState.expanded) {
                    closeHoverTimer.restart();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !ShellState.expanded
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    // Date sits on the right half of the collapsed clock strip.
                    if (mouse.x < width / 2)
                        return;
                    mouse.accepted = true;
                    closeHoverTimer.stop();
                    Calendar.show();
                    ShellState.show("calendar");
                    return;
                }
                closeHoverTimer.stop();
                ShellState.show("control");
            }
            onPressAndHold: (mouse) => {
                if (mouse.button === Qt.RightButton)
                    mouse.accepted = true;
            }
        }

        // Behind panel controls: left-click empty chrome/gaps dismisses the menu.
        MouseArea {
            anchors.fill: parent
            enabled: ShellState.expanded
            acceptedButtons: Qt.LeftButton
            onClicked: ShellState.close()
        }

        Timer {
            id: closeHoverTimer
            interval: 280
            onTriggered: {
                if (ShellState.expanded && !notchHover.hovered)
                    ShellState.close();
            }
        }
        // LLM PROMPT [end]

        Item {
            id: panelHost

            anchors.left: notchBody.left
            anchors.right: notchBody.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: window.contentPadding
            anchors.rightMargin: window.contentPadding
            anchors.topMargin: window.displayedTopPadding
            anchors.bottomMargin: window.displayedBottomPadding
            visible: opacity > 0
            opacity: window.contentRevealed ? 1 : 0
            clip: true
            // Keep panel above the dismiss MouseArea so controls still receive clicks.
            z: 1

            ControlPanel {
                id: controlPanel

                width: parent.width
                height: parent.height
                visible: window.displayedPanel === "control"
            }

            LauncherPanel {
                id: launcherPanel

                width: parent.width
                visible: window.displayedPanel === "launcher"
            }

            ClipboardPanel {
                id: clipboardPanel

                width: parent.width
                visible: window.displayedPanel === "clipboard"
            }

            TodoPanel {
                id: todoPanel

                width: parent.width
                visible: window.displayedPanel === "todo"
            }

            QuickNotesPanel {
                id: quickNotesPanel

                width: parent.width
                height: parent.height
                visible: window.displayedPanel === "notes"
            }

            ThemePanel {
                id: themePanel

                width: parent.width
                height: parent.height
                visible: window.displayedPanel === "theme"
            }

            WallpaperPanel {
                id: wallpaperPanel

                width: parent.width
                height: parent.height
                visible: window.displayedPanel === "wallpaper"
            }

            CapturePanel {
                id: capturePanel

                width: parent.width
                visible: window.displayedPanel === "capture"
            }

            PowerPanel {
                id: powerPanel

                width: parent.width
                visible: window.displayedPanel === "power"
            }

            // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Host calendar panel inside the notch panel host. 2026-10-10.
            CalendarPanel {
                id: calendarPanel

                width: parent.width
                height: parent.height
                visible: window.displayedPanel === "calendar"
            }
            // LLM PROMPT [end]

            // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Host timer panel inside the notch panel host. 2026-10-10.
            TimerPanel {
                id: timerPanel

                width: parent.width
                visible: window.displayedPanel === "timer"
            }
            // LLM PROMPT [end]

            // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Host zen panel inside the notch panel host. 2026-10-11.
            ZenPanel {
                id: zenPanel

                width: parent.width
                visible: window.displayedPanel === "zen"
            }
            // LLM PROMPT [end]

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animationNormal
                    easing.type: Easing.OutCubic
                }

            }

        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.animationNormal
                easing.type: Easing.OutCubic
            }

        }

        Behavior on height {
            enabled: !clipboardPanel.previewTransitionActive

            NumberAnimation {
                duration: Theme.animationNormal
                easing.type: Easing.OutCubic
            }

        }

    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    HyprlandFocusGrab {
        windows: [window]
        active: ShellState.expanded && Backend.captureSelectionMode !== "region"
        onCleared: {
            if (ShellState.expanded && Backend.captureSelectionMode !== "region")
                ShellState.close();

        }
    }

    Timer {
        id: focusTimer

        interval: 35
        onTriggered: window.focusInitialControl()
    }

    Timer {
        id: clockRevealTimer

        interval: 150
        onTriggered: {
            if (!ShellState.expanded)
                window.clockRevealed = true;

        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: ShellState.expanded
        onActivated: ShellState.close()
    }

    mask: Region {
        item: notchBody
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Theme.radius
        bottomRightRadius: Theme.radius
    }

}
