pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/** Tap-to-toggle visibility for the fixed left/clock zones. No switches. */
Column {
    id: list

    property real s: 1
    readonly property var zones: [
        { id: "workspaces", label: "Workspaces" }
    ]

    function shown(id) {
        return id === "workspaces" ? Flags.barWorkspaces : false;
    }
    function toggle(id) {
        if (id === "workspaces")
            Flags.barWorkspaces = !Flags.barWorkspaces;
    }

    width: parent ? parent.width : 0
    spacing: 2 * list.s

    Repeater {
        model: list.zones

        Rectangle {
            id: row
            required property var modelData
            readonly property bool shown: list.shown(row.modelData.id)
            width: list.width
            height: 24 * list.s
            radius: 7 * list.s
            color: hh.hovered ? Qt.alpha(Theme.cream, 0.07)
                : (row.shown ? Qt.alpha(Theme.vermLit, 0.035) : "transparent")
            opacity: row.shown ? 1 : 0.42
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }

            HoverHandler { id: hh }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12 * list.s
                width: 5 * list.s
                height: 5 * list.s
                radius: width / 2
                color: row.shown ? Theme.vermLit : Theme.faint
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 28 * list.s
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.label
                color: row.shown ? Theme.cream : Theme.faint
                font.family: Theme.font
                font.pixelSize: Typography.size("body", list.s)
                font.weight: Font.Medium
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: list.toggle(row.modelData.id)
            }
        }
    }
}
