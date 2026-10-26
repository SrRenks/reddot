pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Fan-curve table. The surface owns the draft; this component only renders it
 * and emits edit/apply/reset. Eight rows, one per thinkfan level.
 */
Column {
    id: curve

    property real s: 1
    property var surface: null
    property var rows: []
    property bool busy: false
    property bool dirty: false

    signal edited(int index, string edge, int value)
    signal applied()
    signal reset()

    width: parent ? parent.width : 0
    spacing: 0

    Item {
        width: parent.width
        height: 40 * curve.s

        Row {
            id: chart
            width: parent.width
            height: parent.height
            spacing: 4 * curve.s

            Repeater {
                model: curve.rows

                Item {
                    id: bar
                    required property var modelData
                    width: (chart.width - 7 * 4 * curve.s) / 8
                    height: chart.height

                    Rectangle {
                        x: 0
                        y: 4 * curve.s
                        width: parent.width
                        height: 26 * curve.s
                        radius: 2 * curve.s
                        color: Theme.frameBg
                    }

                    Rectangle {
                        x: 0
                        y: 4 * curve.s + (100 - bar.modelData.high) / 100 * 26 * curve.s
                        width: parent.width
                        height: Math.max(2 * curve.s, (bar.modelData.high - bar.modelData.low) / 100 * 26 * curve.s)
                        radius: 2 * curve.s
                        color: Theme.verm
                        Behavior on y { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 32 * curve.s
                        text: bar.modelData.level
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 7.5 * curve.s
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }

    Item {
        width: parent.width
        height: help.implicitHeight + 8 * curve.s

        Text {
            id: help
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 2 * curve.s
            text: "Temperature band per fan level, in °C. Low and high are the hysteresis edges for that level."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9 * curve.s
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
        }
    }

    Repeater {
        model: curve.rows

        SettingsField {
            id: row
            required property var modelData
            required property int index
            surface: curve.surface
            label: "Level " + row.modelData.level

            Row {
                spacing: 4 * curve.s

                ScrubValue {
                    s: curve.s
                    value: row.modelData.low
                    from: 0
                    to: 100
                    step: 1
                    enabled: !curve.busy
                    onEdited: (v) => curve.edited(row.index, "low", v)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "–"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9 * curve.s
                }

                ScrubValue {
                    s: curve.s
                    value: row.modelData.high
                    from: 0
                    to: 100
                    step: 1
                    enabled: !curve.busy
                    onEdited: (v) => curve.edited(row.index, "high", v)
                }
            }
        }
    }

    Item {
        width: parent.width
        height: 30 * curve.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * curve.s

            ChipButton {
                s: curve.s
                text: "Apply curve"
                lit: curve.dirty
                enabled: curve.dirty && !curve.busy
                opacity: enabled ? 1 : 0.45
                onClicked: curve.applied()
            }

            ChipButton {
                s: curve.s
                text: "Reset"
                visible: curve.dirty
                enabled: !curve.busy
                onClicked: curve.reset()
            }
        }
    }
}
