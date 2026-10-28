
/**
 * Navigation metadata for everything that can be named or found from the pill.
 * Runtime routing stays in surfaces.js; this file owns human-facing names,
 * aliases, tags and redirects. Keep it data-only so the Node contract and the
 * QML shell read the same source.
 */
var pages = {
    mixer:      { title: "Mixer",             sub: "Volume, faders and audio routing",       aliases: ["audio", "volume", "faders"], tags: ["music", "sound"] },
    sound:      { title: "Sound",             sub: "Equalizer and output effects",           aliases: ["eq", "audio", "equalizer"], tags: ["music", "sound"] },
    calendar:   { title: "Calendar",          sub: "Date and agenda",                        aliases: ["date", "agenda", "time"], tags: ["time"] },
    launcher:   { title: "Launcher",          sub: "Applications and commands",              aliases: ["apps", "applications", "run"], tags: ["apps"] },
    clipboard:  { title: "Clipboard",         sub: "Clipboard history",                      aliases: ["copy", "history", "paste"], tags: ["text"] },
    wallpaper:  { title: "Wallpaper",         sub: "Desktop background",                     aliases: ["background", "wall", "image"], tags: ["appearance"] },
    power:      { title: "Session",           sub: "Lock, logout, sleep, restart and shut down", aliases: ["logout", "sleep", "reboot", "shutdown"], tags: ["system", "session"] },
    media:      { title: "Media",             sub: "Now playing",                            aliases: ["music", "player", "track"], tags: ["music"] },
    link:       { title: "Notifications",     sub: "Notification history",                    aliases: ["inbox", "messages", "alerts"], tags: ["system"] },
    wifi:       { title: "Wi-Fi",             sub: "Wireless networks",                      aliases: ["network", "wireless", "wlan"], tags: ["network"] },
    bt:         { title: "Bluetooth",         sub: "Paired devices",                         aliases: ["devices", "peripherals"], tags: ["network"] },
    battery:    { title: "Battery",           sub: "Charge and power state",                 aliases: ["charge", "power"], tags: ["system"] },
    tlp:        { title: "Profile & battery care", sub: "Performance mode and charge window", aliases: ["tlp", "profile", "charge", "battery"], tags: ["power", "system"] },
    thinkpad:   { title: "ThinkPad",          sub: "Fan, LEDs, TrackPoint and function keys", aliases: ["fan", "trackpoint", "leds", "keyboard"], tags: ["hardware"], available: "thinkpad" },
    settings:   { title: "Settings",          sub: "Preferences and controls",                aliases: ["config", "preferences", "options"], tags: ["system"] },
    shell:      { title: "Shell",             sub: "Bar, clock, pill and notices",            aliases: ["gui", "interface", "bar", "pill"], tags: ["appearance"] },
    clock:      { title: "Clock",             sub: "Format, seconds and date",                aliases: ["time", "date", "clock format"], tags: ["bar"] },
    pillsettings: { title: "Pill",           sub: "Geometry, opacity, blur and key notices",  aliases: ["size", "opacity", "blur", "notices"], tags: ["appearance"] },
    windows:    { title: "Windows",           sub: "Layout, gaps, borders, shadow and opacity", aliases: ["layout", "gaps", "borders", "effects"], tags: ["window"] },
    powerhub:   { title: "Power",              sub: "Profile, battery care and session",      aliases: ["battery", "profile", "energy"], tags: ["system"] },
    shortcuts:  { title: "Shortcuts",          sub: "Keybinds and special workspaces",       aliases: ["keys", "bindings", "keyboard"], tags: ["system"] },
    maintenance:{ title: "Maintenance",        sub: "Startup commands and updates",          aliases: ["updates", "startup", "cleanup"], tags: ["system"] },
    packages:   { title: "System packages",    sub: "Pacman, AUR and Flatpak update meter",    aliases: ["pacman", "aur", "flatpak", "packages"], tags: ["system", "updates"] },
    keybinds:   { title: "Keybinds",           sub: "Edit keys, actions and commands",        aliases: ["shortcuts", "keys", "bindings"], tags: ["system"] },
    workspaces: { title: "Workspaces",         sub: "Special workspaces and shortcuts",       aliases: ["special", "workspace"], tags: ["window"] },
    startup:    { title: "Startup",            sub: "Commands run when the session starts",   aliases: ["autostart", "commands", "boot"], tags: ["system"] },
    stash:      { title: "Minimized stash",    sub: "Windows parked on the special workspace", aliases: ["minimized", "hidden", "windows"], tags: ["window"] },
    spaceapps:  { title: "Special apps",       sub: "Apps assigned to special workspaces",    aliases: ["workspaces", "special"], tags: ["window"] },
    recorder:   { title: "Recorder",           sub: "Screen recording",                      aliases: ["screen", "video", "capture"], tags: ["media"] },
    sysmon:     { title: "System",             sub: "Sensors, cooling and compute",           aliases: ["sensors", "cpu", "memory", "temperature"], tags: ["system", "hardware"] },
    appearance: { title: "Appearance",         sub: "Theme, palette, typography and comfort", aliases: ["theme", "palette", "font", "colors"], tags: ["appearance"] },
    bar:        { title: "Bar layout",         sub: "Alignment, order and visible items",     aliases: ["bar", "gui", "organize", "status bar", "icons"], tags: ["bar", "layout"] },
    updates:    { title: "Updates",            sub: "Shell updates and release notes",        aliases: ["version", "release notes", "update"], tags: ["system", "updates"] },
    display:    { title: "Display",            sub: "Resolution, refresh and scale",          aliases: ["monitor", "screen", "resolution", "scale"], tags: ["display"] },
    input:      { title: "Input",              sub: "Pointer, keyboard, touchpad and cursor",  aliases: ["keyboard", "touchpad", "pointer", "cursor"], tags: ["input"] },
    look:       { title: "Window & effects",   sub: "Layout, gaps, borders, shadow and opacity", aliases: ["gaps", "borders", "shadow", "opacity", "blur"], tags: ["window"] },
    presets:    { title: "Power presets",      sub: "Saved profile and charge combinations",   aliases: ["preset", "profile", "charge"], tags: ["power"] },
    idlelock:   { title: "Security",           sub: "Fingerprint and idle lock",               aliases: ["lock", "fingerprint", "idle", "suspend", "security"], tags: ["security"] },
    animation:  { title: "Motion",              sub: "Animation speed, curve and reduced motion", aliases: ["animation", "speed", "motion"], tags: ["window"] },
    fontpicker: { title: "Font",                sub: "Installed font families",                 aliases: ["typography", "typeface", "font"], tags: ["appearance"] }
};

