pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Horizontal chip strip for long capability lists (LED names, trigger names,
 * language codes). The list scrolls instead of wrapping, so a row keeps one
 * stable height and the surface never grows with the kernel's trigger catalogue.
 */
Flickable {
    id: strip

    property real s: 1
    property var options: []
    property var value
    signal picked(var value)

    readonly property var items: {
        var out = [];
        for (var i = 0; i < options.length; i++) {
            var o = options[i];
            out.push(typeof o === "string" ? o : (o.value !== undefined ? o.value : o.label));
        }
        return out;
    }

    height: 24 * strip.s
    contentWidth: row.implicitWidth
    contentHeight: height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentWidth > width

    Row {
        id: row
        height: parent.height
        spacing: 4 * strip.s

        Repeater {
            model: strip.items

            Rectangle {
                id: chip
                required property var modelData
                readonly property bool current: strip.value === modelData

                width: chipLabel.implicitWidth + 16 * strip.s
                height: 22 * strip.s
                radius: 7 * strip.s
                color: current ? Qt.alpha(Theme.verm, 0.16)
                    : (chipArea.containsMouse ? Theme.frameBg : "transparent")
                border.width: 1
                border.color: current ? Qt.alpha(Theme.verm, 0.55) : Theme.frameBorder

                Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: chip.modelData
                    color: chip.current ? Theme.cream : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 9 * strip.s
                    font.weight: chip.current ? Font.DemiBold : Font.Medium
                }

                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: strip.picked(chip.modelData)
                }
            }
        }
    }
}
