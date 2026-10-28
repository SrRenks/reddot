pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Drag-to-reorder status cluster. The grip is the drag handle; the following
 * row lifts under the pointer while the others slide into their new slots.
 * Visibility stays a tap on the label, so the row keeps its minimalist shape.
 */
Item {
    id: list

    property real s: 1
    property real rowH: 24 * list.s
    property real slotH: rowH + 2 * list.s

    readonly property var knownIds: [
        "weather", "minimized", "tray", "dnd", "network", "inbox",
        "mixer", "sound", "thinkpad", "sysmon", "updates",
        "recorder", "settings", "power"
    ]

    property var allIds: []
    property var displayOrder: []
    property string dragId: ""
    property int dragPos: -1
    property real dragVisualY: 0
    property real dragGrabY: 0
    property bool moved: false

    width: parent ? parent.width : 0
    height: allIds.length * slotH
    implicitHeight: height

    Component.onCompleted: syncOrder()

    Connections {
        target: Flags
        function onBarStatusOrderChanged() {
            if (list.dragId.length === 0)
                list.syncOrder();
        }
    }

    function normalized() {
        var raw = Flags.barStatusOrder.split(",");
        var out = [];
        var seen = ({});
        for (var i = 0; i < raw.length; i++) {
            var id = raw[i];
            if (id.length === 0 || seen[id] !== undefined)
                continue;
            seen[id] = true;
            out.push(id);
        }
        // Keep current custom IDs, then add known items that predate this list.
        for (var k = 0; k < knownIds.length; k++) {
            if (seen[knownIds[k]] === undefined)
                out.push(knownIds[k]);
        }
        return out;
    }

    function syncOrder() {
        var next = normalized();
        var at = next.indexOf("settings");
        if (at >= 0 && next.indexOf("updates") < 0)
            next.splice(at, 0, "updates");
        allIds = next.slice();
        displayOrder = next.slice();
    }

    function label(id) {
        switch (id) {
        case "weather": return "Weather";
        case "minimized": return "Minimized apps";
        case "tray": return "System tray";
        case "dnd": return "Do not disturb";
        case "network": return "Network group";
        case "inbox": return "Notifications";
        case "mixer": return "Mixer";
        case "sound": return "Sound";
        case "thinkpad": return "ThinkPad";
        case "sysmon": return "System monitor";
        case "updates": return "Package updates";
        case "recorder": return "Recorder";
        case "settings": return "Settings";
        case "power": return "Power";
        }
        return id;
    }

    function visibleOf(id) {
        switch (id) {
        case "weather": return Flags.barWeather;
        case "minimized": return Flags.barMinimized;
        case "tray": return Flags.barTray;
        case "dnd": return Flags.barDnd;
        case "network": return Flags.barNetwork;
        case "inbox": return Flags.barInbox;
        case "mixer": return Flags.barMixer;
        case "sound": return Flags.barSound;
        case "thinkpad": return Flags.barThinkpad;
        case "sysmon": return Flags.barSysmon;
        case "updates": return Flags.barUpdates;
        case "recorder": return Flags.barRecorder;
        case "settings": return Flags.barSettings;
        case "power": return Flags.barPower;
        }
        return true;
    }

    function setVisible(id, v) {
        switch (id) {
        case "weather": Flags.barWeather = v; break;
        case "minimized": Flags.barMinimized = v; break;
        case "tray": Flags.barTray = v; break;
        case "dnd": Flags.barDnd = v; break;
        case "network": Flags.barNetwork = v; break;
        case "inbox": Flags.barInbox = v; break;
        case "mixer": Flags.barMixer = v; break;
        case "sound": Flags.barSound = v; break;
        case "thinkpad": Flags.barThinkpad = v; break;
        case "sysmon": Flags.barSysmon = v; break;
        case "updates": Flags.barUpdates = v; break;
        case "recorder": Flags.barRecorder = v; break;
        case "settings": Flags.barSettings = v; break;
        case "power": Flags.barPower = v; break;
        }
    }

    function beginDrag(id, index, grabY) {
        dragId = id;
        dragPos = index;
        dragGrabY = grabY;
        dragVisualY = index * slotH;
        moved = false;
    }

    function dragTo(pointerY) {
        if (dragId.length === 0)
            return;
        var nextY = Math.max(0, Math.min((allIds.length - 1) * slotH,
            pointerY - dragGrabY));
        dragVisualY = nextY;
        var target = Math.max(0, Math.min(allIds.length - 1,
            Math.round(nextY / slotH)));
        if (target === dragPos)
            return;
        var next = displayOrder.slice();
        var from = next.indexOf(dragId);
        if (from < 0)
            return;
        next.splice(from, 1);
        next.splice(target, 0, dragId);
        displayOrder = next;
        dragPos = target;
        moved = true;
    }

    function endDrag() {
        if (dragId.length === 0)
            return;
        if (moved)
            Flags.barStatusOrder = displayOrder.join(",");
        dragId = "";
        dragPos = -1;
        moved = false;
    }

    function cancelDrag() {
        if (dragId.length === 0)
            return;
        syncOrder();
        dragId = "";
        dragPos = -1;
        moved = false;
    }

    Rectangle {
        visible: list.dragId.length > 0
        x: 8 * list.s
        y: list.dragPos * list.slotH
        width: list.width - 16 * list.s
        height: 2 * list.s
        radius: 1 * list.s
        color: Theme.vermLit
        opacity: 0.9
        z: 5
        Behavior on y { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
    }

    Repeater {
        model: list.allIds

        Rectangle {
            id: row
            required property var modelData
            readonly property int pos: list.displayOrder.indexOf(row.modelData)
            readonly property bool shown: list.visibleOf(row.modelData)
            readonly property bool dragging: list.dragId === row.modelData

            x: 0
            y: dragging ? list.dragVisualY : row.pos * list.slotH
            width: list.width
            height: list.rowH
            radius: 7 * list.s
            z: dragging ? 10 : 0
            scale: dragging ? 1.018 : 1
            color: dragging ? Qt.alpha(Theme.vermLit, 0.16)
                : (rowHover.hovered ? Qt.alpha(Theme.cream, 0.07)
                : (row.shown ? Qt.alpha(Theme.vermLit, 0.035) : "transparent"))
            opacity: dragging ? 1 : (row.shown ? 1 : 0.42)
            border.width: dragging ? 1 : 0
            border.color: Qt.alpha(Theme.vermLit, 0.55)

            Behavior on y {
                enabled: !row.dragging
                NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
            }
            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }

            HoverHandler { id: rowHover }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 2 * list.s
                radius: 1 * list.s
                color: row.shown ? Theme.vermLit : "transparent"
                opacity: row.shown ? 0.8 : 0
            }

            Item {
                id: grip
                anchors.left: parent.left
                anchors.leftMargin: 4 * list.s
                anchors.verticalCenter: parent.verticalCenter
                width: 20 * list.s
                height: 22 * list.s

                GlyphIcon {
                    anchors.centerIn: parent
                    width: 14 * list.s
                    height: 14 * list.s
                    name: "grip"
                    color: row.dragging || rowHover.hovered ? Theme.cream
                        : (row.shown ? Theme.vermLit : Theme.faint)
                    stroke: 1.8
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4 * list.s
                    cursorShape: Qt.SizeVerCursor
                    preventStealing: true
                    onPressed: (mouse) => {
                        var p = mapToItem(list, mouse.x, mouse.y);
                        list.beginDrag(row.modelData, row.pos,
                            Math.max(0, Math.min(list.rowH, p.y - row.y)));
                    }
                    onPositionChanged: (mouse) => {
                        if (!pressed || list.dragId.length === 0)
                            return;
                        var p = mapToItem(list, mouse.x, mouse.y);
                        list.dragTo(p.y);
                    }
                    onReleased: list.endDrag()
                    onCanceled: list.cancelDrag()
                }
            }

            Text {
                anchors.left: grip.right
                anchors.right: parent.right
                anchors.rightMargin: 8 * list.s
                anchors.verticalCenter: parent.verticalCenter
                text: list.label(row.modelData)
                elide: Text.ElideRight
                color: row.shown ? Theme.cream : Theme.faint
                font.family: Theme.font
                font.pixelSize: 10.5 * list.s
                font.weight: Font.Medium
            }

            MouseArea {
                anchors.left: grip.right
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                cursorShape: Qt.PointingHandCursor
                onClicked: list.setVisible(row.modelData, !row.shown)
            }
        }
    }
}
