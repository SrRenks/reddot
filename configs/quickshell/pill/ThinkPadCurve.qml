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
