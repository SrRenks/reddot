//@ pragma UseQApplication

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"
import "lib/surfaces.js" as SurfaceCatalog

/**
 * Washi pill top shell. Each monitor carries two layer-shell windows:
 *
 *  - `reserve` is a zero-content strip that only claims an exclusive zone the
 *    height of the rest pill, so tiled windows always sit below the pill even
 *    while it is expanded or a surface is open.
 *  - `overlay` is a full-screen transparent Overlay layer hosting the single
 *    morphing pill anchored at top-centre. The pill never moves windows and is
 *    never re-parented; it just grows in place, so every surface grows out of
 *    the rest pill instead of popping up as a separate panel.
 *
 * Input is routed by the window mask. While the pill is collapsed the mask is
 * the pill rect only, so the rest of the screen clicks through to windows.
 * While the pill is expanded (hovered/pinned) or a surface is open the mask is
 * cleared so the whole layer catches clicks. A backdrop press dismisses, and
 * keyboard focus is taken on demand so Escape closes the open surface.
 */
ShellRoot {
    id: root

    property string openMon: ""
    property string openSurface: ""
    property string peekMon: ""
    /** Monitor whose pill is currently pulled down from the auto-hide strip. */
    property string revealMon: ""
    /** Keybind-opened monitor waiting for the layer to map before the focus warp. */
    property string pendingWarpMon: ""
    /** Suppress the hover-open state after a keyboard toggle closes the pill. */
    property string forceHiddenMon: ""
    /** Keyboard close holds the pill during the surface morph, then hides it once. */
    property string closingMon: ""
    /** Keep the overlay full-screen until the retract animation has finished. */
    property string layerHoldMon: ""

    function refresh() {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    Component.onCompleted: {
        refresh();
        Devices.restore();
        void GameMode.active;
        void Sound.eq;
    }

    /**
     * The first cursor warp can happen before the layer surface maps, so Hyprland
     * never sees a pointer enter and keyboard focus stays with the window below.
     * A delayed second warp generates the enter after mapping, without a timer
     * loop or any resident process.
     */
    Timer {
        id: warpRetry
        interval: 240
        repeat: false
        onTriggered: {
            if (root.pendingWarpMon.length > 0)
                root.warpToPill(root.pendingWarpMon, 2);
        }
    }

    Timer {
        id: keyboardHide
        interval: Motion.closeRest
        repeat: false
        onTriggered: {
            if (root.closingMon.length > 0)
                root.forceHiddenMon = root.closingMon;
            root.closingMon = "";
            layerRelease.restart();
        }
    }

    Timer {
        id: layerRelease
        interval: Motion.closeTail
        repeat: false
        onTriggered: {
            if (root.closingMon.length === 0 && root.layerHoldMon.length > 0)
                root.layerHoldMon = "";
        }
    }

    /**
     * After an update relaunches the shell, raise a one-shot toast naming what
     * landed, so the apply ends in a confirmation instead of a silent restart. The
     * updater drops the marker just before it restarts; the short delay lets the
     * notification server own the bus before we post to it, and the marker is
     * removed as it is read so the toast only ever fires once.
     */
    Timer {
        interval: 2500
        running: true
        onTriggered: updatedToast.running = true
    }
    Process {
        id: updatedToast
        command: ["sh", "-c",
            "m=\"${XDG_STATE_HOME:-$HOME/.local/state}/reddot/updated\"; [ -f \"$m\" ] || exit 0; "
            + "b=$(cat \"$m\"); rm -f \"$m\"; "
            + "gdbus call --session --dest org.freedesktop.Notifications "
            + "--object-path /org/freedesktop/Notifications "
            + "--method org.freedesktop.Notifications.Notify "
            + "reddot 0 '' 'reddot updated' \"$b\" '[]' '{}' 5000 >/dev/null 2>&1"]
    }

    PanelWindow {
        id: inhibitWin
        visible: Flags.keepAwake
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "pill-inhibit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; left: true }
        IdleInhibitor { window: inhibitWin; enabled: Flags.keepAwake }
    }

    /**
     * The Wayland IdleInhibitor above only pauses the compositor's own idle
     * (DPMS); hypridle runs its own timer and never sees it, so the lock still
     * fired with keep-awake on. A logind idle inhibitor is the wire hypridle
     * does respect, so hold one for as long as the flag is set.
     */
    Process {
        running: Flags.keepAwake
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=reddot",
                  "--why=keep awake", "--mode=block", "sleep", "infinity"]
    }

    /**
     * Only these raw events can change what the pill renders (per-monitor
     * active workspace, minimized toplevels, monitor hotplug). Everything
     * else (window drags, resizes, title spam) must not trigger the triple
     * model refresh, which costs three Hyprland IPC round-trips.
     */
    readonly property var refreshEvents: ({
        workspace: true, workspacev2: true,
        createworkspace: true, createworkspacev2: true,
        destroyworkspace: true, destroyworkspacev2: true,
        moveworkspace: true, moveworkspacev2: true,
        renameworkspace: true, activespecial: true,
        focusedmon: true, focusedmonv2: true,
        openwindow: true, closewindow: true,
        movewindow: true, movewindowv2: true,
        fullscreen: true,
        monitoradded: true, monitoraddedv2: true, monitorremoved: true
    })

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.refreshEvents[event.name])
                root.refresh();
        }
    }

    /**
     * An empty monitor argument resolves to the focused monitor here, so the
     * keybind scripts skip their hyprctl+jq round trip and a surface open costs
     * one IPC call instead of three process spawns.
     */
    /** Resolve an empty keybind monitor even before Hyprland reports focusedMonitor. */
    function focusedMonitorName() {
        if (Hyprland.focusedMonitor)
            return Hyprland.focusedMonitor.name;
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++)
            if (mons[i] && mons[i].focused)
                return mons[i].name;
        var ws = Hyprland.focusedWorkspace;
        if (ws) {
            for (var j = 0; j < mons.length; j++)
                if (mons[j] && mons[j].activeWorkspace && mons[j].activeWorkspace.id === ws.id)
                    return mons[j].name;
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }

    function toggleSurface(mon, surface) {
        if (!SurfaceCatalog.isValid(surface))
            return;
        if (!mon || mon.length === 0)
            mon = root.focusedMonitorName();
        if (root.openMon === mon && root.openSurface === surface) {
            root.closeWithAnimation(mon);
            return;
        }
        root.resetCloseState();
        root.peekMon = "";
        root.openMon = mon;
        root.openSurface = surface;
        Flags.lastSurface = surface;
    }

    /** Home is the expanded pill with no surface. It is a real history state. */
    function openHome(mon) {
        if (!mon || mon.length === 0)
            mon = root.openMon || root.focusedMonitorName();
        root.resetCloseState();
        root.layerHoldMon = mon;
        Flags.lastSurface = "";
        root.openMon = "";
        root.openSurface = "";
        root.peekMon = mon;
        root.pendingWarpMon = mon;
        layerRelease.restart();
        Qt.callLater(() => root.warpToPill(mon));
        warpRetry.restart();
    }

    /** Open the remembered surface, or close the pill when one is already open. */
    function togglePill(mon) {
        if (!mon || mon.length === 0)
            mon = root.focusedMonitorName();
        if (root.openSurface.length > 0) {
            root.closeWithAnimation(mon);
            return;
        }
        if (root.peekMon === mon) {
            root.peekMon = "";
            root.closeWithAnimation(mon);
            return;
        }
        root.resetCloseState();
        if (SurfaceCatalog.isValid(Flags.lastSurface)) {
            root.peekMon = "";
            root.openMon = mon;
            root.openSurface = Flags.lastSurface;
            root.pendingWarpMon = mon;
            Qt.callLater(() => root.warpToPill(mon));
            warpRetry.restart();
        } else {
            root.openHome(mon);
        }
    }

    /**
     * The layer surface takes keyboard focus on open, but Hyprland grants it to a
     * layer only when the pointer is over that layer on this setup. The keyboard
     * toggle therefore parks the pointer on the pill's top-centre, which also
     * preserves hover and keeps Escape/arrow keys working without a mouse trip.
     */
    function warpToPill(mon, nudge) {
        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            if (!s || s.name !== mon)
                continue;
            var x = Math.round(s.x + s.width / 2) + (nudge || 0);
            var y = Math.round(s.y + Math.max(8, 24 * (s.height / 1080) * Flags.uiScale));
            Hyprland.dispatch("hl.dsp.cursor.move({ x = " + x + ", y = " + y + " })");
            return;
        }
        // Fallback for a compositor that has not populated Quickshell.screens yet.
        var mons = Hyprland.monitors.values;
        for (var j = 0; j < mons.length; j++) {
            var m = mons[j];
            if (!m || m.name !== mon)
                continue;
            var fx = Math.round(m.x + m.width / 2) + (nudge || 0);
            var fy = Math.round(m.y + Math.max(8, 24 * (m.height / 1080) * Flags.uiScale));
            Hyprland.dispatch("hl.dsp.cursor.move({ x = " + fx + ", y = " + fy + " })");
            return;
        }
    }

    function close() {
        root.openMon = "";
        root.openSurface = "";
        root.pendingWarpMon = "";
    }

    /**
     * Return the per-monitor chrome to its neutral state. Every open path calls
     * this instead of stopping the two close timers ad hoc.
     */
    function resetCloseState() {
        keyboardHide.stop();
        layerRelease.stop();
        root.closingMon = "";
        root.layerHoldMon = "";
        root.forceHiddenMon = "";
    }

    /**
     * The single close timeline. `resetHistory` is false for the toggle and for
     * backdrop closes, both of which remember the panel; only the explicit home
     * action clears it. Visual state is cleared by the overlay's closingMon
     * connection.
     */
    function closePill(mon, resetHistory) {
        if (!mon || mon.length === 0)
            mon = root.focusedMonitorName();
        layerRelease.stop();
        root.closingMon = mon;
        root.layerHoldMon = mon;
        if (resetHistory)
            Flags.lastSurface = "";
        root.close();
        keyboardHide.restart();
    }

    function closeWithAnimation(mon) { root.closePill(mon, false); }

    /** A back click lands on the pill home, not on a stale panel. */
    function back() {
        root.openHome(root.openMon || root.focusedMonitorName());
    }

    function peek(mon) {
        root.peekMon = root.peekMon === mon ? "" : mon;
    }

    IpcHandler {
        target: "pill"
        function mixer(mon: string): void { root.toggleSurface(mon, "mixer"); }
        function sound(mon: string): void { root.toggleSurface(mon, "sound"); }
        function eq(): void { Sound.setEq(!Sound.eq); }
        function eqMode(name: string): void { Sound.pick(name); }
        function micFilter(): void { Sound.setDenoise(!Sound.denoise); }
        function calendar(mon: string): void { root.toggleSurface(mon, "calendar"); }
        function launcher(mon: string): void { root.toggleSurface(mon, "launcher"); }
        function power(mon: string): void { root.toggleSurface(mon, "power"); }
        function link(mon: string): void { root.toggleSurface(mon, "link"); }
        function battery(mon: string): void { root.toggleSurface(mon, "battery"); }
        function tlp(mon: string): void { root.toggleSurface(mon, "tlp"); }
        function thinkpad(mon: string): void { root.toggleSurface(mon, "thinkpad"); }
        function settings(mon: string): void { root.toggleSurface(mon, "settings"); }
        function presets(mon: string): void { root.toggleSurface(mon, "presets"); }
        function startup(mon: string): void { root.toggleSurface(mon, "startup"); }
        function toggle(mon: string): void { root.togglePill(mon); }
        function blur(): void {
            const on = !WindowBlur.enabled;
            WindowBlur.setEnabled(on);
            KeyNotice.show("sparkles", "Window blur", on ? "On" : "Off");
        }
        function notice(icon: string, label: string, value: string): void {
            KeyNotice.show(icon, label, value);
        }
        function panelblur(): void { UiBlur.setEnabled(!UiBlur.enabled); }
        function keybinds(mon: string): void { root.toggleSurface(mon, "keybinds"); }
        function recorder(mon: string): void { root.toggleSurface(mon, "recorder"); }

        /**
         * Quick-record keybind (SUPER+D): one button cycles the whole flow with no
         * surface. Recording → stop. Counting down → cancel. A chooser already up
         * on this monitor → dismiss. Otherwise open the standalone source chooser on
         * the focused monitor `mon`, so only that pill renders it.
         */
        function quickRecord(mon: string): void {
            if (ScreenRec.recording) {
                ScreenRec.stop();
            } else if (ScreenRec.counting) {
                ScreenRec.cancel();
            } else if (ScreenRec.quickChoosing) {
                ScreenRec.quickChoosing = false;
                ScreenRec.quickScreenChoosing = false;
            } else {
                ScreenRec.quickMon = mon;
                ScreenRec.quickScreenChoosing = false;
                ScreenRec.quickChoosing = true;
            }
        }
        function gameMode(mon: string): void { Flags.gameMode = !Flags.gameMode; }
        function sysmon(mon: string): void { root.toggleSurface(mon, "sysmon"); }
        function clipboard(mon: string): void { root.toggleSurface(mon, "clipboard"); }
        function wallpaper(mon: string): void { root.toggleSurface(mon, "wallpaper"); }
        function media(mon: string): void {
            if (Players.list.length > 0)
                root.toggleSurface(mon, "media");
        }
        function peek(mon: string): void { root.peek(mon); }
        function hide(): void { root.close(); }

        /** Opens any surface by name, settings sub-pages included; dev and scripting door. */
        function page(mon: string, name: string): void { root.toggleSurface(mon, name); }
        function open(mon: string, name: string): void { root.toggleSurface(mon, name); }
        function close(): void { root.close(); }

        /**
         * The two halves of the SUPER+M minimize toggle, driven by the
         * minimize-toggle script which has already read the focused window. A
         * desktop window drops into the minimized stash; a window already stashed
         * comes back to the workspace it is handed, so the same key hides and
         * restores. Both target the window by address so they act on the one the
         * user pressed on, not whatever the compositor calls active afterwards.
         */
        function minimizeWindow(addr: string): void {
            Hyprland.dispatch('hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = "address:' + addr + '" })');
        }
        function restoreWindow(arg: string): void {
            var p = arg.split("|");
            if (p.length < 2 || p[0].length === 0)
                return;
            Hyprland.dispatch('hl.dsp.window.move({ workspace = ' + p[1] + ', window = "address:' + p[0] + '" })');
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: reserve
            required property var modelData
            readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
            readonly property real topGap: 8 * Flags.topGap * s
            readonly property real restHeight: 38 * s

            /** Trimming the reserved band below the pill's bottom lets windows climb, so App gap sets the pill-to-window air without touching the desktop gaps_out. */
            readonly property real reservedH: Math.max(0, restHeight + topGap - 12 * (1 - Flags.appGap) * s)

            readonly property real gameBarH: 34 * s

            /**
             * Auto mode keeps the band at zero even while the pill is revealed:
             * the strip has to stay reachable and windows must not jump when it
             * slides in. `pillReserve` is the always-on/off choice.
             */
            readonly property bool reserveBand: Flags.pillReserve && Flags.pillMode !== "auto"
            readonly property real bandH: Flags.gameMode ? gameBarH : (reserveBand ? reservedH : 0)

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: bandH
            aboveWindows: true

            anchors { top: true; left: true; right: true }
            implicitHeight: bandH

            mask: emptyReserve
            Region { id: emptyReserve }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            required property var modelData
            readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
            readonly property real topGap: 8 * Flags.topGap * s
            readonly property string surface: root.openMon === modelData.name ? root.openSurface : ""
            readonly property bool surfaceOpen: surface.length > 0
            readonly property bool modal: pill.authPending ? false : (surfaceOpen || pill.held || pill.quickChoosing)
            readonly property bool keyboardOpen: surfaceOpen || pill.held || pill.hoverLatch || pill.quickChoosing
            property bool grabReady: false
            /**
             * True while this monitor's active workspace reports a fullscreen
             * client. The pill retracts off the top edge and the layer is
             * click-through so fullscreen content owns the screen, until a
             * surface or a peek summons it back over the content.
             */
            readonly property bool monFullscreen: {
                var mons = Hyprland.monitors.values;
                for (var i = 0; i < mons.length; i++) {
                    if (mons[i].name === modelData.name) {
                        var ws = mons[i].activeWorkspace;
                        var o = ws ? ws.lastIpcObject : null;
                        return o ? !!o.hasfullscreen : false;
                    }
                }
                return false;
            }
            readonly property bool summoned: modal || root.peekMon === modelData.name
            readonly property bool pillHidden: monFullscreen && !summoned

            /** Dash-to-dock style: retracted to a 10 px strip until the pointer touches it. */
            readonly property bool autoMode: Flags.pillMode === "auto"
            readonly property bool autoHidden: autoMode && !monFullscreen && !Flags.gameMode
                && !modal && !pill.pinned && !pill.osdActive && !pill.toastActive
                && root.peekMon !== modelData.name && root.revealMon !== modelData.name
                && root.closingMon !== modelData.name
            readonly property bool hiddenNow: pillHidden || autoHidden

            onMonFullscreenChanged: if (monFullscreen) {
                if (root.openMon === modelData.name) root.close();
                if (root.peekMon === modelData.name) root.peekMon = "";
                if (root.revealMon === modelData.name) root.revealMon = "";
                pill.pinned = false;
            }

            /** Rest, hover, toasts and OSDs fit a top band; the layer only spans the screen while a surface or tall morph needs it. */
            readonly property real bandH: Math.ceil(topGap + 200 * s + slot.pad)
            readonly property bool tall: modal || topGap + Math.max(pill.height, pill.targetH) + slot.pad > bandH

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (keyboardOpen && !pill.authPending)
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None
            WlrLayershell.namespace: "pill"

            /** Close an explicitly held pill without leaving a pinned/revealed state behind. */
            function dismissPill() { root.closePill(modelData.name, false); }

            /**
             * HyprlandFocusGrab retains keyboard focus for the listed surface
             * even when the mouse leaves it. This is what makes Escape and arrow
             * keys reliable after a keyboard open; the compositor pointer-enter
             * heuristic otherwise decides when the layer may take focus.
             */
            HyprlandFocusGrab {
                id: surfaceGrab
                windows: [overlay]
                active: overlay.keyboardOpen && !pill.authPending
                onActiveChanged: {
                    if (active) {
                        overlay.grabReady = false;
                        grabArm.restart();
                    } else {
                        grabArm.stop();
                    }
                }
                /** Ignore the grab's initial clear; outside clicks after it settles close. */
                onCleared: if (overlay.surfaceOpen && overlay.grabReady
                               && root.forceHiddenMon !== modelData.name
                               && root.closingMon !== modelData.name)
                               overlay.dismissPill()
            }

            /** QtObject children cannot own a Timer; this one belongs to the PanelWindow. */
            Timer {
                id: grabArm
                interval: 280
                repeat: false
                onTriggered: overlay.grabReady = true
            }

            anchors { top: true; left: true; right: true }
            implicitHeight: (tall || root.layerHoldMon === modelData.name)
                ? modelData.height : bandH

            mask: modal ? fullRegion
                : (pillHidden ? hiddenRegion
                : (autoMode ? (autoHidden ? revealRegion : revealUnion) : pillRegion))
            Region { id: hiddenRegion }
            Region {
                id: pillRegion
                readonly property real baseW: Math.max(pill.width, pill.targetW)
                x: slot.x + pill.x + (pill.width - baseW) / 2
                y: slot.y + pill.y
                width: baseW + pill.inputPadRight
                height: Math.max(pill.height, pill.targetH)
            }

            /**
             * The only live area while the pill is retracted: a thin top-centre
             * strip, matching Ukishima's auto-hide. It doubles as the reveal
             * input mask, so nothing invisible below it blocks clicks.
             */
            Region {
                id: revealRegion
                readonly property real revealW: Math.max(420 * overlay.s, pill.width)
                x: Math.max(0, overlay.width / 2 - revealW / 2)
                y: 0
                width: revealW
                /* A 10 px target demanded too much precision when the pointer
                   swept the edge; 18 px makes the retracted strip forgiving. */
                height: 18 * overlay.s
            }

            /** Strip + pill while revealed, so the pointer can travel from one to the other without losing hover. */
            Region {
                id: revealUnion
                x: Math.min(revealRegion.x, pillRegion.x)
                y: Math.min(revealRegion.y, pillRegion.y)
                width: Math.max(revealRegion.x + revealRegion.width,
                               pillRegion.x + pillRegion.width) - x
                height: Math.max(revealRegion.y + revealRegion.height,
                                pillRegion.y + pillRegion.height) - y
            }

            HoverHandler {
                id: autoHover
                enabled: overlay.autoMode && !overlay.monFullscreen
                onHoveredChanged: {
                    if (!enabled)
                        return;
                    if (hovered) {
                        forceRelease.stop();
                        if (root.forceHiddenMon !== overlay.modelData.name) {
                            root.revealMon = overlay.modelData.name;
                            revealHide.stop();
                        }
                    } else {
                        if (root.revealMon === overlay.modelData.name)
                            revealHide.restart();
                        if (root.forceHiddenMon === overlay.modelData.name)
                            forceRelease.restart();
                    }
                }
            }

            /** Do not let the morph's temporary leave/enter cycle re-show a keyboard-closed pill. */
            Timer {
                id: forceRelease
                interval: Motion.forceRelease
                repeat: false
                onTriggered: {
                    if (root.forceHiddenMon === overlay.modelData.name && !autoHover.hovered)
                        root.forceHiddenMon = "";
                }
            }

            Timer {
                id: revealHide
                interval: Motion.revealExit
                onTriggered: if (root.revealMon === overlay.modelData.name)
                    root.revealMon = "";
            }
            Region {
                id: fullRegion
                width: overlay.width
                height: overlay.height
            }

            MouseArea {
                anchors.fill: parent
                enabled: overlay.modal
                acceptedButtons: Qt.AllButtons
                /**
                 * Close on the completed click, not on the press. Closing on press
                 * released the layer before the physical button was released; the
                 * release then leaked to the application below and produced the
                 * click-outside stutter. Every outside close now uses the same
                 * dismissPill timeline as Escape.
                 */
                onWheel: (event) => {
                    if (SurfaceChrome.scrollMax <= 0 || SurfaceChrome.scrollTarget === null)
                        return;
                    var step = Math.max(20 * pill.s,
                        Math.min(140 * pill.s, SurfaceChrome.scrollViewH * 0.16));
                    SurfaceChrome.scrollBy(event.angleDelta.y > 0 ? -step : step);
                    event.accepted = true;
                }
                onClicked: (mouse) => {
                    if (pill.quickChoosing) {
                        ScreenRec.quickChoosing = false;
                        ScreenRec.quickScreenChoosing = false;
                        return;
                    }
                    if (overlay.surfaceOpen) {
                        var inside = mouse.x >= pillRegion.x && mouse.x <= pillRegion.x + pillRegion.width
                            && mouse.y >= pillRegion.y && mouse.y <= pillRegion.y + pillRegion.height;
                        if (!inside) {
                            overlay.dismissPill();
                        } else if (mouse.y <= pillRegion.y + 40 * pill.s) {
                            pill.surfaceBack();
                        }
                    } else if (pill.held || pill.hoverLatch
                               || root.peekMon === modelData.name
                               || root.revealMon === modelData.name) {
                        overlay.dismissPill();
                    }
                }
            }

            FocusScope {
                id: focusScope
                anchors.fill: parent
                focus: overlay.keyboardOpen

                HoverHandler {
                    onHoveredChanged: pill.hovered = hovered
                }
                Keys.onEscapePressed: {
                    if (pill.quickChoosing) {
                        ScreenRec.quickChoosing = false;
                        ScreenRec.quickScreenChoosing = false;
                    } else if (!pill.keybindsBack()) {
                        if (overlay.surfaceOpen && SurfaceCatalog.parent(overlay.surface).length > 0)
                            pill.surfaceBack(false);
                        else if (overlay.surfaceOpen)
                            pill.requestBack();
                        else if (pill.held || pill.hoverLatch || root.peekMon === modelData.name)
                            overlay.dismissPill();
                        else
                            overlay.dismissPill();
                    }
                }
                Keys.onUpPressed: (e) => {
                    if (pill.keybindsOpen && !pill.keybindsListening) { pill.keybindsMove(-1); e.accepted = true; return; }
                    e.accepted = pill.mixerStep(1) || pill.recorderStep(5) || pill.settingsMove(-1);
                }
                Keys.onDownPressed: (e) => {
                    if (pill.keybindsOpen && !pill.keybindsListening) { pill.keybindsMove(1); e.accepted = true; return; }
                    e.accepted = pill.mixerStep(-1) || pill.recorderStep(-5) || pill.settingsMove(1);
                }
                Keys.onLeftPressed: (e) => {
                    if (pill.mixerOpen) { pill.mixerFocusMove(-1); e.accepted = true; }
                    else if (pill.wallpaperOpen) { pill.wallpaperMove(-1); e.accepted = true; }
                    else if (pill.powerOpen) { pill.powerMove(-1); e.accepted = true; }
                    else if (pill.recorderOpen) { e.accepted = pill.recorderStep(-5); }
                    else if (pill.settingsLike) { pill.settingsAdjust(-1); e.accepted = true; }
                }
                Keys.onRightPressed: (e) => {
                    if (pill.mixerOpen) { pill.mixerFocusMove(1); e.accepted = true; }
                    else if (pill.wallpaperOpen) { pill.wallpaperMove(1); e.accepted = true; }
                    else if (pill.powerOpen) { pill.powerMove(1); e.accepted = true; }
                    else if (pill.recorderOpen) { e.accepted = pill.recorderStep(5); }
                    else if (pill.settingsLike) { pill.settingsAdjust(1); e.accepted = true; }
                }

                /**
                 * Return/Enter/Space: the wallpaper strip applies its focused
                 * thumb on every press; the power surface fires a safe tile on
                 * the first press and, for a destructive tile, holds the heat
                 * fill across autorepeat presses (drained on release). Autorepeat
                 * is swallowed for everything else so a held key never re-fires.
                 */
                Keys.onPressed: (e) => {
                    // The focus grab can keep the compositor from seeing the
                    // global toggle while the pill is modal. Handle it here too.
                    if (e.key === Qt.Key_Space
                        && (e.modifiers & Qt.MetaModifier)
                        && (e.modifiers & Qt.ShiftModifier)) {
                        root.togglePill(overlay.modelData.name);
                        e.accepted = true;
                        return;
                    }
                    if (pill.wallpaperOpen && !pill.wallpaperSearching
                        && e.text.length === 1 && e.text > " ") {
                        pill.wallpaperType(e.text);
                        e.accepted = true;
                        return;
                    }
                    if (e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter && e.key !== Qt.Key_Space)
                        return;
                    if (pill.wallpaperOpen) {
                        if (!e.isAutoRepeat) pill.wallpaperActivate();
                        e.accepted = true;
                    } else if (pill.powerOpen) {
                        if (!e.isAutoRepeat) pill.powerPress();
                        e.accepted = true;
                    } else if (pill.settingsLike) {
                        if (!e.isAutoRepeat) pill.settingsActivate();
                        e.accepted = true;
                    } else if (pill.keybindsOpen && !pill.keybindsListening) {
                        if (!e.isAutoRepeat) pill.keybindsActivate();
                        e.accepted = true;
                    }
                }
                Keys.onReleased: (e) => {
                    if (e.isAutoRepeat)
                        return;
                    if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                        && pill.powerOpen) {
                        pill.powerRelease();
                        e.accepted = true;
                    }
                }

                /**
                 * Slot the pill rests in. While a toast is dragged the slot
                 * becomes a soft-edged mask: the pill slides against an invisible
                 * wall and dissolves at the edge it leaves through instead of
                 * getting cut. The fade lives in the padding outside the pill's
                 * resting footprint, so an unmoved pill is never touched by it.
                 */
                Item {
                    id: slot
                    readonly property real pad: 56 * overlay.s
                    readonly property bool swiping: pill.swipeX !== 0 || pill.swipeY !== 0
                    anchors.top: parent.top
                    anchors.topMargin: (pill.mode === "game" ? 0 : overlay.topGap) - pad
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: pill.width + 2 * pad
                    height: pill.height + 2 * pad

                    Behavior on anchors.topMargin {
                        NumberAnimation {
                            duration: Motion.morph
                            easing.type: Motion.easeMorph
                            easing.bezierCurve: Motion.morphCurve
                        }
                    }

                    layer.enabled: swiping
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: wall
                    }

                    Item {
                        id: wall
                        width: slot.width
                        height: slot.height
                        visible: false
                        layer.enabled: true

                        Rectangle {
                            id: wallRect
                            anchors.fill: parent
                            readonly property bool sideways: pill.swipeX !== 0
                            readonly property bool leftward: pill.swipeX < 0
                            readonly property real edge: slot.pad / (sideways ? slot.width : slot.height)
                            gradient: Gradient {
                                orientation: wallRect.sideways ? Gradient.Horizontal : Gradient.Vertical
                                GradientStop { position: 0.0; color: wallRect.sideways && !wallRect.leftward ? "white" : "transparent" }
                                GradientStop { position: wallRect.edge; color: "white" }
                                GradientStop { position: 1 - wallRect.edge; color: "white" }
                                GradientStop { position: 1.0; color: wallRect.sideways && wallRect.leftward ? "white" : "transparent" }
                            }
                        }
                    }

                Pill {
                    id: pill
                    anchors.top: parent.top
                    anchors.topMargin: slot.pad
                    anchors.horizontalCenter: parent.horizontalCenter
                    s: overlay.s
                    screenName: overlay.modelData.name
                    barWindow: overlay
                    surface: overlay.surface
                    forcePinned: root.peekMon === overlay.modelData.name

                    opacity: overlay.hiddenNow ? 0 : pill.swipeFade
                    Behavior on opacity {
                        enabled: !slot.swiping
                        NumberAnimation {
                            duration: Motion.morph
                            easing.type: Motion.easeMorph
                            easing.bezierCurve: Motion.morphCurve
                        }
                    }
                    transform: [
                        Translate { x: pill.swipeX; y: pill.swipeY },
                        Translate {
                            y: overlay.hiddenNow ? -(pill.height + overlay.topGap) : 0
                            Behavior on y {
                                NumberAnimation {
                                    duration: Motion.morph
                                    easing.type: Motion.easeMorph
                                    easing.bezierCurve: Motion.morphCurve
                                }
                            }
                        }
                    ]

                    onRequestSurface: (name) => root.toggleSurface(overlay.modelData.name, name)
                    onRequestClose: root.closeWithAnimation(overlay.modelData.name)
                    onRequestBack: root.back()
                }
                }
            }

            /**
             * One-glyph back control in the pill's left gutter. The gutter exists
             * only while a surface is open; the panel content keeps its original
             * width because the target width grows by the same amount.
             */
            Rectangle {
                id: surfaceBackChip
                visible: overlay.surfaceOpen
                z: 20
                x: pillRegion.x + 1 * overlay.s
                y: pillRegion.y + 2 * overlay.s
                width: 22 * overlay.s
                height: 30 * overlay.s
                radius: 5 * overlay.s
                opacity: backMouse.containsMouse ? 1 : 0.9
                color: backMouse.containsMouse
                    ? Qt.rgba(Theme.vermLit.r, Theme.vermLit.g, Theme.vermLit.b, 0.16)
                    : Qt.rgba(Theme.tileBg.r, Theme.tileBg.g, Theme.tileBg.b, 0.9)
                border.width: 1
                border.color: backMouse.containsMouse
                    ? Qt.rgba(Theme.vermLit.r, Theme.vermLit.g, Theme.vermLit.b, 0.72)
                    : Qt.rgba(Theme.vermLit.r, Theme.vermLit.g, Theme.vermLit.b, 0.35)
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                GlyphIcon {
                    anchors.centerIn: parent
                    width: 17 * overlay.s
                    height: 17 * overlay.s
                    name: "chevron-left"
                    color: Theme.vermLit
                    stroke: 2.5
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.surfaceBack()
                }

                Tooltip {
                    s: overlay.s
                    title: "Back"
                    desc: "Esc"
                    show: backMouse.containsMouse
                    placement: "below"
                }
            }

            Connections {
                target: root

                /**
                 * Clear the interactive state as soon as a close starts, not only
                 * when the retract finishes. This is the difference between a mouse
                 * close (pill was pinned) and a keyboard close; both must target the
                 * same rest state before the hide animation begins.
                 */
                function onClosingMonChanged() {
                    if (root.closingMon === modelData.name) {
                        pill.suppressHover = true;
                        pill.hoverLatch = false;
                        pill.pinned = false;
                        root.peekMon = "";
                        root.revealMon = "";
                    } else if (root.closingMon.length === 0) {
                        pill.suppressHover = false;
                    }
                }

                function onForceHiddenMonChanged() {
                    if (root.forceHiddenMon === modelData.name) {
                        pill.suppressHover = true;
                        pill.hoverLatch = false;
                        pill.pinned = false;
                        root.peekMon = "";
                        root.revealMon = "";
                    } else if (root.forceHiddenMon.length === 0) {
                        pill.suppressHover = false;
                    }
                }
            }

            onKeyboardOpenChanged: {
                if (keyboardOpen) {
                    focusArmTimer.restart();
                    focusPulse.restart();
                } else {
                    focusArmTimer.stop();
                    focusPulse.stop();
                }
            }

            Timer {
                id: focusArmTimer
                interval: 80
                repeat: false
                onTriggered: {
                    if (!overlay.surfaceOpen)
                        return;
                    focusScope.forceActiveFocus();
                }
            }

            /** Second focus pulse after the morph settles; the first can land before the layer is active. */
            Timer {
                id: focusPulse
                interval: 300
                repeat: false
                onTriggered: {
                    if (!overlay.surfaceOpen)
                        return;
                    focusScope.forceActiveFocus();
                    if (root.pendingWarpMon === modelData.name) {
                        root.warpToPill(modelData.name, 1);
                        root.pendingWarpMon = "";
                    }
                }
            }

            Connections {
                target: pill
                function onQuickChoosingChanged() {
                    if (pill.quickChoosing)
                        focusScope.forceActiveFocus();
                }
                function onWallpaperSearchingChanged() {
                    if (!pill.wallpaperSearching && overlay.surfaceOpen)
                        focusScope.forceActiveFocus();
                }
                function onKeybindsListeningChanged() {
                    if (!pill.keybindsListening && overlay.surfaceOpen)
                        focusScope.forceActiveFocus();
                }
            }
        }
    }
}
