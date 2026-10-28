import Quickshell.Io
import QtQuick
import Quickshell

ShellRoot {
    id: root

    property string outPath: Quickshell.env("REDDOT_TEST_OUT") || "/tmp/reddot-qml-test"
    property string pillPath: Quickshell.env("REDDOT_TEST_PILL") || ""
    property string result: "fail"

    Loader {
        id: surfaceLoader
        asynchronous: false
        source: "file://" + root.pillPath + "/PillSurface.qml"
    }

    Loader {
        id: segLoader
        asynchronous: false
        source: "file://" + root.pillPath + "/SettingsSeg.qml"
    }

    Loader {
        id: scrubLoader
        asynchronous: false
        source: "file://" + root.pillPath + "/ScrubValue.qml"
    }

    Timer {
        interval: 600
        running: true
        onTriggered: root.run()
    }

    function run() {
        var failures = [];
        var surface = surfaceLoader.item;
        var seg = segLoader.item;
        var scrub = scrubLoader.item;

        if (surface) {
            surface.width = 300;
            surface.height = 100;
            surface.open = true;
            if (surface.contentHeight < surface.height) failures.push("PillSurface content height is invalid");
        } else {
            failures.push("PillSurface did not load");
        }

        if (seg) {
            seg.s = 1;
            seg.options = [{ label: "A", value: "a" }, { label: "B", value: "b" }];
            seg.value = "a";
            if (seg.width <= 0 || seg.height <= 0) failures.push("segmented control did not lay out");
        } else {
            failures.push("SettingsSeg did not load");
        }

        if (scrub) {
            scrub.s = 1;
            scrub.value = 5;
            scrub.from = 0;
            scrub.to = 10;
            scrub.step = 1;
            var seen = -1;
            scrub.edited.connect(function (v) { seen = v; });
            scrub.bump(1);
            if (seen !== 6) failures.push("scrub bump emitted " + seen);
        } else {
            failures.push("ScrubValue did not load");
        }

        root.result = failures.length === 0 ? "pass" : "fail: " + failures.join("; ");
        writer.command = ["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "sh", root.result, root.outPath];
        writer.running = true;
    }

    Process {
        id: writer
        command: []
        onExited: Qt.quit()
    }
}
