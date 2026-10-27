pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Keyboard languages for Input: configured layout+variant pairs, active row,
 * cycle control and compact add-chips. The physical keyboard model is a separate
 * control in Input; this file only owns the language list.
 */
Item {
    id: root

    property real s: 1
    property var entries: []
    property var catalog: []
    property string activeKeymap: ""
    property int activeIndex: -1
    property string activeLabel: ""

    signal activate(int index)
    signal cycle()
    signal add(string layout, string variant)
    signal remove(int index)

    implicitHeight: column.implicitHeight
    width: parent ? parent.width : 0

    function configured(layout, variant) {
        for (var i = 0; i < entries.length; i++)
            if (entries[i].layout === layout && (entries[i].variant || "") === (variant || ""))
                return true;
        return false;
    }

    readonly property var available: {
        var out = [];
        for (var i = 0; i < catalog.length; i++) {
            var c = catalog[i];
            if (!configured(c.layout, c.variant || ""))
                out.push(c);
        }
        return out;
    }

    Column {
        id: column
        width: parent.width
        spacing: 3 * root.s

        Item {
            width: parent.width
            height: 24 * root.s

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "ACTIVE"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 8 * root.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.1 * root.s
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 53 * root.s
                anchors.right: cycleGlyph.left
                anchors.rightMargin: 8 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: root.activeKeymap.length > 0
                    ? root.activeKeymap
                    : (root.activeLabel.length > 0 ? root.activeLabel : "Unknown")
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            GlyphIcon {
                id: cycleGlyph
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 14 * root.s
                height: 14 * root.s
                name: "refresh"
                color: cycleArea.containsMouse ? Theme.cream : Theme.vermLit
                stroke: 1.8
            }

            MouseArea {
                id: cycleArea
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 24 * root.s
                height: 24 * root.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cycle()
            }
        }

        Repeater {
            model: root.entries

            Item {
                id: langRow
                required property int index
                required property var modelData

                width: column.width
                height: 27 * root.s

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: -6 * root.s
                    anchors.rightMargin: -6 * root.s
                    radius: 8 * root.s
                    color: langRow.index === root.activeIndex ? Qt.alpha(Theme.vermLit, 0.10)
                        : (langArea.containsMouse ? Theme.frameBg : "transparent")
                    border.width: langRow.index === root.activeIndex ? 1 : 0
                    border.color: Qt.alpha(Theme.vermLit, 0.34)
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5 * root.s
                    height: 5 * root.s
                    radius: 2.5 * root.s
                    color: langRow.index === root.activeIndex ? Theme.vermLit : Theme.hairSoft
                    opacity: langRow.index === root.activeIndex ? 1 : 0.7
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 15 * root.s
                    anchors.right: langShort.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: langRow.modelData.label
                    color: langRow.index === root.activeIndex ? Theme.cream : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10.5 * root.s
                    font.weight: langRow.index === root.activeIndex ? Font.DemiBold : Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    id: langShort
                    anchors.right: removeGlyph.left
                    anchors.rightMargin: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: langRow.modelData.short
                    color: langRow.index === root.activeIndex ? Theme.vermLit : Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 8 * root.s
                    font.weight: Font.Bold
                    font.letterSpacing: 0.7 * root.s
                }

                GlyphIcon {
                    id: removeGlyph
                    anchors.right: parent.right
                    anchors.rightMargin: 3 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.entries.length > 1
                    width: 12 * root.s
                    height: 12 * root.s
                    name: "close"
                    color: removeArea.containsMouse ? Theme.vermLit : Theme.faint
                    stroke: 1.7
                }

                MouseArea {
                    id: langArea
                    anchors.fill: parent
                    anchors.rightMargin: 19 * root.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activate(langRow.index)
                }

                MouseArea {
                    id: removeArea
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 20 * root.s
                    visible: root.entries.length > 1
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.remove(langRow.index)
                }
            }
        }

        Item { width: 1; height: 5 * root.s }

        Text {
            width: parent.width
            text: "ADD LANGUAGE"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 7.5 * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.1 * root.s
        }

        Flow {
            width: parent.width
            spacing: 4 * root.s

            Repeater {
                model: root.available

                Rectangle {
                    required property var modelData
                    width: addLabel.implicitWidth + 17 * root.s
                    height: 22 * root.s
                    radius: 7 * root.s
                    color: addArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.12) : "transparent"
                    border.width: 1
                    border.color: addArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.45) : Theme.hairSoft

                    Text {
                        id: addLabel
                        anchors.centerIn: parent
                        text: "+ " + parent.modelData.short
                        color: addArea.containsMouse ? Theme.cream : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 8.5 * root.s
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.4 * root.s
                    }

                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.add(parent.modelData.layout, parent.modelData.variant || "")
                    }
                }
            }
        }

        Text {
            width: parent.width
            topPadding: 3 * root.s
            text: "Super+Space cycles; click a row to activate it directly."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 8.5 * root.s
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
        }
    }
}
