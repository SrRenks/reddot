local mod  = "SUPER"
local term = "ghostty"
local fm   = term .. " -e yazi" -- yazi is a TUI: it needs the terminal as its host

hl.bind(mod .. " + SHIFT + Q",         hl.dsp.window.kill()) -- Kill Window
hl.bind(mod .. " + Q",    hl.dsp.window.close()) -- Close Window
hl.bind(mod .. " + Return",    hl.dsp.exec_cmd(term)) -- Open Terminal
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen()) -- Fullscreen
hl.bind(mod .. " + E",         hl.dsp.exec_cmd(fm)) -- File Explorer
hl.bind(mod .. " + T",         hl.dsp.window.float({ action = "toggle" })) -- Toggle Window Float
hl.bind(mod .. " + M",         hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/minimize-toggle.sh")) -- Minimize Window
hl.bind(mod .. " + SHIFT + M", hl.dsp.workspace.toggle_special("minimized")) -- Toggle Minimized Window

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mod .. " + Left",       hl.dsp.focus({ direction = "l" })) -- Focus left Window
hl.bind(mod .. " + Right",      hl.dsp.focus({ direction = "r" })) -- Focus Right Window
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "r+1" }))

hl.bind(mod .. " + 1", hl.dsp.focus({ workspace = 1 })) -- Focus Workspace 1
hl.bind(mod .. " + 2", hl.dsp.focus({ workspace = 2 })) -- Focus Workspace 2
hl.bind(mod .. " + 3", hl.dsp.focus({ workspace = 3 })) -- Focus Workspace 3
hl.bind(mod .. " + 4", hl.dsp.focus({ workspace = 4 })) -- Focus Workspace 4
hl.bind(mod .. " + 5", hl.dsp.focus({ workspace = 5 })) -- Focus Workspace 5
hl.bind(mod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mod .. " + 0", hl.dsp.focus({ workspace = 10 }))

hl.bind(mod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1,  follow = false }))
hl.bind(mod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2,  follow = false }))
hl.bind(mod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3,  follow = false }))
hl.bind(mod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4,  follow = false }))
hl.bind(mod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5,  follow = false }))
hl.bind(mod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6,  follow = false }))
hl.bind(mod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7,  follow = false }))
hl.bind(mod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8,  follow = false }))
hl.bind(mod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9,  follow = false }))
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10, follow = false }))

hl.bind(mod .. " + P",         hl.dsp.workspace.toggle_special("private"))
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/special-toggle.sh private"))

hl.bind(mod .. " + S",         hl.dsp.workspace.toggle_special("stash"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/special-toggle.sh stash"))

hl.bind(mod .. " + SHIFT + C",  hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mod .. " + SHIFT + R",  hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/record.sh")) -- Record
hl.bind(mod .. " + SHIFT + E",  hl.dsp.exec_cmd("easyeffects --bypass-toggle")) -- EasyEffects bypass
hl.bind(mod .. " + SHIFT + F",  hl.dsp.exec_cmd("qs -c pill ipc call pill blur")) -- Toggle blur + window transparency

hl.bind(mod .. " + A",      hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/open-surface.sh launcher")) -- Open Apps
hl.bind(mod .. " + W",      hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/open-surface.sh wallpaper")) -- Wallpaper Picker
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/wallpaper.sh")) -- Wallpaper Flush
hl.bind(mod .. " + V",          hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/open-surface.sh clipboard")) -- Open Clipboard

hl.bind(mod .. " + L",          hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/lock.sh"))

hl.bind(mod .. " + SHIFT + B",  hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/open-surface.sh tlp")) -- TLP charge window
hl.bind(mod .. " + SHIFT + T",  hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/open-surface.sh thinkpad")) -- ThinkPad extras
hl.bind(mod .. " + G",          hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/open-surface.sh gameMode")) -- Gamemode

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/volume.sh"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/volume.sh down"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     { locked = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay",        hl.dsp.global("quickshell:mediaToggle"),                           { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.global("quickshell:mediaNext"),                             { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.global("quickshell:mediaPrev"),                             { locked = true })
hl.bind(mod .. " + Space", hl.dsp.exec_cmd("hyprctl switchxkblayout all next")) -- Toggle Keyboard Layout
hl.bind(mod .. " + SHIFT + Space", hl.dsp.exec_cmd("qs -c pill ipc call pill toggle \"\"")) -- Open/close pill, last surface
hl.bind(mod .. " + Up",   hl.dsp.focus({ direction = "u" })) -- Focus Up Window
hl.bind(mod .. " + Down", hl.dsp.focus({ direction = "d" })) -- Focus Below Window
hl.bind(mod .. " + SHIFT + Left",  hl.dsp.window.move({ direction = "l" })) -- Move Window Left
hl.bind(mod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "r" })) -- Move Window Right
hl.bind(mod .. " + SHIFT + Up",    hl.dsp.window.move({ direction = "u" })) -- Move Window Up
hl.bind(mod .. " + SHIFT + Down",  hl.dsp.window.move({ direction = "d" })) -- Move Window Down

-- Screenshots: Print or SUPER+F9 starts rishot normally; Shift+Print or
-- SUPER+SHIFT+Print jumps straight to the focused monitor. rishot is installed
-- in ~/.local/bin, which is not on the compositor's exec PATH.
local rishot_region = os.getenv("HOME") .. "/.local/bin/rishot"
local rishot_current = os.getenv("HOME") .. "/.config/hypr/scripts/reddot-shot-current.sh"

hl.bind("Print", hl.dsp.exec_cmd(rishot_region))
hl.bind("SUPER + F9", hl.dsp.exec_cmd(rishot_region))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(rishot_current))
hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd(rishot_current))
