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
    focus: false
    activeFocusOnTab: true

    onOpenChanged: {
        if (open) {
            kbIndex = 0;
            forceActiveFocus();
        }
    }

    Keys.onUpPressed: (event) => {
        root.kbMove(-1);
        event.accepted = true;
    }
    Keys.onDownPressed: (event) => {
        root.kbMove(1);
        event.accepted = true;
    }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            if (!event.isAutoRepeat)
                root.kbActivate();
            event.accepted = true;
        }
    }

    function syncRows() {
        var next = [];
        for (var i = 0; i < entriesRepeater.count; i++) {
            var item = entriesRepeater.itemAt(i);
            if (item)
                next.push({ item: item, kind: "nav", surface: root.entries[i].surface });
        }
        root.rows = next;
    }

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
            id: entriesRepeater
            model: root.entries

            onCountChanged: root.syncRows()
            Component.onCompleted: root.syncRows()

            Item {
                id: entryRow
                required property var modelData
                required property int index
                width: content.width
                height: 42 * root.s

                readonly property bool hovered: hover.hovered
                readonly property bool focused: root.kbIndex === entryRow.index

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: -6 * root.s
                    anchors.rightMargin: -6 * root.s
                    anchors.topMargin: 2 * root.s
                    anchors.bottomMargin: 2 * root.s
                    radius: 9 * root.s
                    color: entryRow.focused ? Qt.alpha(Theme.vermLit, 0.09)
                        : (entryRow.hovered ? Theme.frameBg : "transparent")
                    border.width: entryRow.focused ? 1 : 0
                    border.color: Qt.alpha(Theme.vermLit, 0.34)
                }

                GlyphIcon {
                    anchors.left: parent.left
                    anchors.leftMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * root.s
                    height: 17 * root.s
                    name: entryRow.modelData.icon
                    color: entryRow.hovered || entryRow.focused ? Theme.cream : Theme.subtle
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
                        font.pixelSize: Typography.size("bodyLarge", root.s)
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: entryRow.modelData.sub.length > 0
                        text: entryRow.modelData.sub
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: Typography.size("micro", root.s)
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
                    color: entryRow.hovered || entryRow.focused ? Theme.cream : Theme.iconDim
                    stroke: 2
                }

                HoverHandler {
                    id: hover
                    onHoveredChanged: if (hovered) root.reportRowHover(entryRow, true)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activateRow(entryRow)
                }
            }
        }

        Item { width: 1; height: 12 * root.s }
    }
}
