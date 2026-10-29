pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Hyprland
import "Singletons"

/**
 * Status cluster, instantiated only while the bar is expanded. Keeping this
 * file separate lets the idle pill avoid building network, tray, media, and
 * system widgets that cannot be clicked until hover.
 */
Item {
    id: root

    property var pill: null
    property bool live: false

    readonly property var statusOrder: {
        var base = BarLayout.statusOrder.slice();
        return Flags.barStatusReverse ? base.slice().reverse() : base;
    }
    readonly property real statusGap: 12 * (pill ? pill.s : 1)

    function statusOnBar(id) {
        return BarLayout.enabled(id) && BarLayout.hostOf(id) === "bar.right"
            && BarLayout.mode(id) === "icon";
    }

    function statusWidth(id) {
        switch (id) {
        case "weather":    return weatherGlance.visible ? weatherGlance.implicitWidth : 0;
        case "minimized":  return minimized.visible ? minimized.width : 0;
        case "tray":       return trayItem.visible ? trayItem.width : 0;
        case "dnd":        return dndIcon.visible ? dndIcon.width : 0;
        case "network":    return networkGroup.visible ? networkGroup.width : 0;
        case "inbox":      return inboxIcon.width;
        case "mixer":      return mixerIcon.width;
        case "sound":      return soundIcon.width;
        case "thinkpad":   return thinkpadIcon.width;
        case "sysmon":     return sysmonIcon.width;
        case "updates":    return updatesIcon.visible ? updatesIcon.width : 0;
        case "recorder":   return recorderIcon.width;
        case "settings":   return settingsIcon.width;
        case "power":      return powerIcon.width;
        }
        return 0;
    }

    function statusX(id) {
        var x = 0;
        var any = false;
        for (var i = 0; i < statusOrder.length; i++) {
            var key = statusOrder[i];
            if (key === id)
                return x;
            var w = statusWidth(key);
            if (w <= 0)
                continue;
            if (any)
                x += statusGap;
            x += w;
            any = true;
        }
        return x;
    }

    readonly property real totalWidth: {
        var x = 0;
        var any = false;
        for (var i = 0; i < statusOrder.length; i++) {
            var w = statusWidth(statusOrder[i]);
            if (w <= 0)
                continue;
            if (any)
                x += statusGap;
            x += w;
            any = true;
        }
        return x;
    }

    function soulPointFor(target) {
        const drop = 12 * pill.s;
        if (target === "wifi")
            return wifiIcon.mapToItem(pill, wifiIcon.width / 2, wifiIcon.height + drop * 0.55);
        if (target === "bt")
            return btIcon.mapToItem(pill, btIcon.width / 2, btIcon.height + drop * 0.55);
        if (target === "battery")
            return batteryIcon.mapToItem(pill, batteryIcon.width / 2, batteryIcon.height + drop * 0.55);
        if (target === "inbox")
            return inboxIcon.mapToItem(pill, inboxIcon.width / 2, inboxIcon.height + drop * 0.55);
        if (target === "mixer")
            return mixerIcon.mapToItem(pill, mixerIcon.width / 2, mixerIcon.height + drop * 0.55);
        if (target === "sound")
            return soundIcon.mapToItem(pill, soundIcon.width / 2, soundIcon.height + drop * 0.55);
        if (target === "thinkpad")
            return thinkpadIcon.mapToItem(pill, thinkpadIcon.width / 2, thinkpadIcon.height + drop * 0.55);
        if (target === "power")
            return powerIcon.mapToItem(pill, powerIcon.width / 2, powerIcon.height + drop * 0.55);
        if (target === "settings")
            return settingsIcon.mapToItem(pill, settingsIcon.width / 2, settingsIcon.height + drop * 0.55);
        if (target === "recorder")
            return recorderIcon.mapToItem(pill, recorderIcon.width / 2, recorderIcon.height + drop * 0.55);
        if (target === "sysmon")
            return sysmonIcon.mapToItem(pill, sysmonIcon.width / 2, sysmonIcon.height + drop * 0.55);
        return null;
    }

    width: totalWidth
    height: 22 * (pill ? pill.s : 1)

Item {
    anchors.verticalCenter: parent.verticalCenter
    width: totalWidth
    height: 22 * pill.s

    Row {
        id: weatherGlance
        anchors.verticalCenter: parent.verticalCenter
        x: statusX("weather")
        visible: statusOnBar("weather") && Weather.ready
        width: visible ? implicitWidth : 0
        spacing: 5 * pill.s

        HoverHandler {
            id: weatherHover
            cursorShape: Qt.PointingHandCursor
            enabled: root.live
        }
        TapHandler {
            enabled: root.live
            onTapped: pill.requestSurface("calendar")
        }

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * pill.s
            height: 16 * pill.s
            name: Weather.glyphFor(Weather.codeNow, Weather.isDay)
            color: Theme.subtle
            stroke: 1.8
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.tempNow + "°"
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: Typography.size("bodyLarge", pill.s)
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }
    }

    MinimizedTray {
        id: minimized
        anchors.verticalCenter: parent.verticalCenter
        x: statusX("minimized")
        s: pill.s
        screenName: pill.screenName
        enabled: root.live
        visible: statusOnBar("minimized") && count > 0
        width: visible ? implicitWidth : 0
    }

    Tray {
        id: trayItem
        anchors.verticalCenter: parent.verticalCenter
        x: statusX("tray")
        visible: statusOnBar("tray")
        width: visible ? implicitWidth : 0
        s: pill.s
        barWindow: pill.barWindow
        enabled: root.live
    }

    Item {
        id: dndIcon
        anchors.verticalCenter: parent.verticalCenter
        x: statusX("dnd")
        visible: statusOnBar("dnd") && Flags.dnd
        width: visible ? 16 * pill.s : 0
        height: 16 * pill.s

        Shape {
            id: dndShape

            width: 16
            height: 16
            scale: pill.s
            transformOrigin: Item.TopLeft
            x: dndShape.boundingRect.width > 0
               ? dndIcon.width / 2 - (dndShape.boundingRect.x + dndShape.boundingRect.width / 2) * pill.s
               : (dndIcon.width - 16 * pill.s) / 2
            y: dndShape.boundingRect.height > 0
               ? dndIcon.height / 2 - (dndShape.boundingRect.y + dndShape.boundingRect.height / 2) * pill.s
               : (dndIcon.height - 16 * pill.s) / 2
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.vermLit
                strokeWidth: 1.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: 5.2; startY: 12.2
                PathLine { x: 12.2; y: 12.2 }
                PathLine { x: 12.2; y: 7.2 }
                PathCubic {
                    control1X: 12.2; control1Y: 5.4
                    control2X: 11.2; control2Y: 4.0
                    x: 9.5; y: 3.5
                }
            }
            ShapePath {
                strokeColor: Theme.vermLit
                strokeWidth: 1.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 6.8; startY: 13.6
                PathLine { x: 9.2; y: 13.6 }
            }
            ShapePath {
                strokeColor: Theme.vermLit
                strokeWidth: 1.6
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 3.2; startY: 2.8
                PathLine { x: 13.0; y: 13.4 }
            }
        }
        HoverHandler {
            id: dndHover
            cursorShape: Qt.PointingHandCursor
            enabled: root.live
        }
    }

    Row {
        id: networkGroup
        anchors.verticalCenter: parent.verticalCenter
        x: statusX("network")
        visible: statusOnBar("network") && (pill.wifiDev !== null || pill.btAdapter !== null || Battery.present)
        spacing: 12 * pill.s

        Item {
            id: wifiIcon
            anchors.verticalCenter: parent.verticalCenter
            visible: Flags.barWifi && pill.wifiDev !== null
            width: visible ? 15 * pill.s : 0
            height: 15 * pill.s

            WifiGlyph {
                anchors.centerIn: parent
                s: pill.s
                level: pill.wifiLevel
                on: pill.wifiOn
                stroke: 1.7
            }

            MouseArea {
                id: wifiArea
                anchors.fill: parent
                anchors.margins: -6 * pill.s
                hoverEnabled: true
                enabled: root.live
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (e) => {
                    if (e.button === Qt.RightButton) {
                        if (typeof Networking !== "undefined" && Networking)
                            Networking.wifiEnabled = !Networking.wifiEnabled;
                        return;
                    }
                    pill.requestSurface("wifi");
                }
                onContainsMouseChanged: if (containsMouse) pill.soulTarget = "wifi"
            }
        }

        Item {
            id: btIcon
            anchors.verticalCenter: parent.verticalCenter
            visible: Flags.barBt && pill.btAdapter !== null
            width: visible ? 15 * pill.s + (btLowPct.visible ? btLowPct.implicitWidth + 4 * pill.s : 0) : 0
            height: 15 * pill.s

            GlyphIcon {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 15 * pill.s
                height: 15 * pill.s
                name: "bluetooth"
                color: btArea.containsMouse ? Theme.cream
                    : (Peripherals.connectedCount > 0 ? Theme.vermLit
                    : (pill.btOn ? Theme.iconDim : Qt.alpha(Theme.iconDim, 0.4)))
                stroke: 1.7
            }

            Text {
                id: btLowPct
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: Peripherals.lowestPct >= 0 && Peripherals.lowestPct <= Peripherals.lowAt
                text: Peripherals.lowestPct + "%"
                color: Theme.vermLit
                font.family: Theme.font
                font.pixelSize: Typography.size("body", pill.s)
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }

            MouseArea {
                id: btArea
                anchors.fill: parent
                anchors.margins: -6 * pill.s
                hoverEnabled: true
                enabled: root.live
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (e) => {
                    if (e.button === Qt.RightButton) {
                        if (pill.btAdapter)
                            pill.btAdapter.enabled = !pill.btAdapter.enabled;
                        return;
                    }
                    pill.requestSurface("bt");
                }
                onContainsMouseChanged: if (containsMouse) pill.soulTarget = "bt"
            }
        }

        Item {
            id: batteryIcon
            anchors.verticalCenter: parent.verticalCenter
            visible: Flags.barBattery && Battery.present
            width: visible ? battPct.implicitWidth : 0
            height: 17 * pill.s

            Text {
                id: battPct
                anchors.centerIn: parent
                text: Battery.pct + "%"
                color: Battery.low ? Theme.vermLit : (Battery.charging ? Theme.flameGlow : Theme.subtle)
                font.family: Theme.font
                font.pixelSize: Typography.size("bodyLarge", pill.s)
                font.weight: Battery.charging ? Font.DemiBold : Font.Medium
                font.features: { "tnum": 1 }
            }

            MouseArea {
                id: batteryArea
                anchors.fill: parent
                anchors.margins: -6 * pill.s
                hoverEnabled: true
                enabled: root.live
                cursorShape: Qt.PointingHandCursor
                onClicked: pill.requestSurface("battery")
                onContainsMouseChanged: if (containsMouse) pill.soulTarget = "battery"
            }
        }
    }

    StatusTooltip {
        nodeId: "weather"
        s: pill.s
        anchorItem: weatherGlance
        show: weatherHover.hovered
    }

    StatusTooltip {
        nodeId: "dnd"
        s: pill.s
        anchorItem: dndIcon
        show: dndHover.hovered
    }

    StatusTooltip {
        nodeId: "network"
        s: pill.s
        anchorItem: networkGroup
        show: wifiArea.containsMouse || btArea.containsMouse || batteryArea.containsMouse
    }

    StatusTooltip {
        nodeId: "inbox"
        s: pill.s
        anchorItem: inboxIcon
        show: inboxArea.containsMouse
    }

    StatusTooltip {
        nodeId: "mixer"
        s: pill.s
        anchorItem: mixerIcon
        show: mixerArea.containsMouse
    }

    StatusTooltip {
        nodeId: "sound"
        s: pill.s
        anchorItem: soundIcon
        show: soundArea.containsMouse
    }

    StatusTooltip {
        nodeId: "thinkpad"
        s: pill.s
        anchorItem: thinkpadIcon
        show: thinkpadArea.containsMouse
    }

    StatusTooltip {
        nodeId: "sysmon"
        s: pill.s
        anchorItem: sysmonIcon
        show: sysmonArea.containsMouse
    }

    StatusTooltip {
        nodeId: "updates"
        s: pill.s
        anchorItem: updatesIcon
        show: updatesArea.containsMouse
    }

    StatusTooltip {
        nodeId: "recorder"
        s: pill.s
        anchorItem: recorderIcon
        show: recorderArea.containsMouse
    }

    StatusTooltip {
        nodeId: "settings"
        s: pill.s
        anchorItem: settingsIcon
        show: settingsArea.containsMouse
    }

    StatusTooltip {
        nodeId: "power"
        s: pill.s
        anchorItem: powerIcon
        show: powerArea.containsMouse
    }

    Item {
        id: inboxIcon
        anchors.verticalCenter: parent.verticalCenter
        x: statusX("inbox")
        visible: statusOnBar("inbox")
        width: visible ? 17 * pill.s : 0
        height: 17 * pill.s

        GlyphIcon {
            anchors.fill: parent
            name: "inbox"
            color: inboxArea.containsMouse ? Theme.cream : Theme.iconDim
            stroke: 1.7
        }

        Rectangle {
            visible: Notifs.unread > 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -2 * pill.s
            anchors.rightMargin: -2 * pill.s
            width: 5 * pill.s
            height: 5 * pill.s
            radius: width / 2
            color: Theme.flameGlow
        }

        MouseArea {
            id: inboxArea
            anchors.fill: parent
            anchors.margins: -6 * pill.s
            hoverEnabled: true
            enabled: root.live
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.requestSurface("link")
            onContainsMouseChanged: if (containsMouse) pill.soulTarget = "inbox"
        }
    }

    Item {
        id: mixerIcon
        anchors.verticalCenter: parent.verticalCenter
        x: statusX("mixer")
        visible: statusOnBar("mixer")
        width: visible ? 17 * pill.s : 0
        height: 17 * pill.s

        GlyphIcon {
            anchors.fill: parent
            name: "mixer"
            color: mixerArea.containsMouse ? Theme.cream : Theme.iconDim
            stroke: 1.7
        }

        MouseArea {
            id: mixerArea
            anchors.fill: parent
            anchors.margins: -6 * pill.s
            hoverEnabled: true
            enabled: root.live
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.requestSurface("mixer")
            onContainsMouseChanged: if (containsMouse) pill.soulTarget = "mixer"
        }
    }

    Item {
        id: soundIcon
        anchors.verticalCenter: parent.verticalCenter
        x: statusX("sound")
        visible: statusOnBar("sound")
        width: visible ? 17 * pill.s : 0
        height: 17 * pill.s

        GlyphIcon {
            anchors.fill: parent
            name: "music"
            color: soundArea.containsMouse ? Theme.cream : (Sound.eq ? Theme.vermLit : Theme.iconDim)
            stroke: 1.7
        }

        MouseArea {
            id: soundArea
            anchors.fill: parent
            anchors.margins: -6 * pill.s
            hoverEnabled: true
            enabled: root.live
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.requestSurface("sound")
            onContainsMouseChanged: if (containsMouse) pill.soulTarget = "sound"
        }
    }

    Item {
        id: thinkpadIcon
        anchors.verticalCenter: parent.verticalCenter
        x: statusX("thinkpad")
        visible: statusOnBar("thinkpad") && ThinkPad.present
        width: visible ? 17 * pill.s : 0
        height: 17 * pill.s

        GlyphIcon {
            anchors.fill: parent
            name: "laptop"
            color: thinkpadArea.containsMouse ? Theme.cream : "#ffffff"
            stroke: 1.7
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: -1 * pill.s
            visible: ThinkPad.present
            width: 4 * pill.s
            height: 4 * pill.s
            radius: width / 2
            color: Theme.verm
        }

        MouseArea {
            id: thinkpadArea
            anchors.fill: parent
            anchors.margins: -6 * pill.s
            hoverEnabled: true
            enabled: root.live
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.requestSurface("thinkpad")
            onContainsMouseChanged: if (containsMouse) pill.soulTarget = "thinkpad"
        }
    }

    Item {
        id: sysmonIcon
        anchors.verticalCenter: parent.verticalCenter
        x: statusX("sysmon")
        visible: statusOnBar("sysmon")
        width: visible ? 17 * pill.s : 0
        height: 17 * pill.s

        GlyphIcon {
            anchors.fill: parent
            name: "monitor"
            color: sysmonArea.containsMouse ? Theme.cream : Theme.iconDim
            stroke: 1.7
        }

        MouseArea {
            id: sysmonArea
            anchors.fill: parent
            anchors.margins: -6 * pill.s
            hoverEnabled: true
            enabled: root.live
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.requestSurface("sysmon")
            onContainsMouseChanged: if (containsMouse) pill.soulTarget = "sysmon"
        }
    }

    Item {
        id: updatesIcon
        anchors.verticalCenter: parent.verticalCenter
        x: statusX("updates")
        readonly property bool hasUpdates: PackageUpdates.total > 0 || PackageUpdates.hasError
        readonly property string countText: PackageUpdates.total > 99
            ? "99+" : (String(PackageUpdates.total) + (PackageUpdates.hasError ? "!" : ""))
        visible: statusOnBar("updates") && PackageUpdates.enabled && hasUpdates
        width: visible ? 13 * pill.s + 5 * pill.s + updatesBadge.width : 0
        height: 17 * pill.s

        GlyphIcon {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 13 * pill.s
            height: 13 * pill.s
            name: "download"
            color: PackageUpdates.important ? Theme.verm
                : (PackageUpdates.hasError || PackageUpdates.stale ? Theme.flameCore
                : (updatesArea.containsMouse ? Theme.cream : Theme.iconDim))
            stroke: 1.8
        }

        Rectangle {
            id: updatesBadge
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: updatesLabel.implicitWidth + 9 * pill.s
            height: 15 * pill.s
            radius: height / 2
            color: PackageUpdates.important
                ? Qt.alpha(Theme.verm, updatesArea.containsMouse ? 0.22 : 0.16)
                : (PackageUpdates.hasError || PackageUpdates.stale
                    ? Qt.alpha(Theme.flameCore, 0.14) : Theme.frameBg)
            border.width: 1
            border.color: PackageUpdates.important ? Qt.alpha(Theme.vermLit, 0.42)
                : (PackageUpdates.hasError || PackageUpdates.stale
                    ? Qt.alpha(Theme.flameCore, 0.38) : Theme.hairSoft)

            Text {
                id: updatesLabel
                anchors.centerIn: parent
                text: updatesIcon.countText
                color: PackageUpdates.important ? Theme.vermLit
                    : (PackageUpdates.hasError || PackageUpdates.stale ? Theme.flameCore
                    : (updatesArea.containsMouse ? Theme.cream : Theme.subtle))
                font.family: Theme.font
                font.pixelSize: Typography.size("micro", pill.s)
                font.weight: Font.Bold
                font.letterSpacing: 0.2 * pill.s
                font.features: { "tnum": 1 }
            }
        }

        MouseArea {
            id: updatesArea
            anchors.fill: parent
            anchors.margins: -6 * pill.s
            hoverEnabled: true
            enabled: root.live
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.requestSurface("packages")
            onContainsMouseChanged: if (containsMouse) pill.soulTarget = "updates"
        }
    }

    Item {
        id: recorderIcon
        anchors.verticalCenter: parent.verticalCenter
        x: statusX("recorder")
        visible: statusOnBar("recorder")
        width: visible ? 17 * pill.s : 0
        height: 17 * pill.s

        GlyphIcon {
            anchors.fill: parent
            visible: !ScreenRec.recording
            name: "video"
            color: recorderArea.containsMouse ? Theme.cream : Theme.iconDim
            stroke: 1.7
        }

        Rectangle {
            anchors.centerIn: parent
            visible: ScreenRec.recording
            width: 12 * pill.s
            height: 12 * pill.s
            radius: width / 2
            color: Theme.verm
            SequentialAnimation on opacity {
                running: ScreenRec.recording
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
            }
        }

        MouseArea {
            id: recorderArea
            anchors.fill: parent
            anchors.margins: -6 * pill.s
            hoverEnabled: true
            enabled: root.live
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (e) => {
                if (e.button === Qt.RightButton) {
                    if (ScreenRec.recording)
                        ScreenRec.stop();
                    return;
                }
                pill.requestSurface("recorder");
            }
            onDoubleClicked: (e) => {
                if (e.button === Qt.LeftButton && ScreenRec.recording)
                    ScreenRec.stop();
            }
            onContainsMouseChanged: if (containsMouse) pill.soulTarget = "recorder"
        }
    }

    Item {
        id: settingsIcon
        anchors.verticalCenter: parent.verticalCenter
        x: statusX("settings")
        visible: statusOnBar("settings")
        width: visible ? 17 * pill.s : 0
        height: 17 * pill.s

        GlyphIcon {
            anchors.fill: parent
            name: "cog"
            color: settingsArea.containsMouse ? Theme.cream : Theme.iconDim
            stroke: 1.6
        }

        MouseArea {
            id: settingsArea
            anchors.fill: parent
            anchors.margins: -6 * pill.s
            hoverEnabled: true
            enabled: root.live
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.requestSurface("settings")
            onContainsMouseChanged: if (containsMouse) pill.soulTarget = "settings"
        }
    }

    Item {
        id: powerIcon
        anchors.verticalCenter: parent.verticalCenter
        x: statusX("power")
        visible: statusOnBar("power")
        width: visible ? 17 * pill.s : 0
        height: 17 * pill.s

        GlyphIcon {
            anchors.fill: parent
            name: "shutdown"
            color: powerArea.containsMouse ? Theme.cream : Theme.iconDim
            stroke: 1.7
        }

        MouseArea {
            id: powerArea
            anchors.fill: parent
            anchors.margins: -6 * pill.s
            hoverEnabled: true
            enabled: root.live
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.requestSurface("power")
            onContainsMouseChanged: if (containsMouse) pill.soulTarget = "power"
        }
    }
}
}
