import QtQuick
import "Singletons"

/**
 * Workspaces representation for a bar host. Widget mode keeps the workspace
 * dots; icon mode is a compact layers glyph for hosts that ask for the icon.
 */
Item {
    id: root

    property real s: 1
    property string screenName: ""
    property string mode: "widget"
    property bool active: false

    signal activated()
    signal hoverIndex(int index)
    readonly property alias workspaces: workspacesView

    implicitWidth: mode === "icon" ? 17 * root.s : workspacesView.implicitWidth
    implicitHeight: mode === "icon" ? 17 * root.s : workspacesView.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Workspaces {
        id: workspacesView
        anchors.verticalCenter: parent.verticalCenter
        visible: root.mode !== "icon"
        width: visible ? implicitWidth : 0
        screenName: root.screenName
        s: root.s
        gap: 8 * root.s
        enabled: root.active
        onHoverIndexChanged: if (hoverIndex >= 0) root.hoverIndex(hoverIndex)
    }

    GlyphIcon {
        anchors.centerIn: parent
        visible: root.mode === "icon"
        width: 17 * root.s
        height: 17 * root.s
        name: "layers"
        color: Theme.subtle
        stroke: 1.7
    }

    MouseArea {
        anchors.centerIn: parent
        width: implicitWidth + 14 * root.s
        height: implicitHeight + 8 * root.s
        enabled: root.active && root.mode === "icon"
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
