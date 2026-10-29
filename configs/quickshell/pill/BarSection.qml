import QtQuick
import "Singletons"

/** Small colored section heading for the bar page. */
Item {
    id: root

    property real s: 1
    property string text: ""

    width: parent ? parent.width : 0
    height: 24 * root.s

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 5 * root.s
        height: 5 * root.s
        radius: width / 2
        color: Theme.vermLit
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 10 * root.s
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: Typography.size("micro", root.s)
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.2 * root.s
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Qt.alpha(Theme.vermLit, 0.22)
    }
}
