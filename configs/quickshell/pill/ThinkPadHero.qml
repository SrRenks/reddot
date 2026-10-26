import QtQuick
import "Singletons"

/** RPM and temperature hero for the ThinkPad surface. */
Item {
    id: hero

    property real s: 1
    property string fanText: "—"
    property string fanState: ""
    property string sensorText: "—"

    width: parent ? parent.width : 0
    height: 68 * hero.s

    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 9 * hero.s
        spacing: 5 * hero.s

        Text {
            text: hero.fanText
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 38 * hero.s
            font.weight: Font.Bold
            font.letterSpacing: -0.5 * hero.s
            font.features: { "tnum": 1 }
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4 * hero.s
            text: "rpm"
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 12 * hero.s
            font.weight: Font.DemiBold
        }
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: 5 * hero.s
        text: hero.fanState
        color: Theme.flameGlow
        font.family: Theme.font
        font.pixelSize: 9 * hero.s
        font.weight: Font.Medium
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12 * hero.s
        text: hero.sensorText
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10 * hero.s
        font.weight: Font.Medium
        elide: Text.ElideRight
        width: Math.min(implicitWidth, parent.width * 0.55)
        horizontalAlignment: Text.AlignRight
    }
}
