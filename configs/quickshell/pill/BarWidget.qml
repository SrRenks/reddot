import QtQuick
import "Singletons"

/**
 * Static widget representation of the Bar container mounted in
 * settings.catalog. It avoids a Repeater over the catalog: creating several
 * catalog delegates while the settings surface opens can crash Quickshell.
 */
Item {
    id: root

    property real s: 1

    implicitHeight: 38 * root.s
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
        spacing: 10 * root.s

        BarComponentHost {
            componentId: "workspaces"
            mode: BarLayout.mode("workspaces")
            s: root.s
            screenName: ""
            active: false
        }

        BarComponentHost {
            componentId: "clock"
            mode: BarLayout.mode("clock")
            s: root.s
            active: false
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: BarLayout.statusOrder.length + " status"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: Typography.size("caption", root.s)
        }
    }
}
