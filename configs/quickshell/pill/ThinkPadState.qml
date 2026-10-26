import QtQuick
import "Singletons"

/** Empty and helper-missing states for the ThinkPad surface. */
Item {
    id: tpState

    property real s: 1
    property bool present: true
    property bool available: false
    property bool loading: false
    property string error: ""

    width: parent ? parent.width : 0
    height: !tpState.present ? 96 * tpState.s : (!tpState.available ? 84 * tpState.s : 0)

    Item {
        width: parent.width
        height: tpState.present ? 0 : 96 * tpState.s
        visible: !tpState.present

        Text {
            anchors.centerIn: parent
            text: "No ThinkPad hardware detected"
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 11 * tpState.s
        }
    }

    Item {
        width: parent.width
        height: tpState.present && !tpState.available ? 84 * tpState.s : 0
        visible: tpState.present && !tpState.available

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 12 * tpState.s
            text: tpState.loading
                ? "Reading ThinkPad status…"
                : "ThinkPad detected, helper not available"
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 10 * tpState.s
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 32 * tpState.s
            text: tpState.error.length > 0
                ? tpState.error
                : "Run sudo tools/install-extras.sh from the reddot checkout"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9 * tpState.s
            elide: Text.ElideRight
        }
    }
}
