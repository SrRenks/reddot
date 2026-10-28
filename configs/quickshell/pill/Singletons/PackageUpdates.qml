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
    property real lastCheckEpoch: 0
    property string errorText: ""
    property string officialState: "pending"
    property string aurState: "pending"
    property string flatpakState: "pending"
    property int ageTick: 0

    readonly property bool important: importantNames.length > 0
    readonly property bool hasError: errorText.length > 0
    readonly property bool stale: {
        ageTick;
        return lastCheckEpoch > 0
            && (Date.now() - lastCheckEpoch) > Math.max(5, minutes) * 120000;
    }
    readonly property bool officialAvailable: officialState !== "missing"
    readonly property bool aurAvailable: aurState !== "missing"
    readonly property bool flatpakAvailable: flatpakState !== "missing"
    readonly property string ageText: {
        ageTick;
        if (lastCheckEpoch <= 0)
            return "";
        var mins = Math.floor((Date.now() - lastCheckEpoch) / 60000);
        if (mins < 1) return "just now";
        if (mins < 60) return mins + " min ago";
        var hours = Math.floor(mins / 60);
        if (hours < 24) return hours + " h ago";
        return Math.floor(hours / 24) + " d ago";
    }

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
        var states = ({ official: "pending", aur: "pending", flatpak: "pending" });
        var errors = [];
        var lines = String(text || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line === "@@OFFICIAL@@") { section = "official"; continue; }
            if (line === "@@AUR@@") { section = "aur"; continue; }
            if (line === "@@FLATPAK@@") { section = "flatpak"; continue; }
            if (line.indexOf("@@OK:") === 0) {
                states[line.slice(5, line.length - 2)] = "ok";
                continue;
            }
            if (line.indexOf("@@ERR:") === 0) {
                var errSource = line.slice(6, line.length - 2);
                states[errSource] = "error";
                errors.push(errSource);
                continue;
            }
            if (line.indexOf("@@MISSING:") === 0) {
                states[line.slice(10, line.length - 2)] = "missing";
                continue;
            }
            if (line.length === 0 || line.charAt(0) === "@@")
                continue;
            var name = line.split(/\s+/)[0];
            if (name.length === 0)
                continue;
            if (section === "official") off.push(name);
            else if (section === "aur") aur.push(name);
            else if (section === "flatpak") flat.push(name);
        }

        // A failed source keeps the previous non-empty result instead of
        // flashing a misleading zero while pacman/yay/flatpak are unavailable.
        if (states.official === "error" && root.official.length > 0)
            off = root.official.slice();
        if (states.aur === "error" && root.aur.length > 0)
            aur = root.aur.slice();
        if (states.flatpak === "error" && root.flatpak.length > 0)
            flat = root.flatpak.slice();
        if (states.official === "missing")
            off = [];
        if (states.aur === "missing")
            aur = [];
        if (states.flatpak === "missing")
            flat = [];

        root.official = off;
        root.aur = aur;
        root.flatpak = flat;
        root.officialState = states.official;
        root.aurState = states.aur;
        root.flatpakState = states.flatpak;
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
        root.lastCheckEpoch = Date.now();
        root.errorText = errors.length > 0
            ? "Check failed: " + errors.join(", ") + ". Showing the last good count."
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
        command: ["sh", "-c",
            "printf '@@OFFICIAL@@\\n'; out=$(pacman -Qu 2>/dev/null); rc=$?; [ -n \"$out\" ] && printf '%s\\n' \"$out\"; [ $rc -le 1 ] && printf '@@OK:official@@\\n' || printf '@@ERR:official@@\\n'; "
            + "printf '@@AUR@@\\n'; if command -v yay >/dev/null 2>&1; then out=$(yay -Qua 2>/dev/null); rc=$?; [ -n \"$out\" ] && printf '%s\\n' \"$out\"; [ $rc -le 1 ] && printf '@@OK:aur@@\\n' || printf '@@ERR:aur@@\\n'; else printf '@@MISSING:aur@@\\n'; fi; "
            + "printf '@@FLATPAK@@\\n'; if command -v flatpak >/dev/null 2>&1; then out=$(flatpak remote-ls --updates --columns=application 2>/dev/null); rc=$?; [ -n \"$out\" ] && printf '%s\\n' \"$out\"; [ $rc -eq 0 ] && printf '@@OK:flatpak@@\\n' || printf '@@ERR:flatpak@@\\n'; else printf '@@MISSING:flatpak@@\\n'; fi"]
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
