pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/** CPU temperature history, sampled only while the surface is open. */
Item {
    id: graph

    property real s: 1
    property var samples: []
    property int current: -1

    width: parent ? parent.width : 0
    height: samples.length > 0 ? 46 * graph.s : 0
    visible: samples.length > 0

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        text: "CPU TEMP"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 8 * graph.s
        font.weight: Font.Bold
        font.letterSpacing: 1.0 * graph.s
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        text: graph.current >= 0 ? graph.current + "°" : ""
        color: Theme.subtle
        font.family: Theme.font
        font.pixelSize: 9 * graph.s
        font.weight: Font.DemiBold
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 14 * graph.s
        height: 24 * graph.s

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.threadBg
        }

        Row {
            id: bars
            width: parent.width
            height: parent.height
            spacing: 2 * graph.s

            Repeater {
                model: graph.samples

                Rectangle {
                    required property var modelData
                    width: Math.max(1.5 * graph.s, (bars.width - (graph.samples.length - 1) * 2 * graph.s) / Math.max(1, graph.samples.length))
                    height: Math.max(1.5 * graph.s, (Math.min(100, modelData) - 30) / 70 * 23 * graph.s)
                    anchors.bottom: parent.bottom
                    radius: 1 * graph.s
                    color: modelData >= 80 ? Theme.flameCore : (modelData >= 65 ? Theme.verm : Theme.vermDim)
                    Behavior on height { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
