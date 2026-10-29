import QtQuick
import "Singletons"

/** Persistent package counter widget: icon always; number only when non-zero. */
Item {
    id: root

    property real s: 1
    property bool active: false

    signal requestSurface(string name)

    readonly property int total: PackageUpdates.total
    readonly property bool hasError: PackageUpdates.hasError
    readonly property bool showCount: total > 0 || hasError
    readonly property string countText: hasError && total === 0
        ? "!" : (total > 99 ? "99+" : String(total) + (hasError ? "!" : ""))

    implicitWidth: showCount ? 15 * root.s + 4 * root.s + countBadge.width : 15 * root.s
    implicitHeight: 17 * root.s
    width: implicitWidth
    height: implicitHeight

    GlyphIcon {
        id: glyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 15 * root.s
        height: 15 * root.s
        name: "download"
        color: PackageUpdates.important ? Theme.verm
            : (PackageUpdates.hasError || PackageUpdates.stale ? Theme.flameCore
            : (area.containsMouse ? Theme.cream : Theme.iconDim))
        stroke: 1.8
    }

    Rectangle {
        id: countBadge
        anchors.left: glyph.right
        anchors.leftMargin: 4 * root.s
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showCount
        width: countLabel.implicitWidth + 9 * root.s
        height: 15 * root.s
        radius: height / 2
        color: PackageUpdates.important
            ? Qt.alpha(Theme.verm, area.containsMouse ? 0.22 : 0.16)
            : (PackageUpdates.hasError || PackageUpdates.stale
                ? Qt.alpha(Theme.flameCore, 0.14) : Theme.frameBg)
        border.width: 1
        border.color: PackageUpdates.important ? Qt.alpha(Theme.vermLit, 0.42)
            : (PackageUpdates.hasError || PackageUpdates.stale
                ? Qt.alpha(Theme.flameCore, 0.38) : Theme.hairSoft)

        Text {
            id: countLabel
            anchors.centerIn: parent
            text: root.countText
            color: PackageUpdates.important ? Theme.vermLit
                : (PackageUpdates.hasError || PackageUpdates.stale ? Theme.flameCore
                : (area.containsMouse ? Theme.cream : Theme.subtle))
            font.family: Theme.font
            font.pixelSize: Typography.size("micro", root.s)
            font.weight: Font.Bold
            font.letterSpacing: 0.2 * root.s
            font.features: { "tnum": 1 }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6 * root.s
        hoverEnabled: true
        enabled: root.active
        cursorShape: Qt.PointingHandCursor
        onClicked: root.requestSurface("packages")
    }

    StatusTooltip {
        nodeId: "updates"
        s: root.s
        anchorItem: glyph
        show: area.containsMouse
    }
}
