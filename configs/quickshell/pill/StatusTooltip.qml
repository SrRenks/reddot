import QtQuick
import "lib/navigation.js" as Navigation

/** Hover label for a status-bar node; metadata comes from the navigation manifest. */
Tooltip {
    id: root

    property string nodeId: ""
    property Item anchorItem: null

    readonly property var meta: Navigation.statusInfo(nodeId)
    title: meta ? meta.title : ""
    desc: meta ? meta.sub : ""
    placement: "below"
    anchors.horizontalCenter: anchorItem ? anchorItem.horizontalCenter : parent.horizontalCenter
}
