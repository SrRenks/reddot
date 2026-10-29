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
    property string workspaceDisplay: "dots"

    readonly property bool numberMode: workspaceDisplay === "number"
    readonly property string activeNumber: {
        var name = String(workspacesView.activeName || "");
        var n = parseInt(name);
        if (n > 0)
            return String(n);
        if (name.indexOf("special:") === 0)
            return name.substring(8, 9).toUpperCase();
        return name.length > 0 ? name : "1";
    }

    signal activated()
    signal hoverIndex(int index)
    readonly property alias workspaces: workspacesView

    implicitWidth: numberMode ? numberChip.width
        : (mode === "icon" ? 17 * root.s : workspacesView.implicitWidth)
    implicitHeight: numberMode ? 22 * root.s
        : (mode === "icon" ? 17 * root.s : workspacesView.implicitHeight)
    width: implicitWidth
    height: implicitHeight

    Workspaces {
        id: workspacesView
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.numberMode && root.mode !== "icon"
        width: visible ? implicitWidth : 0
        screenName: root.screenName
        s: root.s
        gap: 8 * root.s
        enabled: root.active
        onHoverIndexChanged: if (hoverIndex >= 0) root.hoverIndex(hoverIndex)
    }

    Rectangle {
        id: numberChip
        anchors.centerIn: parent
        visible: root.numberMode
        width: numberText.implicitWidth + 12 * root.s
        height: 18 * root.s
        radius: height / 2
        color: Theme.frameBg
        border.width: 1
        border.color: Qt.alpha(Theme.vermLit, 0.42)
    }

    Text {
        id: numberText
        anchors.centerIn: parent
        visible: root.numberMode
        text: root.activeNumber
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: Typography.size("bodyLarge", root.s)
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }

    GlyphIcon {
        anchors.centerIn: parent
        visible: root.mode === "icon" && !root.numberMode
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
        enabled: root.active && root.mode === "icon" && !root.numberMode
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.active && root.numberMode
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
