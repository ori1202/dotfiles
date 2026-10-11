// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Calendar date hover shows note preview popup. 2026-10-11.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.components
import qs.services

FocusScope {
    id: root

    property bool hoverPopupVisible: false
    property string hoverKey: ""
    property string hoverTitle: ""
    property string hoverBody: ""
    property real hoverAnchorX: 0
    property real hoverAnchorY: 0

    function takeInitialFocus() {
        nextButton.forceActiveFocus(Qt.TabFocusReason);
    }

    function noteForDate(key) {
        const notes = NotesState.notes;
        for (let i = 0; i < notes.length; i++) {
            if (notes[i] && notes[i].date === key)
                return notes[i];
        }
        return null;
    }

    function previewBody(note) {
        if (!note)
            return "No note yet — click to create";
        let body = String(note.searchText || "");
        body = body.replace(/^---[\s\S]*?---\s*/, "");
        body = body.replace(/^#\s+[^\n]*\n?/, "");
        body = body.replace(/\s+/g, " ").trim();
        if (!body)
            return "Empty note — click to edit";
        return body.length > 160 ? body.slice(0, 160) + "…" : body;
    }

    function showHover(dayItem, key) {
        const note = root.noteForDate(key);
        root.hoverKey = key;
        root.hoverTitle = note ? (note.title || key) : key;
        root.hoverBody = root.previewBody(note);
        const point = dayItem.mapToItem(root, dayItem.width / 2, 0);
        root.hoverAnchorX = point.x;
        root.hoverAnchorY = point.y;
        root.hoverPopupVisible = true;
        hideHoverTimer.stop();
    }

    function scheduleHideHover() {
        hideHoverTimer.restart();
    }

    Component.onCompleted: NotesState.refresh()

    implicitWidth: 292
    implicitHeight: 288

    Timer {
        id: hideHoverTimer
        interval: 80
        onTriggered: root.hoverPopupVisible = false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            IconButton {
                id: prevButton
                width: 30
                height: 30
                icon: "‹"
                accessibleName: "Previous month"
                onClicked: Calendar.prevMonth()
                Keys.onLeftPressed: Calendar.prevMonth()
            }

            ShellText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: {
                    const d = new Date(Calendar.viewYear, Calendar.viewMonth, 1);
                    return Qt.formatDate(d, "MMMM yyyy");
                }
                font.pixelSize: 14
                font.weight: Font.Bold
            }

            IconButton {
                id: nextButton
                width: 30
                height: 30
                icon: "›"
                accessibleName: "Next month"
                onClicked: Calendar.nextMonth()
                Keys.onRightPressed: Calendar.nextMonth()
            }
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: Qt.locale()
            delegate: ShellText {
                required property var model
                text: model.shortName
                color: Theme.muted
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                width: parent.width / 7
            }
        }

        MonthGrid {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            month: Calendar.viewMonth
            year: Calendar.viewYear
            locale: Qt.locale()

            delegate: Item {
                id: dayCell
                required property var model
                implicitWidth: grid.width / 7
                implicitHeight: 32
                readonly property bool isToday: model.today
                readonly property bool inMonth: model.month === grid.month
                readonly property string key: model.date
                    ? Qt.formatDate(model.date, "yyyy-MM-dd")
                    : (String(model.year) + "-" + String(model.month + 1).padStart(2, "0") + "-" + String(model.day).padStart(2, "0"))
                readonly property bool hasNote: !!NotesState.notesByDate[dayCell.key]

                Rectangle {
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    radius: Theme.radiusSmall
                    color: dayCell.isToday ? Theme.primary : (dayPointer.containsMouse ? Theme.bg2 : "transparent")
                    border.width: dayCell.hasNote && !dayCell.isToday ? 1 : 0
                    border.color: Theme.primary

                    ShellText {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: dayCell.hasNote ? -2 : 0
                        text: model.day
                        color: dayCell.isToday ? Theme.bgDim : (dayCell.inMonth ? Theme.foreground : Theme.mutedDark)
                        opacity: dayCell.inMonth || dayCell.isToday ? 1 : 0.5
                        font.pixelSize: 12
                        font.weight: dayCell.isToday || dayCell.hasNote ? Font.Bold : Font.Normal
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        width: 4
                        height: 4
                        radius: 2
                        visible: dayCell.hasNote
                        color: dayCell.isToday ? Theme.bgDim : Theme.primary
                    }
                }

                MouseArea {
                    id: dayPointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.showHover(dayCell, dayCell.key)
                    onExited: root.scheduleHideHover()
                    onClicked: {
                        NotesState.openDateNote(dayCell.key);
                        ShellState.setPanel("notes");
                    }
                }
            }
        }
    }

    // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Floating note preview when hovering a calendar day. 2026-10-11.
    Rectangle {
        id: notePopup
        z: 100
        visible: root.hoverPopupVisible
        width: Math.min(parent.width - 8, 240)
        height: popupColumn.implicitHeight + 16
        radius: Theme.radiusSmall
        color: Theme.bg0
        border.width: 1
        border.color: Theme.bg2

        x: Math.max(4, Math.min(root.width - width - 4, root.hoverAnchorX - width / 2))
        y: {
            const below = root.hoverAnchorY + 34;
            if (below + height <= root.height - 4)
                return below;
            return Math.max(4, root.hoverAnchorY - height - 6);
        }

        Column {
            id: popupColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 4

            // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Hover popup shows note body only; date is already known. 2026-10-11.
            ShellText {
                width: parent.width
                text: root.hoverBody
                color: Theme.foreground
                font.pixelSize: 10
                wrapMode: Text.Wrap
                maximumLineCount: 6
                elide: Text.ElideRight
            }
            // LLM PROMPT [end]
        }
    }
    // LLM PROMPT [end]
}
// LLM PROMPT [end]
