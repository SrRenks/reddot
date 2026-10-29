import QtQuick
import "Singletons"

/**
 * Generic representation host for one catalog instance. The first built-in
 * representations are Clock and Workspaces; unknown ids fall back to the
 * catalog glyph so a future provider can be mounted before its own renderer
 * lands.
 */
Item {
    id: root

    property string componentId: ""
    property var instance: null
    property string mode: "widget"
    property real s: 1
    property string screenName: ""
    property bool active: false

    signal requestSurface(string name)
    signal workspacesHover(int index)
    readonly property var definition: BarCatalog.byId(root.componentId)
    readonly property var workspacesView: componentId === "workspaces" ? workspacesHost.workspaces : null

    function activate() {
        if (root.definition && root.definition.action === "toggle-dnd")
            Flags.dnd = !Flags.dnd;
        else if (root.definition && root.definition.target)
            root.requestSurface(root.definition.target);
    }

    implicitWidth: componentId === "clock" ? clockView.implicitWidth
        : (componentId === "workspaces" ? workspacesHost.implicitWidth
        : (componentId === "command" ? commandView.implicitWidth
        : (componentId === "updates" ? updatesView.implicitWidth
        : (root.mode === "widget" ? fallbackWidget.implicitWidth : (fallback.visible ? fallback.width : 0)))))
    implicitHeight: componentId === "clock" ? clockView.implicitHeight
        : (componentId === "workspaces" ? workspacesHost.implicitHeight
        : (componentId === "command" ? commandView.implicitHeight
        : (componentId === "updates" ? updatesView.implicitHeight
        : (root.mode === "widget" ? fallbackWidget.implicitHeight : (fallback.visible ? fallback.height : 0)))))
    width: implicitWidth
    height: implicitHeight

    BarClock {
        id: clockView
        visible: root.componentId === "clock"
        s: root.s
        mode: root.mode
        active: root.active
        onActivated: root.requestSurface("calendar")
    }

    BarWorkspaces {
        id: workspacesHost
        visible: root.componentId === "workspaces"
        s: root.s
        screenName: root.screenName
        mode: root.mode
        workspaceDisplay: root.instance && root.instance.config
            && root.instance.config.workspaceDisplay === "number" ? "number" : "dots"
        active: root.active
        onActivated: root.requestSurface("launcher")
        onHoverIndex: (index) => root.workspacesHover(index)
    }

    BarCommandItem {
        id: commandView
        visible: root.componentId === "command"
        s: root.s
        item: root.instance
        active: root.active
        onRequestSurface: (name) => root.requestSurface(name)
    }

    BarUpdatesWidget {
        id: updatesView
        visible: root.componentId === "updates" && root.mode === "widget"
        s: root.s
        active: root.active
        onRequestSurface: (name) => root.requestSurface(name)
    }

    GlyphIcon {
        id: fallback
        visible: root.componentId !== "clock" && root.componentId !== "workspaces"
            && root.componentId !== "command" && root.mode !== "widget"
        width: 17 * root.s
        height: 17 * root.s
        name: root.definition ? root.definition.icon : "layers"
        color: root.componentId === "dnd" && !Flags.dnd ? Theme.faint : Theme.subtle
        stroke: 1.7
    }

    Row {
        id: fallbackWidget
        visible: root.componentId !== "clock" && root.componentId !== "workspaces"
            && root.componentId !== "command" && root.componentId !== "updates"
            && root.mode === "widget"
        spacing: 4 * root.s
        anchors.verticalCenter: parent.verticalCenter

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 15 * root.s
            height: 15 * root.s
            name: root.definition ? root.definition.icon : "layers"
            color: Theme.subtle
            stroke: 1.7
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.definition ? root.definition.name : root.componentId
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: Typography.size("body", root.s)
            font.weight: Font.Medium
        }
    }

    MouseArea {
        anchors.centerIn: fallback
        width: fallback.width + 12 * root.s
        height: fallback.height + 8 * root.s
        enabled: root.active && fallback.visible && root.mode !== "widget"
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activate()
    }

    MouseArea {
        anchors.centerIn: fallbackWidget
        width: fallbackWidget.implicitWidth + 10 * root.s
        height: fallbackWidget.implicitHeight + 8 * root.s
        enabled: root.active && fallbackWidget.visible
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activate()
    }
}
