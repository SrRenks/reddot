pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/** Compact navigation hub for a settings area with only subpages. */
SettingsSurface {
    id: root

    property string hubTitle: ""
    property string hubIcon: "layers"
    property var entries: []

    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: 0

        SettingsHeader {
            s: root.s
            icon: root.hubIcon
            title: root.hubTitle
            showBack: true
        }

        Item { width: 1; height: 9 * root.s }

        Repeater {
            model: root.entries

            Item {
                id: entryRow
                required property var modelData
                width: content.width
                height: 42 * root.s

                readonly property bool hovered: hover.hovered

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: -6 * root.s
                    anchors.rightMargin: -6 * root.s
                    anchors.topMargin: 2 * root.s
                    anchors.bottomMargin: 2 * root.s
                    radius: 9 * root.s
                    color: entryRow.hovered ? Theme.frameBg : "transparent"
                }

                GlyphIcon {
                    anchors.left: parent.left
                    anchors.leftMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * root.s
                    height: 17 * root.s
                    name: entryRow.modelData.icon
                    color: entryRow.hovered ? Theme.cream : Theme.subtle
                    stroke: 1.8
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 36 * root.s
                    anchors.right: chevron.left
                    anchors.rightMargin: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * root.s

                    Text {
                        width: parent.width
                        text: entryRow.modelData.name
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 12 * root.s
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: entryRow.modelData.sub.length > 0
                        text: entryRow.modelData.sub
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 8.5 * root.s
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                }

                GlyphIcon {
                    id: chevron
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14 * root.s
                    height: 14 * root.s
                    name: "chevron-right"
                    color: entryRow.hovered ? Theme.cream : Theme.iconDim
                    stroke: 2
                }

                HoverHandler { id: hover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestSurface(entryRow.modelData.surface)
                }
            }
        }

        Item { width: 1; height: 12 * root.s }
    }
}
