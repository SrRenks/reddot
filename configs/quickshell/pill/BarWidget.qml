import QtQuick
import "Singletons"

/** Lightweight static preview of the Bar container; no live child widgets. */
Item {
    id: root

    property real s: 1

    implicitHeight: 42 * root.s
    width: parent ? parent.width : 0
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: 9 * root.s
        color: Theme.tileBg
        border.width: 1
        border.color: Theme.hairSoft
    }

    Row {
        anchors.centerIn: parent
        spacing: 8 * root.s

        GlyphIcon {
            width: 14 * root.s
            height: 14 * root.s
            name: "layers"
            color: Theme.vermLit
            stroke: 1.7
        }

        Text {
            text: "Bar"
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: Typography.size("bodyLarge", root.s)
            font.weight: Font.DemiBold
        }

        Text {
            text: "settings.catalog"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: Typography.size("caption", root.s)
        }

        Text {
            text: "· " + BarLayout.statusOrder.length + " status"
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: Typography.size("caption", root.s)
        }
    }
}
