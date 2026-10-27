import QtQuick
import "Singletons"

/**
 * Shared morph-surface base. It is a Flickable so every panel gets one reliable
 * viewport: content taller than the host is clipped, wheel/drag scrolling stops
 * exactly at the last child, and the host can draw a scrollbar from contentY.
 *
 * Deriving surfaces set implicitHeight and add their content as normal children;
 * Flickable reparents those children into its contentItem.
 */
Flickable {
    id: surface

    property real s: 1
    property bool open: false
    property real morphCloseness: 1

    property real mTop: 0
    property real mLeft: 0
    property real mRight: 0
    property real mBottom: 0

    signal requestClose()

    property string ameForm: "off"
    property point amePoint: Qt.point(width / 2, height / 2)

    readonly property bool active: open

    property bool settled: false

    anchors.fill: parent
    anchors.topMargin: mTop * s
    anchors.leftMargin: mLeft * s + SurfaceChrome.contentShift * s
    anchors.rightMargin: mRight * s
    anchors.bottomMargin: mBottom * s

    contentWidth: width
    /**
     * Use the actual laid-out child bottom; implicitHeight can contain trailing
     * padding or a fixed min-height and would leave an empty tail.
     */
    contentHeight: Math.max(height, contentItem ? contentItem.childrenRect.height : implicitHeight)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: true

    function scrollBy(delta) {
        contentY = Math.max(0, Math.min(contentHeight - height, contentY + delta));
    }

    WheelHandler {
        onWheel: (event) => {
            var step = Math.max(20 * surface.s,
                Math.min(140 * surface.s, surface.height * 0.16));
            var raw = -event.angleDelta.y * 0.6;
            surface.scrollBy(Math.max(-step, Math.min(step, raw)));
            event.accepted = true;
        }
    }

    enabled: open
    opacity: open ? (settled ? 1 : Math.pow(morphCloseness, 0.9)) : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
    }

    onOpenChanged: {
        if (!open) {
            settled = false;
            contentY = 0;
        }
    }
    onMorphClosenessChanged: if (open && morphCloseness > 0.92) settled = true

    Binding {
        target: SurfaceChrome
        property: "scrollTarget"
        value: surface
        when: surface.active
    }
    Binding {
        target: SurfaceChrome
        property: "scrollMax"
        value: Math.max(0, surface.contentHeight - surface.height)
        when: surface.active
    }
    Binding {
        target: SurfaceChrome
        property: "scrollOffset"
        value: surface.contentY
        when: surface.active
    }
    Binding {
        target: SurfaceChrome
        property: "scrollViewH"
        value: surface.height
        when: surface.active
    }
}
