pragma Singleton
import QtQuick
import Quickshell

/**
 * Shared chrome state for the currently open surface. `gutter` sizes the target
 * width immediately; `contentShift` animates the surface margin independently so
 * the panel content does not snap sideways while the pill is morphing.
 */
Singleton {
    property bool reserveBack: false
    readonly property real gutter: reserveBack ? 24 : 0
    /** Bridge for the one open surface's scroll state; Pill draws the host bar. */
    property real scrollMax: 0
    property real scrollOffset: 0
    property real scrollViewH: 0
    property var scrollTarget: null
    function scrollBy(delta) {
        if (scrollTarget !== null && scrollTarget.active)
            scrollTarget.scrollBy(delta);
    }
    property real contentShift: 0
    onReserveBackChanged: contentShift = reserveBack ? 24 : 0
    Behavior on contentShift { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
}
