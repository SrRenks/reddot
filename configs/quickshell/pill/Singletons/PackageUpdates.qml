pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "PackageUpdatesParser.js" as PackageParser

/**
 * Periodic system package counter: native repos, AUR via yay or paru, and Flatpak.
 * A small key-package list flags updates that change the kernel, initramfs,
 * bootloader, firmware or core desktop stack so the bar can turn red.
 */
Singleton {
    id: root

    property bool enabled: Flags.packageUpdatesEnabled
    property int minutes: Flags.packageCheckMinutes
    property bool checking: false
    property int officialCount: 0
    property int aurCount: 0
    property int flatpakCount: 0
    property int total: 0
    property var official: []
    property var aur: []
    property var flatpak: []
    property var importantNames: []
    property string lastCheck: ""
    property real lastCheckEpoch: 0
    property string errorText: ""
    property string backend: "unknown"
    property string officialState: "pending"
    property string aurState: "pending"
    property string flatpakState: "pending"
    property int ageTick: 0

    readonly property bool important: importantNames.length > 0
    readonly property bool hasError: errorText.length > 0
    readonly property bool stale: {
        void root.ageTick;
        return lastCheckEpoch > 0
            && (Date.now() - lastCheckEpoch) > Math.max(5, minutes) * 120000;
    }
    readonly property bool officialAvailable: officialState !== "missing"
    readonly property string backendLabel: {
        if (backend === "fedora") return "RPM/dnf";
        if (backend === "suse") return "RPM/zypper";
        if (backend === "debian") return "APT";
        if (backend === "arch") return "pacman";
        return "system";
    }
    readonly property string availabilityText: {
        var parts = [];
        parts.push(backendLabel + (officialAvailable ? "" : " unavailable"));
        if (aurAvailable)
            parts.push("AUR");
        if (flatpakAvailable)
            parts.push("Flatpak");
        return parts.join(" · ");
    }
    readonly property bool aurAvailable: aurState !== "missing"
    readonly property bool flatpakAvailable: flatpakState !== "missing"
    readonly property string ageText: {
        void root.ageTick;
        if (lastCheckEpoch <= 0)
            return "";
        var mins = Math.floor((Date.now() - lastCheckEpoch) / 60000);
        if (mins < 1) return "just now";
        if (mins < 60) return mins + " min ago";
        var hours = Math.floor(mins / 60);
        if (hours < 24) return hours + " h ago";
        return Math.floor(hours / 24) + " d ago";
    }

    function parse(text) {
        var result = PackageParser.parse(text, {
            official: root.official,
            aur: root.aur,
            flatpak: root.flatpak
        });
        root.official = result.official;
        root.aur = result.aur;
        root.flatpak = result.flatpak;
        root.backend = result.backend || "unknown";
        root.officialState = result.states.official;
        root.aurState = result.states.aur;
        root.flatpakState = result.states.flatpak;
        root.officialCount = result.official.length;
        root.aurCount = result.aur.length;
        root.flatpakCount = result.flatpak.length;
        root.total = result.total;
        root.importantNames = result.important;
        root.lastCheck = Qt.formatDateTime(new Date(), "HH:mm");
        root.lastCheckEpoch = Date.now();
        root.errorText = result.errors.length > 0
            ? "Check failed: " + result.errors.join(", ") + ". Showing the last good count."
            : "";
    }

    function check() {
        if (root.checking)
            return;
        root.checking = true;
        checkProc.running = true;
    }

    Process {
        id: checkProc
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/package-updates.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parse(this.text);
                root.checking = false;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim().length > 0)
                root.errorText = this.text.trim()
        }
        onExited: (code) => {
            root.checking = false;
            if (code !== 0 && root.errorText.length === 0)
                root.errorText = "Package check exited with code " + code;
        }
    }

    Timer {
        interval: Math.max(5, root.minutes) * 60000
        running: root.enabled
        repeat: true
        onTriggered: root.check()
    }

    Connections {
        target: Flags
        function onPackageUpdatesEnabledChanged() {
            if (Flags.packageUpdatesEnabled)
                root.check();
        }
    }

    Timer {
        interval: 30000
        running: root.lastCheckEpoch > 0
        repeat: true
        onTriggered: root.ageTick++
    }

    Component.onCompleted: if (root.enabled) root.check()
}
