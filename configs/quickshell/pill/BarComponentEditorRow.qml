import QtQuick
import "Singletons"

/**
 * Static catalog editor row. Keeping the rows explicit avoids the runtime
 * crash seen with a large Repeater of catalog definitions; each row still reads
 * its identity and current placement from the shared catalog/layout.
 */
SettingsRow {
    id: root

    property string componentId: ""

    readonly property var definition: BarCatalog.byId(root.componentId)
    readonly property var hostOptions: {
        var out = [];
        var hosts = root.definition ? root.definition.allowedHosts : [];
        for (var i = 0; i < hosts.length; i++) {
            var h = hosts[i];
            if (h.indexOf("bar.") !== 0)
                continue;
            out.push({
                label: h === "bar.left" ? "L" : (h === "bar.center" ? "C" : "R"),
                value: h
            });
        }
        return out;
    }
    readonly property var modeOptions: {
        var out = [];
        var modes = root.definition ? root.definition.modes : [];
        for (var i = 0; i < modes.length; i++)
            out.push({ label: modes[i] === "icon" ? "Icon" : "Widget", value: modes[i] });
        return out;
    }

    name: root.definition ? root.definition.name : root.componentId
    icon: root.definition ? root.definition.icon : "layers"
    sub: BarLayout.findHost(root.componentId) + " · " + BarLayout.mode(root.componentId)

    Row {
        spacing: 6 * root.s

        SettingsSeg {
            visible: root.modeOptions.length > 1
            s: root.s
            options: root.modeOptions
            value: BarLayout.mode(root.componentId)
            onPicked: (v) => BarLayout.setMode(root.componentId, v)
        }

        SettingsSeg {
            visible: root.hostOptions.length > 1
            s: root.s
            options: root.hostOptions
            value: BarLayout.hostOf(root.componentId)
            onPicked: (v) => BarLayout.setHost(root.componentId, v)
        }
    }
}
