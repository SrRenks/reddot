import QtQuick
import "Singletons"

/** One open Hyprland window in the game-mode picker. */
Item {
    id: root

    property real s: 1
    property var app: null
    property bool target: false
    property bool kept: false

    signal picked()
    signal keepChanged(bool on)

    width: parent ? parent.width : 0
    height: 34 * root.s

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2 * root.s
        anchors.bottomMargin: 2 * root.s
        radius: 8 * root.s
        color: root.target ? Qt.alpha(Theme.vermLit, 0.12)
            : (rowHover.hovered ? Theme.frameBg : "transparent")
        border.width: root.target ? 1 : 0
        border.color: Qt.alpha(Theme.vermLit, 0.35)
    }

    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }

    GlyphIcon {
        anchors.left: parent.left
        anchors.leftMargin: 10 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: 15 * root.s
        height: 15 * root.s
        name: root.target ? "gamepad" : "app-window"
        color: root.target ? Theme.vermLit : Theme.subtle
        stroke: 1.7
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 33 * root.s
        anchors.right: keepToggle.left
        anchors.rightMargin: 8 * root.s
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1 * root.s

        Text {
            width: parent.width
            text: root.app ? root.app.title : ""
            color: root.target ? Theme.cream : Theme.subtle
            font.family: Theme.font
            font.pixelSize: Typography.size("body", root.s)
            font.weight: root.target ? Font.DemiBold : Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.app ? (root.app.klass + (root.app.fullscreen ? " · fullscreen" : "")) : ""
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: Typography.size("micro", root.s)
            elide: Text.ElideRight
        }
    }

    Text {
        anchors.right: stopLabel.left
        anchors.rightMargin: 8 * root.s
        anchors.verticalCenter: parent.verticalCenter
        text: root.target ? "TARGET" : (root.app ? String(root.app.pid) : "")
        color: root.target ? Theme.vermLit : Theme.faint
        font.family: Theme.font
        font.pixelSize: Typography.size("micro", root.s)
        font.weight: Font.Bold
        font.letterSpacing: 0.8 * root.s
    }

    Text {
        id: stopLabel
        anchors.right: keepToggle.left
        anchors.rightMargin: 8 * root.s
        anchors.verticalCenter: parent.verticalCenter
        text: root.target ? "keep" : ""
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: Typography.size("micro", root.s)
    }

    LinkToggle {
        id: keepToggle
        anchors.right: parent.right
        anchors.rightMargin: 9 * root.s
        anchors.verticalCenter: parent.verticalCenter
        s: root.s
        visible: !root.target
        on: root.kept
        onToggled: root.keepChanged(!root.kept)
    }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: 45 * root.s
        enabled: !root.target
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
    }
}