var status = {
    weather:   { title: "Weather",           sub: "Open the forecast",             target: "calendar", aliases: ["climate", "forecast", "temperature"] },
    minimized: { title: "Minimized apps",    sub: "Restore a minimized window",     target: "",         aliases: ["windows", "hidden"] },
    tray:      { title: "System tray",       sub: "Status icons from applications", target: "",         aliases: ["tray", "icons"] },
    dnd:       { title: "Do not disturb",    sub: "Notification state",             target: "",         action: "toggle-dnd", aliases: ["silence", "mute", "notifications"] },
    network:   { title: "Network",            sub: "Wi-Fi, Bluetooth and battery",   target: "wifi",     aliases: ["wifi", "wireless", "bluetooth"] },
    inbox:     { title: "Notifications",     sub: "Open notification history",      target: "link",     aliases: ["inbox", "messages", "alerts"] },
    mixer:     { title: "Mixer",              sub: "Open audio faders",              target: "mixer",    aliases: ["volume", "audio"] },
    sound:     { title: "Sound",              sub: "Open the equalizer",             target: "sound",    aliases: ["eq", "audio"] },
    thinkpad:  { title: "ThinkPad",           sub: "Fan, LEDs and TrackPoint",       target: "thinkpad", available: "thinkpad", aliases: ["fan", "trackpoint"] },
    sysmon:    { title: "System monitor",     sub: "Sensors and compute",            target: "sysmon",   aliases: ["cpu", "memory", "sensors"] },
    updates:   { title: "Package updates",    sub: "Open system packages",           target: "packages", aliases: ["updates", "pacman", "aur"] },
    recorder:  { title: "Recorder",           sub: "Screen recording",               target: "recorder", aliases: ["record", "video"] },
    settings:  { title: "Settings",           sub: "Open preferences",               target: "settings", aliases: ["config", "options"] },
    power:     { title: "Power",              sub: "Session and power actions",      target: "power",    aliases: ["session", "battery"] }
};

var settingsGroups = {
    "Desktop": ["appearance", "shell", "windows", "display"],
    "Controls": ["input", "idlelock", "shortcuts"],
    "System": ["powerhub", "sysmon", "maintenance"]
};

var hubs = {
    shell: ["bar", "clock", "pillsettings"],
    windows: ["look", "animation"],
    powerhub: ["tlp", "presets", "power"],
    shortcuts: ["keybinds", "workspaces"],
    maintenance: ["startup", "updates", "packages"]
};

function pageInfo(id) {
    return pages[id] || null;
}

function statusInfo(id) {
    return status[id] || null;
}

function pageLabel(id) {
    var entry = pageInfo(id);
    return entry ? entry.title : id;
}

function statusLabel(id) {
    var entry = statusInfo(id);
    return entry ? entry.title : id;
}

function allPageIds() {
    return Object.keys(pages);
}

function allStatusIds() {
    return Object.keys(status);
}

function settingsIndexIds() {
    var out = [];
    for (var group in settingsGroups)
        out = out.concat(settingsGroups[group]);
    return out;
}

function hubIds() {
    var out = [];
    for (var hub in hubs)
        out = out.concat(hubs[hub]);
    return out;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { pages: pages, status: status, settingsGroups: settingsGroups, hubs: hubs,
        pageInfo: pageInfo, statusInfo: statusInfo, pageLabel: pageLabel, statusLabel: statusLabel,
        allPageIds: allPageIds, allStatusIds: allStatusIds, settingsIndexIds: settingsIndexIds, hubIds: hubIds };
}
