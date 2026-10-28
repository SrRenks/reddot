pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/setInput.js" as SetInput
import "Singletons"

/**
 * 操 INPUT sub-surface: edits the pointer, keyboard and cursor settings that live
 * in the Hyprland Lua modules, writing each change straight back to its source so
 * the choice survives a restart. Pointer and keyboard fields rewrite input.lua
 * and reload Hyprland. The physical keyboard model (`kb_model`) is separate from
 * the ordered language/variant list (`kb_layout`/`kb_variant`); the list supports
 * adding, removing and direct selection, while Super+Space keeps cycling it.
 * Cursor size and theme apply live through `hyprctl setcursor` with no reload,
 * and persist by rewriting the XCURSOR/HYPRCURSOR env lines and the autostart
 * setcursor call. The theme list is scanned from the installed icon themes that
 * carry a `cursors/` folder. Reached from the settings index; morphs back on the
 * back chevron.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    /**
     * Row registry; scrub rows expose a bump that steps their ScrubValue one
     * increment. The layout row's vals gain the current layout at the end when it
     * is not in the curated list, so an exotic layout shows as-is and a click
     * wraps around to the start of the list.
     */
    rows: [
        { item: sensRow, kind: "scrub", bump: function (d) { sensScrub.bump(d); } },
        { item: accelRow, kind: "seg", vals: ["flat", "adaptive"], get: function () { return root.accelProfile; }, set: function (v) { root.accelProfile = v; root.writeInputField("accel_profile", "\"" + v + "\""); } },
        { item: modelRow, kind: "seg", vals: root.kbModelVals, get: function () { return root.kbModel; }, set: function (v) { root.setKbModel(v); } },
        { item: layoutRow, kind: "seg", vals: root.languageNames, get: function () { return root.activeLanguageName; }, set: function (v) { root.selectLanguageName(v); } },
        { item: rateRow, kind: "scrub", bump: function (d) { rateScrub.bump(d); } },
        { item: delayRow, kind: "scrub", bump: function (d) { delayScrub.bump(d); } },
        { item: numlockRow, kind: "toggle", get: function () { return root.numlockOn; }, set: function (v) { root.numlockOn = v; root.writeInputField("numlock_by_default", v ? "true" : "false"); } },
        { item: fingerprintRow, kind: "toggle", get: function () { return Flags.lockFingerprint; }, set: function (v) { Flags.lockFingerprint = v; } },
        { item: naturalRow, kind: "toggle", get: function () { return root.naturalScroll; }, set: function (v) { root.naturalScroll = v; root.writeInputKey("natural_scroll", v ? "true" : "false"); } },
        { item: tapRow, kind: "toggle", get: function () { return root.tapToClick; }, set: function (v) { root.tapToClick = v; root.writeInputKey("tap_to_click", v ? "true" : "false"); } },
        { item: typingRow, kind: "toggle", get: function () { return root.disableWhileTyping; }, set: function (v) { root.disableWhileTyping = v; root.writeInputKey("disable_while_typing", v ? "true" : "false"); } },
        { item: clickfingerRow, kind: "toggle", get: function () { return root.clickfinger; }, set: function (v) { root.clickfinger = v; root.writeInputKey("clickfinger_behavior", v ? "true" : "false"); } },
        { item: middleRow, kind: "toggle", get: function () { return root.middleButton; }, set: function (v) { root.middleButton = v; root.writeInputKey("middle_button_emulation", v ? "true" : "false"); } },
        { item: sizeRow, kind: "scrub", bump: function (d) { sizeScrub.bump(d); } },
        { item: themeRow, kind: "toggle", get: function () { return root.themeOpen; }, set: function (v) { root.themeOpen = v; } }
    ]

    property string note: ""

    readonly property string inputPath: Quickshell.env("HOME") + "/.config/hypr/modules/input.lua"
    readonly property string envPath: Quickshell.env("HOME") + "/.config/hypr/modules/env.lua"
    readonly property string autostartPath: Quickshell.env("HOME") + "/.config/hypr/modules/autostart.lua"

    property real sensitivity: 0
    property string accelProfile: "flat"
    property string kbModel: "auto"
    property var languages: []
    property string activeKeymap: ""
    property int activeIndex: -1
    property int repeatRate: 25
    property int repeatDelay: 600
    property bool numlockOn: false
    property bool naturalScroll: true
    property bool tapToClick: true
    property bool disableWhileTyping: true
    property bool clickfinger: false
    property bool middleButton: false
    property bool tpBusy: false
    property string tpNotice: ""
    readonly property bool hasPointing: ThinkPad.tpList.length > 0 || ThinkPad.doubletap >= 0
    property int cursorSize: 24
    property string cursorTheme: "Bibata-Modern-Ice"
    property var cursorThemes: []
    property bool themeOpen: false
    property bool fingerprintAvailable: false
    property string fingerprintStatus: "Checking fingerprint reader…"

    property string inputText: ""
    property string envText: ""
    property string autostartText: ""

    /** Per-field values captured on each open; the ScrubValue undo glyphs revert to these. */
    property var base: ({})

    readonly property var accelOptions: [
        { label: "Flat", value: "flat" },
        { label: "Adaptive", value: "adaptive" }
    ]

    /**
     * Each entry is a language+variant pair, matching Hyprland's parallel
     * kb_layout/kb_variant lists. The physical keyboard model is separate.
     */
    readonly property var kbCatalog: [
        { layout: "us", variant: "", short: "US", label: "English (US)", keymap: "English (US)" },
        { layout: "us", variant: "intl", short: "US INTL", label: "English (US, intl.)", keymap: "English (US, intl., with dead keys)" },
        { layout: "us", variant: "altgr-intl", short: "US ALTGR", label: "English (US, alt. intl.)", keymap: "English (US, alt. intl.)" },
        { layout: "gb", variant: "", short: "GB", label: "English (UK)", keymap: "English (UK)" },
        { layout: "de", variant: "", short: "DE", label: "German", keymap: "German" },
        { layout: "fr", variant: "", short: "FR", label: "French", keymap: "French" },
        { layout: "es", variant: "", short: "ES", label: "Spanish", keymap: "Spanish" },
        { layout: "it", variant: "", short: "IT", label: "Italian", keymap: "Italian" },
        { layout: "pt", variant: "", short: "PT", label: "Portuguese", keymap: "Portuguese" },
        { layout: "br", variant: "", short: "BR", label: "Portuguese (Brazil)", keymap: "Portuguese (Brazil)" },
        { layout: "tr", variant: "", short: "TR", label: "Turkish", keymap: "Turkish" },
        { layout: "ru", variant: "", short: "RU", label: "Russian", keymap: "Russian" },
        { layout: "jp", variant: "", short: "JP", label: "Japanese", keymap: "Japanese" },
        { layout: "kr", variant: "", short: "KR", label: "Korean", keymap: "Korean" }
    ]

    readonly property var kbModelOptions: [
        { label: "Auto", value: "auto" },
        { label: "ANSI", value: "pc104" },
        { label: "ISO", value: "pc105" },
        { label: "JIS", value: "jp106" }
    ]
    readonly property var kbModelVals: ["auto", "pc104", "pc105", "jp106"]

    readonly property var languageNames: {
        var out = [];
        for (var i = 0; i < languages.length; i++)
            out.push(languages[i].label);
        return out;
    }
    readonly property string activeLanguageName: {
        if (activeIndex >= 0 && activeIndex < languages.length)
            return languages[activeIndex].label;
        return activeKeymap.length > 0 ? activeKeymap : "";
    }
    readonly property string activeLanguageShort: {
        if (activeIndex >= 0 && activeIndex < languages.length)
            return languages[activeIndex].short;
        return activeKeymap.length > 0 ? activeKeymap : "—";
    }

    onActiveChanged: {
        if (active) {
            inputFile.reload();
            envFile.reload();
            autostartFile.reload();
            seed();
            kbStatus.running = true;
            themeProc.running = true;
            ThinkPad.refresh();
        } else {
            themeOpen = false;
            focusRowItem = null;
            kbIndex = -1;
        }
    }

    /**
     * Seeds every control from the live source files. Numbers fall back to the
     * defaults when a field is missing so a partially hand-edited config never
     * leaves a control blank.
     */
    function seed() {
        root.inputText = inputFile.text();
        root.envText = envFile.text();
        root.autostartText = autostartFile.text();

        var inp = root.inputText;
        var sens = parseFloat(SetInput.getField(inp, "sensitivity"));
        root.sensitivity = isNaN(sens) ? 0 : sens;
        var ap = SetInput.getField(inp, "accel_profile");
        root.accelProfile = ap.length > 0 ? ap : "flat";
        var kl = SetInput.getField(inp, "kb_layout");
        var kv = SetInput.getField(inp, "kb_variant");
        var km = SetInput.getField(inp, "kb_model");
        root.kbModel = km.length > 0 ? km : "auto";
        root.languages = root.pairEntries(kl, kv);
        var rr = parseInt(SetInput.getField(inp, "repeat_rate"), 10);
        root.repeatRate = isNaN(rr) ? 25 : rr;
        var rd = parseInt(SetInput.getField(inp, "repeat_delay"), 10);
        root.repeatDelay = isNaN(rd) ? 600 : rd;
        root.numlockOn = SetInput.getField(inp, "numlock_by_default") === "true";
        root.naturalScroll = SetInput.getKey(inp, "natural_scroll") === "true";
        root.tapToClick = SetInput.getKey(inp, "tap_to_click") === "true";
        root.disableWhileTyping = SetInput.getKey(inp, "disable_while_typing") === "true";
        root.clickfinger = SetInput.getKey(inp, "clickfinger_behavior") === "true";
        root.middleButton = SetInput.getKey(inp, "middle_button_emulation") === "true";

        var env = root.envText;
        var cs = parseInt(SetInput.getField(env, "XCURSOR_SIZE"), 10);
        root.cursorSize = isNaN(cs) ? 24 : cs;
        var ct = SetInput.getField(env, "XCURSOR_THEME");
        root.cursorTheme = ct.length > 0 ? ct : "Bibata-Modern-Ice";

        root.base = {
            sensitivity: root.sensitivity,
            repeatRate: root.repeatRate,
            repeatDelay: root.repeatDelay,
            cursorSize: root.cursorSize
        };
    }

    /**
     * Rewrites one input.lua field to `literal` (already formatted by the caller)
     * and reloads Hyprland so the change takes effect at once.
     */
    function writeInputField(name, literal) {
        var res = SetInput.setField(root.inputText, name, literal);
        if (!res.ok)
            return;
        root.inputText = res.text;
        inputWriter.setText(res.text);
        reloadTimer.restart();
    }

    function writeInputKey(name, literal) {
        var res = SetInput.setKey(root.inputText, name, literal);
        if (!res.ok)
            return;
        root.inputText = res.text;
        inputWriter.setText(res.text);
        reloadTimer.restart();
    }

    function splitCsv(text) {
        return String(text || "").split(",").map(function (part) { return part.trim(); });
    }

    function catalogFor(layout, variant) {
        for (var i = 0; i < root.kbCatalog.length; i++) {
            var c = root.kbCatalog[i];
            if (c.layout === layout && (c.variant || "") === (variant || ""))
                return c;
        }
        return null;
    }

    function pairEntries(layoutText, variantText) {
        var layouts = splitCsv(layoutText);
        var variants = splitCsv(variantText);
        var out = [];
        for (var i = 0; i < layouts.length; i++) {
            if (layouts[i].length === 0)
                continue;
            var variant = (i < variants.length ? variants[i] : "") || "";
            var c = catalogFor(layouts[i], variant);
            out.push({
                layout: layouts[i],
                variant: variant,
                label: c ? c.label : (layouts[i] + (variant.length > 0 ? " (" + variant + ")" : "")),
                short: c ? c.short : (layouts[i] + (variant.length > 0 ? "-" + variant : "")).toUpperCase(),
                keymap: c ? c.keymap : ""
            });
        }
        if (out.length === 0)
            out.push({ layout: "us", variant: "", label: "English (US)", short: "US", keymap: "English (US)" });
        return out;
    }

    function languageIndexOfLabel(label) {
        for (var i = 0; i < root.languages.length; i++)
            if (root.languages[i].label === label)
                return i;
        return -1;
    }

    function writeLanguages(next) {
        if (next.length === 0)
            return;
        var layouts = next.map(function (e) { return e.layout; }).join(",");
        var variants = next.map(function (e) { return e.variant || ""; }).join(",");
        root.languages = next;
        root.writeInputField("kb_layout", JSON.stringify(layouts));
        root.writeInputField("kb_variant", JSON.stringify(variants));
        kbStatus.running = true;
    }

    function addLanguage(layout, variant) {
        var c = root.catalogFor(layout, variant);
        var next = root.languages.slice();
        next.push({
            layout: layout,
            variant: variant || "",
            label: c ? c.label : (layout + (variant ? " (" + variant + ")" : "")),
            short: c ? c.short : (layout + (variant ? "-" + variant : "")).toUpperCase(),
            keymap: c ? c.keymap : ""
        });
        root.writeLanguages(next);
    }

    function removeLanguage(index) {
        if (index < 0 || index >= root.languages.length || root.languages.length <= 1)
            return;
        var next = root.languages.slice();
        next.splice(index, 1);
        root.writeLanguages(next);
    }

    function selectLanguage(index) {
        if (index < 0 || index >= root.languages.length)
            return;
        root.activeIndex = index;
        switchLayoutProc.layoutIndex = index;
        switchLayoutProc.running = true;
    }

    function selectLanguageName(name) {
        var i = root.languageIndexOfLabel(name);
        if (i >= 0)
            root.selectLanguage(i);
    }

    function cycleLanguage() {
        if (root.languages.length === 0)
            return;
        var next = (root.activeIndex + 1) % root.languages.length;
        root.selectLanguage(next);
    }

    function tpRun(args) {
        if (tpActionProc.running)
            return;
        tpBusy = true;
        tpNotice = "authentication required…";
        tpActionProc.command = ["/usr/bin/pkexec", ThinkPad.helper].concat(args);
        tpActionProc.running = true;
    }

    function setTp(name, value) {
        root.tpRun(["trackpoint", name, String(value)]);
    }

    function setDoubletap(value) {
        root.tpRun(["doubletap", value ? "1" : "0"]);
    }

    function setFnLock(value) {
        root.tpRun(["fnlock", value ? "1" : "0"]);
    }

    function tpLabel(name) {
        switch (name) {
        case "sensitivity": return "Sensitivity";
        case "speed": return "Speed";
        case "press_to_select": return "Press to select";
        case "dragging": return "Dragging";
        case "drift_time": return "Drift time";
        case "inertia": return "Inertia";
        }
        return name;
    }

    function setKbModel(v) {
        root.kbModel = v;
        root.writeInputField("kb_model", JSON.stringify(v === "auto" ? "" : v));
    }

    function readActiveKeymap(text) {
        try {
            var data = JSON.parse(text);
            var keyboards = data.keyboards || [];
            var keymap = "";
            for (var i = 0; i < keyboards.length; i++) {
                if (keyboards[i].active_keymap && keyboards[i].active_keymap.length > 0) {
                    keymap = keyboards[i].active_keymap;
                    break;
                }
            }
            root.activeKeymap = keymap;
            var idx = -1;
            for (var j = 0; j < root.languages.length; j++) {
                if (root.languages[j].keymap === keymap) {
                    idx = j;
                    break;
                }
            }
            // Some XKB descriptions differ slightly; fall back to a label prefix.
            if (idx < 0) {
                for (var k = 0; k < root.languages.length; k++) {
                    var label = root.languages[k].label.toLowerCase();
                    if (keymap.toLowerCase().indexOf(label) === 0) {
                        idx = k;
                        break;
                    }
                }
            }
            root.activeIndex = idx;
        } catch (e) {
            root.activeKeymap = "";
        }
    }

    /**
     * Applies a cursor theme/size pair live via `hyprctl setcursor`, then persists
     * it by rewriting the XCURSOR/HYPRCURSOR env lines and the autostart setcursor
     * call. No Hyprland reload is needed for the cursor.
     */
    function applyCursor(theme, size) {
        setcursorProc.theme = theme;
        setcursorProc.size = size;
        setcursorProc.running = true;

        var env = root.envText;
        var e1 = SetInput.setEnv(env, "XCURSOR_THEME", theme);
        var e2 = SetInput.setEnv(e1.ok ? e1.text : env, "XCURSOR_SIZE", String(size));
        var e3 = SetInput.setEnv(e2.ok ? e2.text : (e1.ok ? e1.text : env), "HYPRCURSOR_SIZE", String(size));
        if (e3.ok || e2.ok || e1.ok) {
            root.envText = e3.ok ? e3.text : (e2.ok ? e2.text : e1.text);
            envWriter.setText(root.envText);
        }

        var auto = SetInput.setCursorLine(root.autostartText, theme, size);
        if (auto.ok) {
            root.autostartText = auto.text;
            autostartWriter.setText(auto.text);
        }
    }

    FileView {
        id: inputFile
        path: root.inputPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: inputWriter
        path: root.inputPath
        atomicWrites: true
        printErrors: false
    }

    FileView {
        id: envFile
        path: root.envPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: envWriter
        path: root.envPath
        atomicWrites: true
        printErrors: false
    }

    FileView {
        id: autostartFile
        path: root.autostartPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: autostartWriter
        path: root.autostartPath
        atomicWrites: true
        printErrors: false
    }

    /**
     * Reload is debounced so a scrub drag writes the file per step but reloads
     * Hyprland once, and captured so a failed reload surfaces as the inline note
     * instead of vanishing with a detached process.
     */
    Timer {
        id: reloadTimer
        interval: 250
        repeat: false
        onTriggered: reloadProc.running = true
    }

    Process {
        id: reloadProc
        command: ["sh", "-c", "sleep 0.3; hyprctl reload"]
        onExited: function (exitCode) {
            root.note = exitCode === 0 ? "" : "Hyprland reload failed. The change is saved but not applied.";
        }
    }

    Process {
        id: kbStatus
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.readActiveKeymap(this.text)
        }
    }

    Process {
        id: switchLayoutProc
        property int layoutIndex: 0
        command: ["hyprctl", "switchxkblayout", "all", String(layoutIndex)]
        onExited: kbPollTimer.start()
    }

    Timer {
        id: kbPollTimer
        interval: 180
        repeat: false
        onTriggered: kbStatus.running = true
    }

    Timer {
        interval: 700
        running: root.active
        repeat: true
        onTriggered: if (!kbStatus.running) kbStatus.running = true
    }

    Process {
        id: setcursorProc
        property string theme: ""
        property int size: 24
        command: ["hyprctl", "setcursor", theme, String(size)]
    }

    Process {
        id: tpActionProc
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim().length > 0)
                root.tpNotice = this.text.trim();
        }
        onExited: (code) => {
            root.tpBusy = false;
            if (code === 0) {
                root.tpNotice = "saved";
                ThinkPad.refresh();
            } else if (root.tpNotice.length === 0) {
                root.tpNotice = "authentication cancelled or helper failed (" + code + ")";
            }
        }
    }

    Process {
        id: fingerprintProbe
        running: true
        command: ["sh", "-c", "command -v fprintd-list >/dev/null 2>&1 && fprintd-list \"$(id -un)\" >/dev/null 2>&1"]
        onExited: code => {
            root.fingerprintAvailable = code === 0;
            if (code === 0)
                root.fingerprintStatus = "Any enrolled finger can unlock the lock";
            else if (code === 127)
                root.fingerprintStatus = "fprintd is not installed";
            else
                root.fingerprintStatus = "No enrolled fingerprint on this machine";
        }
    }

    Process {
        id: themeProc
        command: ["sh", "-c", "{ printf '%s\\n' \"$HOME/.icons\" \"$HOME/.local/share/icons\" /usr/share/icons; printf '%s' \"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\" | tr ':' '\\n' | sed 's#/*$#/icons#'; } | sort -u | while IFS= read -r d; do [ -d \"$d\" ] || continue; for t in \"$d\"/*/; do [ -d \"$t/cursors\" ] && basename \"$t\"; done; done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n").filter(function (l) { return l.trim().length > 0; });
                root.cursorThemes = lines;
            }
        }
    }

    component GroupLabel: SettingsLabel { s: root.s }

    component FieldRow: SettingsField { surface: root }

    Column {
        id: content
        z: 100
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "操"
            title: "INPUT"
            showBack: true
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            spacing: 0

            GroupLabel { text: "Pointer" }

            FieldRow {
                id: sensRow
                label: "Sensitivity"
                caption: "Pointer speed offset"
                icon: "mouse"
                ScrubValue {
                    id: sensScrub
                    s: root.s
                    value: root.sensitivity
                    openValue: root.base.sensitivity
                    from: -1; to: 1; step: 0.1; decimals: 1
                    onEdited: v => {
                        root.sensitivity = v;
                        root.writeInputField("sensitivity", String(v));
                    }
                }
            }

            FieldRow {
                id: accelRow
                label: "Acceleration"
                caption: "How pointer speed follows motion"
                icon: "bolt"
                SettingsSeg {
                    s: root.s
                    options: root.accelOptions
                    value: root.accelProfile
                    onPicked: (v) => {
                        root.accelProfile = v;
                        root.writeInputField("accel_profile", "\"" + v + "\"");
                    }
                }
            }

            GroupLabel { text: "Keyboard" }

            FieldRow {
                id: modelRow
                label: "Keyboard model"
                caption: "Physical keys: ANSI is pc104, ISO is pc105. Separate from languages."
                icon: "keyboard"

                SettingsSeg {
                    s: root.s
                    options: root.kbModelOptions
                    value: root.kbModel
                    onPicked: (v) => root.setKbModel(v)
                }
            }

            FieldRow {
                id: layoutRow
                label: "Active language"
                caption: "Super+Space cycles; click the chip to advance"
                icon: "language"

                Rectangle {
                    width: 112 * root.s
                    height: 22 * root.s
                    radius: 9 * root.s
                    color: Qt.alpha(Theme.vermLit, 0.08)
                    border.width: 1
                    border.color: Theme.hairSoft

                    Text {
                        id: languageLbl
                        anchors.left: parent.left
                        anchors.leftMargin: 9 * root.s
                        anchors.right: cycleArrow.left
                        anchors.rightMargin: 5 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.activeLanguageShort
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    GlyphIcon {
                        id: cycleArrow
                        anchors.right: parent.right
                        anchors.rightMargin: 7 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: 11 * root.s
                        height: 11 * root.s
                        name: "refresh"
                        color: Theme.vermLit
                        stroke: 1.7
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cycleLanguage()
                    }
                }
            }

            KeyboardLanguages {
                id: languagesEditor
                width: parent.width
                s: root.s
                entries: root.languages
                catalog: root.kbCatalog
                activeKeymap: root.activeKeymap
                activeIndex: root.activeIndex
                activeLabel: root.activeLanguageName
                onActivate: (index) => root.selectLanguage(index)
                onCycle: root.cycleLanguage()
                onAdd: (layout, variant) => root.addLanguage(layout, variant)
                onRemove: (index) => root.removeLanguage(index)
            }

            Item { width: 1; height: 5 * root.s }

            FieldRow {
                id: rateRow
                label: "Repeat rate"
                caption: "Key repeats per second when held"
                icon: "keyboard"
                ScrubValue {
                    id: rateScrub
                    s: root.s
                    value: root.repeatRate
                    openValue: root.base.repeatRate
                    from: 10; to: 80; step: 1; unit: "Hz"
                    onEdited: v => {
                        root.repeatRate = v;
                        root.writeInputField("repeat_rate", String(v));
                    }
                }
            }

            FieldRow {
                id: delayRow
                label: "Repeat delay"
                caption: "Hold time before a key repeats"
                icon: "stopwatch"
                ScrubValue {
                    id: delayScrub
                    s: root.s
                    value: root.repeatDelay
                    openValue: root.base.repeatDelay
                    from: 150; to: 1000; step: 25; unit: "ms"
                    onEdited: v => {
                        root.repeatDelay = v;
                        root.writeInputField("repeat_delay", String(v));
                    }
                }
            }

            FieldRow {
                id: numlockRow
                label: "Numlock"
                caption: "Numlock on at startup"
                icon: "lock"
                LinkToggle {
                    s: root.s
                    on: root.numlockOn
                    onToggled: {
                        root.numlockOn = !root.numlockOn;
                        root.writeInputField("numlock_by_default", root.numlockOn ? "true" : "false");
                    }
                }
            }

            GroupLabel { text: "TrackPoint"; visible: root.hasPointing }

            Repeater {
                model: ThinkPad.tpList

                FieldRow {
                    id: tpRow
                    required property var modelData
                    label: root.tpLabel(tpRow.modelData.name)
                    visible: root.hasPointing

                    LinkToggle {
                        visible: tpRow.modelData.bool
                        s: root.s
                        on: tpRow.modelData.value === 1
                        enabled: !root.tpBusy
                        onToggled: root.setTp(tpRow.modelData.name, !on ? 1 : 0)
                    }

                    ScrubValue {
                        visible: !tpRow.modelData.bool
                        s: root.s
                        value: tpRow.modelData.value
                        from: 0; to: tpRow.modelData.max
                        step: tpRow.modelData.name === "drift_time" ? 50 : 4
                        enabled: !root.tpBusy
                        onEdited: (v) => root.setTp(tpRow.modelData.name, v)
                    }
                }
            }

            FieldRow {
                label: "Double-tap"
                icon: "mouse"
                visible: root.hasPointing && ThinkPad.doubletap >= 0
                LinkToggle {
                    s: root.s
                    on: ThinkPad.doubletap === 1
                    enabled: !root.tpBusy
                    onToggled: root.setDoubletap(!on)
                }
            }

            FieldRow {
                label: "Fn lock"
                icon: "lock"
                visible: root.hasPointing && ThinkPad.fnLock >= 0
                LinkToggle {
                    s: root.s
                    on: ThinkPad.fnLock === 1
                    enabled: !root.tpBusy
                    onToggled: root.setFnLock(!on)
                }
            }

            Text {
                width: parent.width
                visible: root.tpNotice.length > 0
                topPadding: 4 * root.s
                text: root.tpNotice
                color: root.tpNotice === "saved" ? Theme.faint : Theme.flameCore
                font.family: Theme.font
                font.pixelSize: 8.5 * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            GroupLabel { text: "Fingerprint" }

            FieldRow {
                id: fingerprintRow
                label: "Lock unlock"
                caption: root.fingerprintStatus
                icon: "lock"

                LinkToggle {
                    s: root.s
                    on: Flags.lockFingerprint
                    enabled: root.fingerprintAvailable
                    onToggled: Flags.lockFingerprint = !on
                }
            }

            GroupLabel { text: "Touchpad" }

            FieldRow {
                id: naturalRow
                label: "Natural scroll"
                caption: "Content follows the finger direction"
                icon: "mouse"
                LinkToggle {
                    s: root.s
                    on: root.naturalScroll
                    onToggled: {
                        root.naturalScroll = !root.naturalScroll;
                        root.writeInputKey("natural_scroll", root.naturalScroll ? "true" : "false");
                    }
                }
            }

            FieldRow {
                id: tapRow
                label: "Tap to click"
                caption: "A short tap is a left click"
                icon: "mouse"
                LinkToggle {
                    s: root.s
                    on: root.tapToClick
                    onToggled: {
                        root.tapToClick = !root.tapToClick;
                        root.writeInputKey("tap_to_click", root.tapToClick ? "true" : "false");
                    }
                }
            }

            FieldRow {
                id: typingRow
                label: "Disable while typing"
                caption: "Ignore the touchpad while a key is held"
                icon: "keyboard"
                LinkToggle {
                    s: root.s
                    on: root.disableWhileTyping
                    onToggled: {
                        root.disableWhileTyping = !root.disableWhileTyping;
                        root.writeInputKey("disable_while_typing", root.disableWhileTyping ? "true" : "false");
                    }
                }
            }

            FieldRow {
                id: clickfingerRow
                label: "Clickfinger"
                caption: "Two/three-finger taps map to right/middle"
                icon: "mouse"
                LinkToggle {
                    s: root.s
                    on: root.clickfinger
                    onToggled: {
                        root.clickfinger = !root.clickfinger;
                        root.writeInputKey("clickfinger_behavior", root.clickfinger ? "true" : "false");
                    }
                }
            }

            FieldRow {
                id: middleRow
                label: "Middle-button emulation"
                caption: "Three-finger tap is the middle button"
                icon: "mouse"
                LinkToggle {
                    s: root.s
                    on: root.middleButton
                    onToggled: {
                        root.middleButton = !root.middleButton;
                        root.writeInputKey("middle_button_emulation", root.middleButton ? "true" : "false");
                    }
                }
            }

            GroupLabel { text: "Cursor" }

            FieldRow {
                id: sizeRow
                label: "Size"
                caption: "Cursor size in pixels"
                icon: "cursor"
                ScrubValue {
                    id: sizeScrub
                    s: root.s
                    value: root.cursorSize
                    openValue: root.base.cursorSize
                    from: 12; to: 96; step: 4; unit: "px"
                    onEdited: v => {
                        root.cursorSize = v;
                        root.applyCursor(root.cursorTheme, v);
                    }
                }
            }

            Item { width: 1; height: 8 * root.s }

            /**
             * DisplayPicker draws its own chip and dropdown, so the wrapper only
             * adds what the registry needs: hover for the soul seam and a
             * fall-through click that toggles the picker like the chip does.
             */
            Item {
                id: themeRow
                width: parent ? parent.width : 0
                height: themePick.implicitHeight

                HoverHandler {
                    onHoveredChanged: root.reportRowHover(themeRow, hovered)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.activateRow(themeRow)
                }

                DisplayPicker {
                    id: themePick
                    s: root.s
                    label: "Theme"
                    options: root.cursorThemes.map(function (t) { return { label: t, value: t }; })
                    value: root.cursorTheme
                    open: root.themeOpen
                    onRequestToggle: root.themeOpen = !root.themeOpen
                    onPicked: (v) => {
                        root.cursorTheme = v;
                        root.themeOpen = false;
                        root.applyCursor(v, root.cursorSize);
                    }
                }
            }

            Text {
                width: parent.width
                topPadding: 8 * root.s
                visible: root.note.length > 0
                text: root.note
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                lineHeight: 1.25
            }

            Item { width: 1; height: 10 * root.s }
        }
    }
}
