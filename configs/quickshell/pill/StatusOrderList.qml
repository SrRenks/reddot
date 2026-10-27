pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Drag-to-reorder list for the right status cluster. A grip is the only visible
 * control; tapping the label toggles visibility without an on/off switch, keeping
 * the bar page minimal. Flags.barStatusOrder is the single source of truth.
 */
Column {
    id: list

    property real s: 1
    property int dragIndex: -1
    property real rowH: 24 * list.s
    readonly property var order: Flags.barStatusOrder.split(",")

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
        case "recorder": Flags.barRecorder = v; break;
        case "settings": Flags.barSettings = v; break;
        case "power": Flags.barPower = v; break;
        }
    }

    function move(index, to) {
        if (to < 0 || to >= list.order.length || to === index)
            return;
        var next = list.order.slice();
        var item = next[index];
        next.splice(index, 1);
        next.splice(to, 0, item);
        Flags.barStatusOrder = next.join(",");
    }

    function dragTo(y) {
        if (list.dragIndex < 0)
            return;
        var target = Math.max(0, Math.min(list.order.length - 1,
            Math.floor((y - 2 * list.s) / list.rowH)));
        if (target === list.dragIndex)
            return;
        var index = list.dragIndex;
        list.move(index, target);
        list.dragIndex = target;
    }

    width: rootWidth()
    spacing: 2 * list.s

    function rootWidth() {
        return parent ? Math.max(300 * list.s, parent.width) : 300 * list.s;
    }

    Repeater {
        model: list.order

        Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool shown: list.visibleOf(row.modelData)
            readonly property bool dragging: list.dragIndex === row.index

            width: list.width
            height: list.rowH
            radius: 7 * list.s
            color: row.dragging ? Qt.alpha(Theme.vermLit, 0.12)
                : (rowHover.hovered ? Qt.alpha(Theme.cream, 0.07)
                : (row.shown ? Qt.alpha(Theme.vermLit, 0.035) : "transparent"))
            opacity: row.shown ? 1 : 0.42
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
                    color: row.shown ? Theme.vermLit : Theme.faint
                    stroke: 1.8
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4 * list.s
                    cursorShape: Qt.SizeVerCursor
                    preventStealing: true
                    onPressed: {
                        list.dragIndex = row.index;
                    }
                    onPositionChanged: (mouse) => {
                        if (!pressed || list.dragIndex < 0)
                            return;
                        var p = mapToItem(list, mouse.x, mouse.y);
                        list.dragTo(p.y);
                    }
                    onReleased: list.dragIndex = -1
                    onCanceled: list.dragIndex = -1
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
