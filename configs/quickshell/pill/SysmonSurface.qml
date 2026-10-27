pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 系 SYSTEM surface: a flat washi card of live machine vitals fed by the Sysmon
 * singleton. The header carries the kanji, label and uptime. Below it sit flame
 * rectangular horizontal gauges for CPU, IGPU and memory load, with a vermilion
 * bar and the value at the right; a second row reads CPU/IGPU temperature and fan
 * RPM. A COMPUTE card exposes governor/EPP/profile/clock/load/pressure and links
 * to TLP. Every hwmon/thermal/power-supply sensor is listed in grouped cards,
 * followed by the network/disk/swap/VRAM strip and the fan curve. On a machine
 * with no IGPU telemetry the IGPU gauge and
 * VRAM cell drop and the remaining dials recentre. System polling lives in the
 * singleton and only runs while this surface is open.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 19
    mRight: 19
    mBottom: 16

    implicitHeight: content.implicitHeight
    signal requestSurface(string name)

    readonly property var dialKeys: Sysmon.hasGpu ? ["cpu", "gpu", "mem"] : ["cpu", "mem"]
    readonly property var cellKeys: Sysmon.hasVram ? ["net", "disk", "swap", "vram"] : ["net", "disk", "swap"]
    readonly property var sensorKeys: {
        var out = [];
        if (!Sensors.available)
            return out;
        if (Sensors.cpuTemp >= 0)
            out.push("cpuTemp");
        if (Sensors.gpuTemp >= 0)
            out.push("gpuTemp");
        if (Sensors.fanRpm >= 0)
            out.push("fan");
        return out;
    }
    readonly property var sensorGroups: {
        var order = ["Temperatures", "Clocks", "Power", "Battery", "Power supply",
                     "USB-C", "Fans", "Voltages", "Currents", "Energy", "Other"];
        var groups = {};
        if (!Sensors.available)
            return [];
        for (let i = 0; i < Sensors.list.length; i++) {
            const item = Sensors.list[i] || {};
            const label = String(item.label || "").toUpperCase();
            const type = String(item.type || "");
            // The three dials and the dedicated fan block already own these.
            if (type === "temperature_core"
                    && (label === "CPU" || label === "GPU" || label === "IGPU"))
                continue;
            if (label === "FAN RPM" || label === "FAN LEVEL")
                continue;
            var group = item.group || "Other";
            if (order.indexOf(group) < 0)
                group = "Other";
            if (groups[group] === undefined)
                groups[group] = [];
            groups[group].push(item);
        }
        var out = [];
        for (let j = 0; j < order.length; j++) {
            if (groups[order[j]] && groups[order[j]].length > 0)
                out.push({ title: order[j], items: groups[order[j]] });
        }
        return out;
    }

    readonly property var computeItems: [
        { label: "Governor", value: Sysmon.governor.length > 0 ? Sysmon.governor : "—" },
        { label: "EPP", value: Sysmon.epp.length > 0 ? Sysmon.epp.replace(/_/g, " ") : "—" },
        { label: "Profile", value: Sysmon.platformProfile.length > 0 ? Sysmon.platformProfile : "—" },
        { label: "Clock", value: (Sysmon.freqMhz / 1000).toFixed(2) + " / "
            + (Sysmon.maxFreqMhz / 1000).toFixed(2) + " GHz · " + Sysmon.cores + "c" },
        { label: "Load 1/5/15", value: Sysmon.load1.toFixed(2) + "  " + Sysmon.load5.toFixed(2) + "  " + Sysmon.load15.toFixed(2) },
        { label: "Pressure C·M·I", value: Sysmon.pressureCpu.toFixed(0) + " · "
            + Sysmon.pressureMem.toFixed(0) + " · " + Sysmon.pressureIo.toFixed(0) + "%" }
    ]

    function sensorValue(item) {
        var v = Number(item.value);
        if (!isFinite(v))
            return "—";
        return Math.abs(v - Math.round(v)) < 0.05 ? String(Math.round(v)) : v.toFixed(1);
    }

    function sensorUnit(item) {
        if (item.unit === "C") return "°C";
        if (item.unit === "R") return "RPM";
        if (item.unit === "PWM") return "";
        return item.unit || "";
    }

    function sensorTrend(item) {
        var label = String(item.label || "").toUpperCase();
        if (label === "BAT RATE")
            return Sensors.batteryTrend;
        if (label === "POW RATE")
            return Sensors.powerTrend;
        return 0;
    }

    property var focusRowItem: null

    /** Open sensor groups survive the 2 s sensor refresh that rebuilds the Repeater. */
    property var sensorGroupOpen: ({})

    function reportRowHover(row, hovered) {
        if (hovered)
            focusRowItem = row;
        else if (focusRowItem === row)
            focusRowItem = null;
    }

    function activateRow(row) {}

    function sensorArc(key) {
        if (key === "fan")
            return Math.max(0, Math.min(100, Sensors.fanRpm * 100 / Sensors.fanMax));
        return key === "cpuTemp" ? Sensors.cpuTemp : Sensors.gpuTemp;
    }

    function sensorBig(key) {
        if (key === "fan")
            return "" + Sensors.fanRpm;
        return "" + (key === "cpuTemp" ? Sensors.cpuTemp : Sensors.gpuTemp);
    }

    function sensorLabel(key) {
        return key === "fan" ? "FAN"
            : key === "cpuTemp" ? Sensors.cpuLabel : Sensors.gpuLabel;
    }

    function sensorSub(key) {
        if (key === "fan")
            return "LEVEL " + Sensors.fanLevel;
        return "TEMP";
    }

    onActiveChanged: {
        Sysmon.open = active;
        Sensors.open = active;
        if (active) {
            Sensors.refresh();
            ThinkPad.refresh();
        }
    }

    /**
     * The soul ember rests with the 系 header kanji: the kanji is the lantern,
     * the bead its flame, hovering just above the glyph with its wick rising into
     * it. Anchored to the header rather than the dial row so the ember sits in the
     * same deliberate spot whether three dials or two are shown (the header never
     * changes with IGPU presence). With glyphs off the kanji is hidden, so the
     * anchor falls back to the SYSTEM label's left edge, vertically centred on the
     * header, and never floats. Mapped into surface-local space so the host can
     * offset it by the surface origin.
     */
    readonly property point soulPoint: {
        void root.width;
        void root.height;
        if (Flags.showGlyphs)
            return kanji.mapToItem(root, kanji.width / 2, -3 * root.s);
        return sysLabel.mapToItem(root, -8 * root.s, sysLabel.height / 2);
    }

    ameForm: open ? "soul" : "off"
    amePoint: soulPoint

    component Dial: Item {
        id: dial

        property real arc: 0
        property string big: ""
        property string unit: ""
        property string sub: ""
        property string label: ""

        width: 100 * root.s
        height: 62 * root.s

        Rectangle {
            anchors.fill: parent
            radius: 10 * root.s
            color: Theme.tileBg
            border.width: 1
            border.color: Theme.frameBorder
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 9 * root.s
            anchors.top: parent.top
            anchors.topMargin: 7 * root.s
            text: dial.label
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 7.5 * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.8 * root.s
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 9 * root.s
            anchors.top: parent.top
            anchors.topMargin: 4 * root.s
            spacing: 2 * root.s

            Text {
                text: dial.big
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 18 * root.s
                font.weight: Font.ExtraBold
                font.letterSpacing: -0.5 * root.s
                font.features: { "tnum": 1 }
            }
            Text {
                anchors.baseline: parent.children[0].baseline
                visible: dial.unit.length > 0
                text: dial.unit
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 9 * root.s
                font.weight: Font.Bold
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 9 * root.s
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 9 * root.s
            text: dial.sub
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 8 * root.s
            font.weight: Font.Medium
            elide: Text.ElideRight
            width: parent.width - 18 * root.s
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 9 * root.s
            anchors.rightMargin: 9 * root.s
            anchors.bottomMargin: 4 * root.s
            height: 3 * root.s
            radius: 1.5 * root.s
            color: Qt.alpha(Theme.onGlow, 0.10)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, dial.arc)) / 100
                height: parent.height
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.vermBurn }
                    GradientStop { position: 1; color: Theme.vermLit }
                }
                Behavior on width { NumberAnimation { duration: Math.round(700 * Motion.mult); easing.type: Easing.OutCubic } }
            }
        }
    }

    component SectionHead: Item {
        id: section

        property string title: ""
        property string meta: ""

        width: parent ? parent.width : 0
        height: 16 * root.s

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: section.title
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 7.5 * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1 * root.s
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: section.meta.length > 0
            text: section.meta
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 7.5 * root.s
            font.weight: Font.Medium
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.7 * root.s
        }
    }

    component SensorGroup: Item {
        id: group

        property string title: ""
        property var items: []
        property bool open: false
        property bool initialOpen: false

        Component.onCompleted: if (initialOpen) open = true
        width: parent ? parent.width : 0
        height: head.height + (open ? flow.implicitHeight + 6 * root.s : 0)
        clip: true
        Behavior on height { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

        Item {
            id: head
            width: parent.width
            height: 20 * root.s

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: group.title
                color: group.open ? Theme.cream : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 8.5 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.8 * root.s
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 92 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: group.items.length + " READ"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 7 * root.s
                font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.6 * root.s
            }

            GlyphIcon {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 11 * root.s
                height: 11 * root.s
                name: group.open ? "chevron-up" : "chevron-down"
                color: headArea.containsMouse ? Theme.cream : Theme.faint
                stroke: 1.7
            }

            MouseArea {
                id: headArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: group.open = !group.open
            }
        }

        Flow {
            id: flow
            y: head.height
            width: parent.width
            spacing: 4 * root.s

            Repeater {
                model: group.items

                Item {
                    id: sensorCell
                    required property var modelData
                    width: (flow.width - 8 * root.s) / 3
                    height: 27 * root.s

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: sensorCell.modelData.label
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 7 * root.s
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        spacing: 2 * root.s

                        Text {
                            text: root.sensorValue(sensorCell.modelData)
                            color: root.sensorTrend(sensorCell.modelData) > 0 ? Theme.vermLit : Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                        Text {
                            text: root.sensorUnit(sensorCell.modelData)
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 7.5 * root.s
                            font.weight: Font.Medium
                        }
                        Text {
                            visible: root.sensorTrend(sensorCell.modelData) !== 0
                            text: root.sensorTrend(sensorCell.modelData) > 0 ? "▲" : "▼"
                            color: root.sensorTrend(sensorCell.modelData) > 0 ? Theme.vermLit : Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 7 * root.s
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }
    }

        Column {
            id: content
            width: parent.width
            spacing: 0

            Item {
                width: parent.width
                height: 24 * root.s

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9 * root.s

                    Text {
                        id: kanji
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Flags.showGlyphs
                        text: "系"
                        color: Theme.cream
                        font.family: Theme.fontJp
                        font.weight: Font.Medium
                        font.pixelSize: 16 * root.s
                    }
                    Text {
                        id: sysLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SYSTEM"
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.8 * root.s
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sysmon.uptime
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Bold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1 * root.s
                    font.features: { "tnum": 1 }
                }
            }

            Item { width: 1; height: 14 * root.s }

            Row {
                id: dialRow
                width: parent.width
                height: 62 * root.s
                spacing: 7 * root.s

                Repeater {
                    model: root.dialKeys

                    Dial {
                        required property int index
                        required property var modelData
                        readonly property string key: modelData
                        readonly property int val: key === "cpu" ? Sysmon.cpu : key === "gpu" ? Sysmon.gpu : Sysmon.memPct

                        width: (dialRow.width - (root.dialKeys.length - 1) * 7 * root.s) / root.dialKeys.length
                        height: dialRow.height

                        arc: val
                        big: key === "mem" ? Sysmon.memUsedGb.toFixed(1) : "" + val
                        unit: key === "mem" ? "GB" : "%"
                        label: key === "gpu" ? "IGPU" : key
                        sub: key === "mem" ? "/ " + Sysmon.memTotalGb.toFixed(0) + " GB" : ""
                    }
                }
            }

            Item { width: 1; height: 10 * root.s }

            Row {
                id: sensorRow
                width: parent.width
                height: root.sensorKeys.length > 0 ? 58 * root.s : 0
                visible: root.sensorKeys.length > 0
                spacing: 7 * root.s

                Repeater {
                    model: root.sensorKeys

                    Dial {
                        required property int index
                        required property var modelData
                        readonly property string key: modelData

                        width: (sensorRow.width - (root.sensorKeys.length - 1) * 7 * root.s) / root.sensorKeys.length
                        height: sensorRow.height

                        arc: root.sensorArc(key)
                        big: root.sensorBig(key)
                        unit: key === "fan" ? "RPM" : "°C"
                        label: root.sensorLabel(key)
                        sub: root.sensorSub(key)
                    }
                }
            }

            Item { width: 1; height: 16 * root.s }

            SectionHead { title: "Activity" }
            Item { width: 1; height: 8 * root.s }

            Item {
                width: parent.width
                height: 30 * root.s

                Repeater {
                    model: root.cellKeys

                    Item {
                        id: cell
                        required property int index
                        required property var modelData
                        readonly property string key: modelData

                        width: parent.width / root.cellKeys.length
                        height: parent.height
                        x: index * width

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.topMargin: 2 * root.s
                            anchors.bottomMargin: 2 * root.s
                            height: parent.height - 4 * root.s
                            width: 1
                            visible: cell.index > 0
                            color: Theme.hairSoft
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4 * root.s

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cell.key === "net" ? "Net · MB/s"
                                    : cell.key === "disk" ? "Disk · %"
                                    : cell.key === "swap" ? "Swap · GB"
                                    : "VRAM · GB"
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 7.5 * root.s
                                font.weight: Font.Bold
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 0.7 * root.s
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 7 * root.s
                                visible: cell.key === "net"

                                Text {
                                    text: "↓" + Sysmon.netDown.toFixed(1)
                                    color: Theme.cream
                                    font.family: Theme.font
                                    font.pixelSize: 12 * root.s
                                    font.weight: Font.ExtraBold
                                    font.features: { "tnum": 1 }
                                }
                                Text {
                                    text: "↑" + Sysmon.netUp.toFixed(1)
                                    color: Theme.vermLit
                                    font.family: Theme.font
                                    font.pixelSize: 12 * root.s
                                    font.weight: Font.ExtraBold
                                    font.features: { "tnum": 1 }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: cell.key !== "net"
                                text: cell.key === "disk" ? "" + Sysmon.diskPct
                                    : cell.key === "swap" ? Sysmon.swapUsedGb.toFixed(1)
                                    : Sysmon.vramUsedGb.toFixed(1) + " / " + Sysmon.vramTotalGb.toFixed(0)
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 12 * root.s
                                font.weight: Font.ExtraBold
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: ThinkPad.present ? 16 * root.s : 0
            }

            SectionHead { title: "Cooling"; visible: ThinkPad.present }
            FanCurvePanel {
                width: parent.width
                s: root.s
                surface: root
            }

            Item { width: 1; height: 18 * root.s }

            SectionHead { title: "Compute" }
            Item { width: 1; height: 7 * root.s }

            Column {
                id: computeCol
                width: parent.width
                spacing: 4 * root.s

                Flow {
                    width: parent.width
                    spacing: 4 * root.s

                    Repeater {
                        model: root.computeItems

                        Item {
                            required property var modelData
                            width: (parent.width - 4 * root.s) / 2
                            height: 25 * root.s

                            Text {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                text: parent.modelData.label
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 7.5 * root.s
                                font.weight: Font.Medium
                                font.capitalization: Font.AllUppercase
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                text: parent.modelData.value
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 10 * root.s
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 21 * root.s

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Power policy → TLP"
                        color: tlpArea.containsMouse ? Theme.cream : Theme.vermLit
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: tlpArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestSurface("tlp")
                    }
                }

                Text {
                    width: parent.width
                    text: "Read-only here; TLP owns governor and profile."
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 8 * root.s
                    wrapMode: Text.WordWrap
                }
            }

            Item { width: 1; height: 18 * root.s }

            SectionHead {
                title: "Sensors"
                meta: Sensors.available ? Sensors.list.length + " read" : ""
                visible: Sensors.available
            }

            Item {
                width: parent.width
                height: Sensors.available ? 7 * root.s : 0
            }

            Column {
                width: parent.width
                spacing: 2 * root.s
                visible: Sensors.available

                Repeater {
                    model: root.sensorGroups

                    SensorGroup {
                        id: sensorGroup
                        required property var modelData
                        width: parent.width
                        title: modelData.title
                        items: modelData.items
                        initialOpen: root.sensorGroupOpen[modelData.title] === true
                        onOpenChanged: {
                            if (root.sensorGroupOpen[modelData.title] !== open)
                                root.sensorGroupOpen[modelData.title] = open;
                        }
                    }
                }
            }

            Item { width: 1; height: 18 * root.s }
        }
}
