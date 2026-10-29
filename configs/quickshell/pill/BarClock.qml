import QtQuick
import Quickshell
import "Singletons"

/**
 * Clock representation for a bar host. The widget keeps the existing time/date
 * block; icon mode collapses it to the clock glyph. Both open the calendar.
 */
Item {
    id: root

    property real s: 1
    property string mode: "widget"
    property bool active: false

    signal activated()

    implicitWidth: mode === "icon" ? 17 * root.s : clockColumn.implicitWidth
    implicitHeight: mode === "icon" ? 17 * root.s : clockColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight

    SystemClock {
        id: sysClock
        precision: Flags.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    QtObject {
        id: clock
        readonly property var loc: Qt.locale("en_US")
        readonly property var now: sysClock.date
        readonly property string timeFormat: (Flags.time12h ? "h:mm" : "HH:mm")
            + (Flags.clockSeconds ? ":ss" : "")
            + (Flags.time12h ? " AP" : "")
        readonly property string hhmm: Qt.formatTime(now, timeFormat)
        readonly property string date: loc.toString(now, "ddd d MMM")
    }

    Column {
        id: clockColumn
        visible: root.mode !== "icon"
        anchors.centerIn: parent
        spacing: 2 * root.s

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: clock.hhmm
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: Typography.size("display", root.s)
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Flags.barDate
            text: clock.date
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Typography.size("micro", root.s)
            font.weight: Font.Medium
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.6 * root.s
        }
    }

    GlyphIcon {
        anchors.centerIn: parent
        visible: root.mode === "icon"
        width: 17 * root.s
        height: 17 * root.s
        name: "clock"
        color: Theme.cream
        stroke: 1.7
    }

    MouseArea {
        anchors.centerIn: parent
        width: implicitWidth + 22 * root.s
        height: implicitHeight + 10 * root.s
        enabled: root.active
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
