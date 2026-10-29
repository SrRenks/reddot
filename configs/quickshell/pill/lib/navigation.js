
/**
 * Navigation metadata for everything that can be named or found from the pill.
 * Runtime routing stays in surfaces.js; this file owns human-facing names,
 * aliases, tags and redirects. Keep it data-only so the Node contract and the
 * QML shell read the same source.
 */
var pages = {
    mixer:      { title: "Audio mixer",             sub: "Volume, faders and audio routing",       aliases: ["audio", "volume", "faders"], tags: ["music", "sound"] },
    sound:      { title: "Sound & EQ",             sub: "Equalizer and output effects",           aliases: ["eq", "audio", "equalizer"], tags: ["music", "sound"] },
    calendar:   { title: "Calendar & weather",          sub: "Date and agenda",                        aliases: ["date", "agenda", "time", "weather", "forecast", "clima"], tags: ["time"] },
    launcher:   { title: "Launcher",          sub: "Applications and commands",              aliases: ["apps", "applications", "run"], tags: ["apps"] },
    clipboard:  { title: "Clipboard",         sub: "Clipboard history",                      aliases: ["copy", "history", "paste"], tags: ["text"] },
    wallpaper:  { title: "Wallpaper",         sub: "Desktop background",                     aliases: ["background", "wall", "image"], tags: ["appearance"] },
    power:      { title: "Session actions",           sub: "Lock, logout, sleep, restart and shut down", aliases: ["logout", "sleep", "reboot", "shutdown"], tags: ["system", "session"] },
    media:      { title: "Media",             sub: "Now playing",                            aliases: ["music", "player", "track"], tags: ["music"] },
    link:       { title: "Notification center",     sub: "Notification history",                    aliases: ["inbox", "messages", "alerts", "notifications"], tags: ["system"] },
    wifi:       { title: "Wi-Fi",             sub: "Wireless networks",                      aliases: ["network", "wireless", "wlan"], tags: ["network"] },
    bt:         { title: "Bluetooth devices",         sub: "Paired devices",                         aliases: ["devices", "peripherals"], tags: ["network"] },
    battery:    { title: "Battery & charge",           sub: "Charge and power state",                 aliases: ["charge", "power"], tags: ["system"] },
    tlp:        { title: "Battery care", sub: "Performance mode and charge window", aliases: ["tlp", "profile", "charge", "battery"], tags: ["power", "system"] },
    thinkpad:   { title: "ThinkPad hardware",          sub: "Fan, LEDs, TrackPoint and function keys", aliases: ["fan", "trackpoint", "leds", "keyboard"], tags: ["hardware"], available: "thinkpad" },
    settings:   { title: "Settings",          sub: "Preferences and controls",                aliases: ["config", "preferences", "options"], tags: ["system"] },
    search:     { title: "Search",             sub: "Find any section",                       aliases: ["find", "lookup", "filter"], tags: ["navigation"], hidden: true },
    shell:      { title: "Shell & bar",             sub: "Bar, clock, pill and notices",            aliases: ["gui", "interface", "bar", "pill", "minimized", "tray"], tags: ["appearance"] },
    clock:      { title: "Clock & date",             sub: "Format, seconds and date",                aliases: ["time", "date", "clock format"], tags: ["bar"] },
    pillsettings: { title: "Pill & notices",           sub: "Geometry, opacity, blur and key notices",  aliases: ["size", "opacity", "blur", "notices"], tags: ["appearance"] },
    windows:    { title: "Windows & layout",           sub: "Layout, gaps, borders, shadow and opacity", aliases: ["layout", "gaps", "borders", "effects"], tags: ["window"] },
    powerhub:   { title: "Power & battery",              sub: "Profile, battery care and session",      aliases: ["battery", "profile", "energy"], tags: ["system"] },
    gamemode:   { title: "Game mode",         sub: "Focus a game and tame the desktop",      aliases: ["game", "gaming", "performance", "focus", "kill apps"], tags: ["system", "gaming"] },
    shortcuts:  { title: "Shortcuts & workspaces",          sub: "Keybinds and special workspaces",       aliases: ["keys", "bindings", "keyboard"], tags: ["system"] },
    maintenance:{ title: "Maintenance",        sub: "Startup commands and updates",          aliases: ["updates", "startup", "cleanup"], tags: ["system"] },
    packages:   { title: "System packages",    sub: "Pacman, AUR and Flatpak update meter",    aliases: ["pacman", "aur", "flatpak", "packages"], tags: ["system", "updates"] },
    keybinds:   { title: "Keybind editor",           sub: "Edit keys, actions and commands",        aliases: ["shortcuts", "keys", "bindings"], tags: ["system"] },
    workspaces: { title: "Special workspaces",         sub: "Special workspaces and shortcuts",       aliases: ["special", "workspace"], tags: ["window"] },
    startup:    { title: "Startup commands",            sub: "Commands run when the session starts",   aliases: ["autostart", "commands", "boot"], tags: ["system"] },
    stash:      { title: "Minimized stash",    sub: "Windows parked on the special workspace", aliases: ["minimized", "hidden", "windows"], tags: ["window"] },
    spaceapps:  { title: "Special apps",       sub: "Apps assigned to special workspaces",    aliases: ["workspaces", "special"], tags: ["window"] },
    recorder:   { title: "Recorder",           sub: "Screen recording",                      aliases: ["screen", "video", "capture"], tags: ["media"] },
    sysmon:     { title: "System monitor",             sub: "Sensors, cooling and compute",           aliases: ["sensors", "cpu", "memory", "temperature"], tags: ["system", "hardware"] },
    appearance: { title: "Appearance & theme",         sub: "Theme, palette, typography and comfort", aliases: ["theme", "palette", "font", "colors"], tags: ["appearance"] },
    bar:        { title: "Bar & widgets",         sub: "Alignment, order and visible items",     aliases: ["bar", "gui", "organize", "status bar", "icons"], tags: ["bar", "layout"] },
    updates:    { title: "Shell updates",            sub: "Shell updates and release notes",        aliases: ["version", "release notes", "update"], tags: ["system", "updates"] },
    display:    { title: "Display",            sub: "Resolution, refresh and scale",          aliases: ["monitor", "screen", "resolution", "scale"], tags: ["display"] },
    input:      { title: "Input",              sub: "Pointer, keyboard, touchpad and cursor",  aliases: ["keyboard", "touchpad", "pointer", "cursor"], tags: ["input"] },
    look:       { title: "Window effects",   sub: "Layout, gaps, borders, shadow and opacity", aliases: ["gaps", "borders", "shadow", "opacity", "blur"], tags: ["window"] },
    presets:    { title: "Power presets",      sub: "Saved profile and charge combinations",   aliases: ["preset", "profile", "charge"], tags: ["power"] },
    idlelock:   { title: "Security & idle",           sub: "Fingerprint and idle lock",               aliases: ["lock", "fingerprint", "idle", "suspend", "security", "do not disturb", "dnd"], tags: ["security"] },
    animation:  { title: "Motion & animation",              sub: "Animation speed, curve and reduced motion", aliases: ["animation", "speed", "motion"], tags: ["window"] },
    fontpicker: { title: "Font family",                sub: "Installed font families",                 aliases: ["typography", "typeface", "font"], tags: ["appearance"] }
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

/**
 * Extra search words that are not useful as display aliases. Search treats
 * these like tags: lower weight than a title or alias, but enough to catch the
 * words people actually type (mic, pacman, charges, widgets, sensors).
 */
var pageKeywords = {
    mixer: ["microphone", "mic", "input", "output", "routing", "channels", "sink", "source"],
    sound: ["equalizer", "denoise", "noise", "effects", "autoeq", "speakers", "headphones"],
    calendar: ["agenda", "events", "month", "week", "forecast", "temperature"],
    launcher: ["run", "open", "exec", "command", "applications", "apps"],
    clipboard: ["copy", "paste", "history", "snippets", "text"],
    wallpaper: ["background", "wall", "slideshow", "random", "image", "desktop"],
    power: ["logout", "lock", "suspend", "sleep", "restart", "reboot", "shutdown", "session"],
    media: ["player", "track", "song", "music", "now playing", "mpris"],
    link: ["inbox", "notifications", "alerts", "messages", "history"],
    wifi: ["wireless", "wlan", "ssid", "network", "hotspot", "password"],
    bt: ["bluetooth", "pair", "paired", "peripherals", "devices"],
    battery: ["charge", "charging", "percent", "health", "capacity", "runtime", "power"],
    tlp: ["tlp", "battery care", "charge limit", "threshold", "power profile", "governor"],
    thinkpad: ["fan", "trackpoint", "leds", "keyboard light", "bios", "firmware", "mute led"],
    settings: ["preferences", "configuration", "options", "control center"],
    search: ["find", "lookup", "filter", "command palette"],
    shell: ["bar", "pill", "clock", "widgets", "components", "tray", "minimized"],
    clock: ["time", "date", "seconds", "12 hour", "24 hour", "timezone"],
    pillsettings: ["pill", "opacity", "blur", "notices", "notifications", "battery low", "charger", "mic", "geometry"],
    windows: ["layout", "gaps", "borders", "shadow", "opacity", "blur", "workspaces"],
    powerhub: ["power", "battery", "profile", "session", "energy", "charge"],
    gamemode: ["game", "gaming", "fps", "performance", "focus", "cleanup", "terminate", "ram", "allowlist"],
    shortcuts: ["keys", "keybinds", "bindings", "workspaces", "special"],
    maintenance: ["startup", "updates", "packages", "autostart", "cleanup"],
    packages: ["pacman", "aur", "flatpak", "system packages", "updates", "update count"],
    keybinds: ["keys", "shortcuts", "bindings", "actions", "commands"],
    workspaces: ["special", "scratchpad", "stash", "workspace rules"],
    startup: ["autostart", "boot", "login", "session", "commands"],
    stash: ["minimized", "hidden", "restore", "windows"],
    spaceapps: ["special", "workspace", "apps", "assign"],
    recorder: ["screen record", "capture", "video", "screenshot", "gif"],
    sysmon: ["sensors", "cpu", "gpu", "ram", "memory", "temperature", "fan", "compute", "system monitor"],
    appearance: ["theme", "palette", "colors", "font", "typography", "wallpaper"],
    bar: ["bar", "widgets", "components", "status bar", "zones", "alignment", "order", "icons"],
    updates: ["shell update", "release notes", "version", "changelog", "upgrade"],
    display: ["monitor", "screen", "resolution", "refresh", "scale", "hdr", "vrr"],
    input: ["keyboard", "touchpad", "pointer", "cursor", "mouse", "tap to click"],
    look: ["window", "effects", "gaps", "borders", "shadow", "opacity", "blur"],
    presets: ["power preset", "profile", "battery", "charge"],
    idlelock: ["security", "lock", "fingerprint", "idle", "suspend", "dnd", "do not disturb"],
    animation: ["motion", "animation", "speed", "curve", "reduce motion"],
    fontpicker: ["font", "typeface", "typography", "font family"]
};

var statusKeywords = {
    weather: ["forecast", "temperature", "climate", "conditions"],
    minimized: ["hidden", "windows", "restore", "stash"],
    tray: ["icons", "status icons", "applications"],
    dnd: ["silence", "mute notifications", "do not disturb", "focus"],
    network: ["wifi", "wireless", "bluetooth", "battery", "internet"],
    inbox: ["notifications", "messages", "alerts", "history"],
    mixer: ["volume", "audio", "mic", "microphone", "faders"],
    sound: ["equalizer", "eq", "effects", "audio"],
    thinkpad: ["fan", "leds", "trackpoint", "bios", "firmware"],
    sysmon: ["cpu", "gpu", "ram", "memory", "sensors", "temperature"],
    updates: ["packages", "pacman", "aur", "flatpak", "update count"],
    recorder: ["record", "video", "capture", "screen"],
    settings: ["preferences", "config", "options"],
    power: ["battery", "session", "logout", "lock", "shutdown"]
};

for (var pk in pageKeywords)
    if (pages[pk])
        pages[pk].keywords = pageKeywords[pk];
for (var sk in statusKeywords)
    if (status[sk])
        status[sk].keywords = statusKeywords[sk];

var settingsGroups = {
    "Desktop": ["appearance", "shell", "windows", "display"],
    "Controls": ["input", "shortcuts"],
    "System": ["powerhub", "sysmon", "maintenance", "idlelock"]
};

var hubs = {
    shell: ["bar", "clock", "pillsettings"],
    windows: ["look", "animation"],
    powerhub: ["tlp", "presets", "power", "gamemode"],
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
        allPageIds: allPageIds, allStatusIds: allStatusIds, settingsIndexIds: settingsIndexIds, hubIds: hubIds,
        pageKeywords: pageKeywords, statusKeywords: statusKeywords };
}
