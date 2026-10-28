pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Periodic system package counter: official repos, AUR via yay, and Flatpak.
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
    property string errorText: ""

    readonly property bool important: importantNames.length > 0

    function isImportant(name) {
        var n = name.toLowerCase();
        if (n === "linux" || n.indexOf("linux-") === 0)
            return true;
        if (n === "mkinitcpio" || n.indexOf("mkinitcpio-") === 0)
            return true;
        if (n === "systemd" || n.indexOf("systemd-") === 0)
            return true;
        if (n === "glibc" || n === "gcc-libs" || n === "grub" || n === "grub-btrfs"
                || n === "systemd-boot" || n === "limine" || n === "refind"
                || n === "amd-ucode" || n === "intel-ucode"
                || n === "mesa" || n === "hyprland" || n === "quickshell")
            return true;
        if (n.indexOf("nvidia") === 0 || n.indexOf("vulkan-radeon") === 0
                || n.indexOf("vulkan-intel") === 0)
            return true;
        return false;
    }

    function namesFrom(text) {
        var out = [];
        var lines = String(text || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.length === 0)
                continue;
            var name = line.split(/\s+/)[0];
            if (name.length > 0)
                out.push(name);
        }
        return out;
    }

    function parse(text) {
        var off = [], aur = [], flat = [];
        var section = "";
        var lines = String(text || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line === "@@OFFICIAL@@") { section = "official"; continue; }
            if (line === "@@AUR@@") { section = "aur"; continue; }
            if (line === "@@FLATPAK@@") { section = "flatpak"; continue; }
            if (line.length === 0 || line.charAt(0) === "@@")
                continue;
            var name = line.split(/\s+/)[0];
            if (name.length === 0)
                continue;
            if (section === "official") off.push(name);
            else if (section === "aur") aur.push(name);
            else if (section === "flatpak") flat.push(name);
        }
        root.official = off;
        root.aur = aur;
        root.flatpak = flat;
        root.officialCount = off.length;
        root.aurCount = aur.length;
        root.flatpakCount = flat.length;
        root.total = off.length + aur.length + flat.length;
        var key = [];
        for (var j = 0; j < off.length; j++)
            if (root.isImportant(off[j])) key.push(off[j]);
        for (var k = 0; k < aur.length; k++)
            if (root.isImportant(aur[k])) key.push(aur[k]);
        root.importantNames = key;
        root.lastCheck = Qt.formatDateTime(new Date(), "HH:mm");
        root.errorText = "";
    }

    function check() {
        if (root.checking)
            return;
        root.checking = true;
        checkProc.running = true;
    }

    Process {
        id: checkProc
        command: ["sh", "-c",
            "printf '@@OFFICIAL@@\\n'; pacman -Qu 2>/dev/null || true; "
            + "printf '@@AUR@@\\n'; if command -v yay >/dev/null 2>&1; then yay -Qua 2>/dev/null || true; fi; "
            + "printf '@@FLATPAK@@\\n'; if command -v flatpak >/dev/null 2>&1; then flatpak remote-ls --updates --columns=application 2>/dev/null || true; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parse(this.text);
                root.checking = false;
            }
        }
        onExited: root.checking = false
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

    Component.onCompleted: if (root.enabled) root.check()
}
