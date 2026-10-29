import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

/**
 * Command-backed bar widget. The provider is a local executable invoked with an
 * argv array; it writes one JSON object to stdout. No shell interpolation happens
 * here, and the provider's interval/timeout come from the instance config.
 */
Item {
    id: root

    property real s: 1
    property var item: null
    property bool active: false

    readonly property var config: item && item.config && typeof item.config === "object" ? item.config : ({})
    readonly property var command: config.command && config.command.length > 0 ? config.command : []
    property string label: config.label || "Status"
    readonly property string iconName: config.icon || "sparkles"
    readonly property string surface: config.surface || ""
    readonly property string url: config.url || ""

    property string value: ""
    property string detail: ""
    property string state: "idle"
    property string tooltip: ""

    signal requestSurface(string name)

    implicitWidth: content.implicitWidth
    implicitHeight: Math.max(17 * root.s, content.implicitHeight)
    width: implicitWidth
    height: implicitHeight

    function apply(text) {
        try {
            var data = JSON.parse(text);
            if (!data || typeof data !== "object")
                throw new Error("provider output is not an object");
            root.label = data.label || root.label;
            root.value = data.value === undefined ? "" : String(data.value);
            root.detail = data.detail || "";
            root.state = data.state || "ok";
            root.tooltip = data.tooltip || "";
        } catch (error) {
            root.state = "error";
            root.value = "!";
            root.detail = "Invalid provider output";
        }
    }

    function refresh() {
        if (root.command.length === 0 || process.running)
            return;
        process.running = true;
        timeout.restart();
    }

    onActiveChanged: if (active) refresh()

    Process {
        id: process
        command: root.command
        stdout: StdioCollector { id: output }
        onExited: (code) => {
            timeout.stop();
            if (code === 0)
                root.apply(output.text);
            else {
                root.state = "error";
                root.value = "!";
                root.detail = "Provider exited with code " + code;
            }
        }
    }

    Timer {
        id: timeout
        interval: Math.max(5, Number(root.config.timeout) || 10) * 1000
        repeat: false
        onTriggered: {
            if (process.running)
                process.running = false;
            root.state = "error";
            root.value = "!";
            root.detail = "Provider timed out";
        }
    }

    Timer {
        interval: Math.max(5, Number(root.config.interval) || 300) * 1000
        repeat: true
        running: root.command.length > 0
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4 * root.s

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 15 * root.s
            height: 15 * root.s
            name: root.iconName
            color: root.state === "error" ? Theme.vermLit : Theme.subtle
            stroke: 1.7
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.value.length > 0
            text: root.value
            color: root.state === "error" ? Theme.vermLit : Theme.cream
            font.family: Theme.font
            font.pixelSize: Typography.size("body", root.s)
            font.weight: Font.Medium
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 140 * root.s)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.value.length > 0 && root.detail.length > 0
            text: root.detail
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: Typography.size("caption", root.s)
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 180 * root.s)
        }
    }

    HoverHandler {
        id: hover
        enabled: root.active
        cursorShape: root.surface.length > 0 || root.url.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.active && (root.surface.length > 0 || root.url.length > 0)
        onClicked: {
            if (root.surface.length > 0)
                root.requestSurface(root.surface);
            else if (root.url.length > 0)
                Qt.openUrlExternally(root.url);
        }
    }

    Tooltip {
        s: root.s
        title: root.label
        desc: root.detail.length > 0 ? root.detail : root.tooltip
        show: hover.hovered
        placement: "below"
    }
}
