pragma Singleton
import QtQuick
import Quickshell

/**
 * Catalog of every component that can be placed in the pill chrome. Rendering
 * still lives in the QML components; this file owns identity, naming, the two
 * presentation modes and the hosts an instance may occupy.
 *
 * `bar` is intentionally a definition without a default instance: it is the
 * container itself, listed in the catalog so Settings can treat it like any
 * other component instead of hiding it as special chrome.
 */
Singleton {
    id: catalog

    readonly property var definitions: [
        {
            id: "workspaces", name: "Workspaces", icon: "layers",
            description: "Workspace dots for the active monitor",
            target: "launcher",
            category: "navigation", modes: ["widget", "icon"], defaultMode: "widget",
            defaultConfig: { workspaceDisplay: "dots" },
            defaultHost: "bar.left", defaultOrder: 0,
            allowedHosts: ["bar.left", "bar.center"]
        },
        {
            id: "clock", name: "Clock", icon: "clock",
            description: "Time and date; opens the calendar",
            target: "calendar",
            category: "navigation", modes: ["widget", "icon"], defaultMode: "widget",
            defaultHost: "bar.center", defaultOrder: 0,
            allowedHosts: ["bar.left", "bar.center"]
        },
        {
            id: "weather", name: "Weather", icon: "cloud",
            description: "Current temperature and conditions",
            target: "calendar",
            category: "information", modes: ["icon", "widget"], defaultMode: "icon",
            defaultHost: "bar.right", defaultOrder: 0, status: true,
            allowedHosts: ["bar.left", "bar.center", "bar.right", "settings.catalog"]
        },
        {
            id: "minimized", name: "Minimized apps", icon: "app-window",
            description: "Windows parked on the minimized stash",
            target: "stash",
            category: "navigation", modes: ["icon", "widget"], defaultMode: "icon",
            defaultHost: "bar.right", defaultOrder: 1, status: true,
            allowedHosts: ["bar.left", "bar.center", "bar.right", "settings.catalog"]
        },
        {
            id: "tray", name: "System tray", icon: "layers",
            description: "Status icons published by applications",
            category: "information", modes: ["icon", "widget"], defaultMode: "icon",
            defaultHost: "bar.right", defaultOrder: 2, status: true,
            allowedHosts: ["bar.left", "bar.center", "bar.right", "settings.catalog"]
        },
        {
            id: "dnd", name: "Do not disturb", icon: "dnd",
            description: "Notification state",
            action: "toggle-dnd",
            category: "controls", modes: ["icon", "widget"], defaultMode: "icon",
            defaultHost: "bar.right", defaultOrder: 3, status: true,
            allowedHosts: ["bar.left", "bar.center", "bar.right", "settings.catalog"]
        },
        {
            id: "network", name: "Network", icon: "wifi",
            description: "Wi-Fi, Bluetooth and battery in one cluster",
            target: "wifi",
            category: "controls", modes: ["icon", "widget"], defaultMode: "icon",
            defaultHost: "bar.right", defaultOrder: 4, status: true,
            allowedHosts: ["bar.left", "bar.center", "bar.right", "settings.catalog"]
        },
        {
            id: "inbox", name: "Notifications", icon: "inbox",
            description: "Unread notification history",
            target: "link",
            category: "information", modes: ["icon", "widget"], defaultMode: "icon",
            defaultHost: "bar.right", defaultOrder: 5, status: true,
            allowedHosts: ["bar.left", "bar.center", "bar.right", "settings.catalog"]
        },
        {
            id: "mixer", name: "Mixer", icon: "mixer",
            description: "Audio faders and routing",
            target: "mixer",
            category: "controls", modes: ["icon", "widget"], defaultMode: "icon",
            defaultHost: "bar.right", defaultOrder: 6, status: true,
            allowedHosts: ["bar.left", "bar.center", "bar.right", "settings.catalog"]
        },
        {
            id: "sound", name: "Sound", icon: "waves",
            description: "Equalizer and output effects",
            target: "sound",
            category: "controls", modes: ["icon", "widget"], defaultMode: "icon",
            defaultHost: "bar.right", defaultOrder: 7, status: true,
            allowedHosts: ["bar.left", "bar.center", "bar.right", "settings.catalog"]
        },
        {
            id: "thinkpad", name: "ThinkPad", icon: "thinkpad",
            description: "Fan, LEDs and TrackPoint controls",
            target: "thinkpad",
            category: "hardware", modes: ["icon", "widget"], defaultMode: "icon",
            defaultHost: "bar.right", defaultOrder: 8, status: true,
            allowedHosts: ["bar.left", "bar.center", "bar.right", "settings.catalog"]
        },
        {
            id: "sysmon", name: "System", icon: "monitor",
            description: "Sensors, cooling and compute",
            target: "sysmon",
            category: "information", modes: ["icon", "widget"], defaultMode: "icon",
            defaultHost: "bar.right", defaultOrder: 9, status: true,
            allowedHosts: ["bar.left", "bar.center", "bar.right", "settings.catalog"]
        },
        {
            id: "updates", name: "System packages", icon: "download",
            description: "Pending package updates across native, AUR and Flatpak",
            target: "packages",
            category: "information", modes: ["widget", "icon"], defaultMode: "widget",
            defaultHost: "bar.right", defaultOrder: 10, status: true,
            allowedHosts: ["bar.left", "bar.center", "bar.right", "settings.catalog"]
        },
        {
            id: "recorder", name: "Recorder", icon: "record",
            description: "Screen recording state and controls",
            target: "recorder",
            category: "controls", modes: ["icon", "widget"], defaultMode: "icon",
            defaultHost: "bar.right", defaultOrder: 11, status: true,
            allowedHosts: ["bar.left", "bar.center", "bar.right", "settings.catalog"]
        },
        {
            id: "settings", name: "Settings", icon: "cog",
            description: "Preferences and controls",
            target: "settings",
            category: "navigation", modes: ["icon", "widget"], defaultMode: "icon",
            defaultHost: "bar.right", defaultOrder: 12, status: true,
            allowedHosts: ["bar.left", "bar.center", "bar.right", "settings.catalog"]
        },
        {
            id: "power", name: "Power", icon: "shutdown",
            description: "Session and power actions",
            target: "power",
            category: "controls", modes: ["icon", "widget"], defaultMode: "icon",
            defaultHost: "bar.right", defaultOrder: 13, status: true,
            allowedHosts: ["bar.left", "bar.center", "bar.right", "settings.catalog"]
        },
        {
            id: "command", name: "Command status", icon: "sparkles",
            description: "External command provider with JSON output",
            category: "extension", modes: ["icon", "widget"], defaultMode: "widget",
            defaultHost: "bar.right", defaultOrder: 50, optional: true,
            allowedHosts: ["bar.left", "bar.center", "bar.right"]
        },
        {
            id: "bar", name: "Bar", icon: "layers",
            description: "The horizontal chrome container",
            category: "layout", modes: ["icon", "widget"], defaultMode: "widget",
            defaultHost: "settings.catalog", defaultOrder: 0, container: true,
            allowedHosts: ["settings.catalog"]
        }
    ]

    function byId(id) {
        for (var i = 0; i < catalog.definitions.length; i++)
            if (catalog.definitions[i].id === id)
                return catalog.definitions[i];
        return null;
    }

    function allIds() {
        return catalog.definitions.map(function (def) { return def.id; });
    }

    function statusIds() {
        return catalog.definitions
            .filter(function (def) { return def.status === true; })
            .sort(function (a, b) { return a.defaultOrder - b.defaultOrder; })
            .map(function (def) { return def.id; });
    }

    function label(id) {
        var def = catalog.byId(id);
        return def ? def.name : id;
    }

    function supportsMode(id, mode) {
        var def = catalog.byId(id);
        return def ? def.modes.indexOf(mode) >= 0 : false;
    }
}
