import QtQuick
import "Singletons"

/** Compact component picker row; the single editor above edits the selection. */
Item {
    id: root

    property real s: 1
    property string componentId: ""
    property bool selected: false

    signal picked()

    readonly property var definition: BarCatalog.byId(root.componentId)
    width: parent ? parent.width : 0
    height: 27 * root.s

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2 * root.s
        anchors.bottomMargin: 2 * root.s
        radius: 7 * root.s
        color: root.selected ? Qt.alpha(Theme.vermLit, 0.12)
            : (hover.hovered ? Theme.frameBg : "transparent")
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

    GlyphIcon {
        anchors.left: parent.left
        anchors.leftMargin: 12 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: 14 * root.s
        height: 14 * root.s
        name: root.definition ? root.definition.icon : "layers"
        color: root.selected ? Theme.vermLit : Theme.subtle
        stroke: 1.6
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 33 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * 0.55
        text: root.definition ? root.definition.name : root.componentId
        color: root.selected ? Theme.cream : Theme.subtle
        elide: Text.ElideRight
        font.family: Theme.font
        font.pixelSize: Typography.size("body", root.s)
        font.weight: root.selected ? Font.DemiBold : Font.Medium
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12 * root.s
        anchors.verticalCenter: parent.verticalCenter
        text: BarLayout.hostOf(root.componentId) + " · " + BarLayout.mode(root.componentId)
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: Typography.size("micro", root.s)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
    }
}
