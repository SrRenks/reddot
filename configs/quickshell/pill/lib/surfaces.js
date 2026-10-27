.pragma library

/**
 * One catalog for the pill's morphing surfaces. This is metadata only: the QML
 * Loaders stay explicit, but back routing, inline-back visibility, settings-family
 * classification and the remembered-surface check no longer maintain separate
 * name lists.
 *
 * parent:      where the visible back control goes; empty = close at the root
 * settingsLike: settings index and its sub-pages
 * cold:        unload after the pill's idle tail (the preloaded trio stays hot)
 */
var definitions = {
    mixer:      { parent: "",          settingsLike: false, cold: false , loader: "ldMixer" },
    sound:      { parent: "",          settingsLike: false, cold: true  , loader: "ldSound" },
    calendar:   { parent: "",          settingsLike: false, cold: true  , loader: "ldCalendar" },
    launcher:   { parent: "",          settingsLike: false, cold: true  , loader: "ldLauncher" },
    clipboard:  { parent: "",          settingsLike: false, cold: true  , loader: "ldClip" },
    wallpaper:  { parent: "",          settingsLike: false, cold: true  , loader: "ldWall" },
    power:      { parent: "",          settingsLike: false, cold: true  , loader: "ldPower" },
    media:      { parent: "",          settingsLike: false, cold: false , loader: "ldMedia" },
    link:       { parent: "",          settingsLike: false, cold: false , loader: "ldLink" },
    wifi:       { parent: "",          settingsLike: false, cold: true  , loader: "ldWifi" },
    bt:         { parent: "",          settingsLike: false, cold: true  , loader: "ldBt" },
    battery:    { parent: "",          settingsLike: false, cold: true  , loader: "ldBattery" },
    tlp:        { parent: "",          settingsLike: false, cold: true  , loader: "ldTlp" },
    thinkpad:   { parent: "",          settingsLike: false, cold: true  , loader: "ldThinkpad" },
    settings:   { parent: "",          settingsLike: true,  inlineBack: false, cold: true  , loader: "ldSettings" },
    keybinds:   { parent: "settings",  settingsLike: false,  cold: true  , loader: "ldKeybinds" },
    workspaces: { parent: "settings",  settingsLike: false,  cold: true  , loader: "ldWorkspaces" },
    startup:    { parent: "settings",  settingsLike: true,  inlineBack: true,  cold: true  , loader: "ldStartup" },
    stash:      { parent: "workspaces", settingsLike: false, cold: true  , loader: "ldStash" },
    spaceapps:  { parent: "workspaces", settingsLike: false, cold: true  , loader: "ldSpaceapps" },
    recorder:   { parent: "",          settingsLike: false, cold: true  , loader: "ldRecorder" },
    sysmon:     { parent: "",          settingsLike: false, cold: true  , loader: "ldSysmon" },
    appearance: { parent: "settings",  settingsLike: true,  inlineBack: true,  cold: true  , loader: "ldAppearance" },
    bar:        { parent: "settings",  settingsLike: true,  inlineBack: true,  cold: true  , loader: "ldBar" },
    updates:    { parent: "settings",  settingsLike: true,  inlineBack: true,  cold: true  , loader: "ldUpdates" },
    display:    { parent: "settings",  settingsLike: true,  inlineBack: true,  cold: true  , loader: "ldDisplay" },
    input:      { parent: "settings",  settingsLike: true,  inlineBack: true,  cold: true  , loader: "ldInput" },
    look:       { parent: "settings",  settingsLike: true,  inlineBack: true,  cold: true  , loader: "ldLook" },
    presets:    { parent: "settings",  settingsLike: true,  inlineBack: true,  cold: true  , loader: "ldPresets" },
    idlelock:   { parent: "settings",  settingsLike: true,  inlineBack: true,  cold: true  , loader: "ldIdlelock" },
    animation:  { parent: "settings",  settingsLike: true,  inlineBack: true,  cold: true  , loader: "ldAnimation" },
    fontpicker: { parent: "appearance", settingsLike: true,  cold: true  , loader: "ldFontpicker" }
};

function get(id) {
    return definitions[id] || null;
}

function isValid(id) {
    return Object.prototype.hasOwnProperty.call(definitions, id);
}

function parent(id) {
    var entry = get(id);
    return entry ? entry.parent : "";
}

function settingsLike(id) {
    var entry = get(id);
    return entry ? entry.settingsLike : false;
}

function cold(id) {
    var entry = get(id);
    return entry ? entry.cold : false;
}

function ids() {
    return Object.keys(definitions);
}
