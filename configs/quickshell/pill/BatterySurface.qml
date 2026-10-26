pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 蓄 BATTERY surface: a typographic read-out for the laptop battery. The
 * percentage is the hero, set over a time-to-empty/full subline, with a thin
 * charge meter and an adaptive stat list (Rate / Health / Capacity) beneath a
 * hairline. Health drops when UPower can't report it and the time line drops
 * when no estimate exists; on AC-full the subline reads "Plugged in". Charging
 * warms the percentage, subline and meter to the flame tones. Exposes
 * `implicitHeight` from its content and docks Ame as a seam at the charge head.
 */
PillSurface {
    id: root

    /** Opens the TLP surface from the battery-care row at the foot of the card. */
    signal requestSurface(string name)

    onOpenChanged: if (open) PowerHistory.refresh()

    mTop: 16
    mLeft: 19
    mRight: 19
    mBottom: 16

    implicitHeight: content.implicitHeight

    /**
     * Where the seam docks: the head of the charge meter, mirroring the
     * seek-stroke head on the media card. Sits clear of the hero number and
     * tracks the charge level. mapToItem isn't reactive, so the void reads
     * force re-eval across the morph and on charge changes.
     */
    readonly property point chargeHead: {
        void root.width;
        void root.height;
        void Battery.frac;
        void meter.width;
        return meter.mapToItem(root, meter.width * Battery.frac, meter.height / 2);
    }

    ameForm: "seam"
    amePoint: chargeHead

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "蓄"
            title: "BATTERY"
            showIcon: false

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.stateLabel
                color: Battery.charging ? Theme.flameGlow : Theme.dim
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.1 * root.s
            }
        }

        Column {
            width: parent.width
            topPadding: 16 * root.s
            bottomPadding: 14 * root.s
            spacing: 9 * root.s

            Text {
                id: pctText
                text: Battery.present ? Battery.pct + "%" : "—"
                color: Battery.low ? Theme.vermLit : (Battery.charging ? Theme.flameGlow : Theme.cream)
                font.family: Theme.font
                font.pixelSize: 46 * root.s
                font.weight: Font.Bold
                font.letterSpacing: -1 * root.s
                font.features: { "tnum": 1 }
            }

            Text {
                readonly property string body: !Battery.present
                    ? "No battery"
                    : (Battery.full
                        ? "Plugged in"
                        : (Battery.hasTime
                            ? Battery.timeStr + (Battery.charging ? " to full" : " remaining")
                            : ""))
                visible: body.length > 0
                text: body
                color: Battery.charging ? Theme.flameCore : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            id: meter
            width: parent.width
            height: 3 * root.s
            visible: Battery.present
            radius: 1.5 * root.s
            color: Theme.threadBg

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Battery.frac
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Battery.charging ? Theme.vermLit : Theme.vermDeep }
                    GradientStop { position: 1.0; color: Battery.charging ? Theme.flameGlow : Theme.vermLit }
                }
            }
        }

        Item {
            width: parent.width
            height: PowerHistory.ready ? 56 * root.s : 0
            visible: PowerHistory.ready

            Row {
                id: historyBars
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 14 * root.s
                height: 22 * root.s
                spacing: 2 * root.s

                Repeater {
                    model: PowerHistory.hourly
                    Item {
                        required property real modelData
                        width: (historyBars.width - 23 * historyBars.spacing) / 24
                        height: historyBars.height

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: modelData > 0
                                ? Math.max(2 * root.s, (modelData / Math.max(1, PowerHistory.peak24h)) * parent.height)
                                : 2 * root.s
                            radius: 1 * root.s
                            color: modelData > 0 ? Theme.verm : Theme.threadBg
                            opacity: modelData > 0 ? 0.55 + 0.45 * (modelData / Math.max(1, PowerHistory.peak24h)) : 0.5
                        }
                    }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                text: "24h draw · " + PowerHistory.avg24h.toFixed(1)
                    + " W avg · peak " + PowerHistory.peak24h.toFixed(1) + " W"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.Medium
            }
        }

        Column {
            width: parent.width
            topPadding: 16 * root.s
            spacing: 10 * root.s

            component StatRow: Item {
                id: stat
                width: parent ? parent.width : 0
                height: vText.implicitHeight
                property string label: ""
                property string value: ""
                property bool warm: false

                Text {
                    anchors.left: parent.left
                    anchors.baseline: vText.baseline
                    text: stat.label
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.8 * root.s
                }

                Text {
                    id: vText
                    anchors.right: parent.right
                    text: stat.value
                    color: stat.warm ? Theme.flameGlow : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 12.5 * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }

            StatRow {
                visible: Math.abs(Battery.rateW) >= 0.05
                label: "Rate"
                value: (Battery.rateW > 0 ? "+" : "−") + Math.abs(Battery.rateW).toFixed(1) + " W"
                warm: Battery.charging
            }

            StatRow {
                visible: PowerHistory.ready && PowerHistory.avg1h > 0
                label: "1h avg"
                value: PowerHistory.avg1h.toFixed(1) + " W"
            }

            StatRow {
                visible: Battery.healthSupported
                label: "Health"
                value: Battery.health + "%"
                warm: true
            }

            StatRow {
                visible: Battery.capacityWh >= 1
                label: "Capacity"
                value: Battery.capacityWh.toFixed(1) + " Wh"
            }
        }

        Item {
            width: parent.width
            height: 12 * root.s
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.threadBg
        }

        Item {
            width: parent.width
            height: 38 * root.s
            visible: Battery.present

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 3 * root.s
                anchors.bottomMargin: 3 * root.s
                radius: 8 * root.s
                color: careArea.containsMouse ? Theme.frameBg : "transparent"
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 6 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: "Battery care"
                color: careArea.containsMouse ? Theme.cream : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 6 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: "Power  ›"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.Medium
                font.letterSpacing: 0.8 * root.s
            }

            MouseArea {
                id: careArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.requestSurface("tlp")
            }
        }
    }
}
