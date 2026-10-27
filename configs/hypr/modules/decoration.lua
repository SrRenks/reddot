local home = os.getenv("HOME")
local ok, wc = pcall(dofile, home .. "/.cache/reddot/hypr-colors.lua")
if not ok then wc = nil end

local function border(hex, fallback)
    if type(hex) ~= "string" then hex = fallback end
    return "rgb(" .. hex:gsub("#", "") .. ")"
end

local active   = border(wc and wc.active, "#e60012")
local inactive = border(wc and wc.inactive, "#2a2a2a")

--[[
    Splash rendering SEGVs Hyprland (pango free in renderSplash) when a monitor
    gets reconfigured while the splash would draw, e.g. a display apply from the
    pill. Logo and splash off closes that crash surface.
]]
hl.config({
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
    },
    general = {
        gaps_in     = 1,
        gaps_out    = 0,
        border_size = 1,
        layout      = "master",
        resize_on_border = true,
        ["col.active_border"]   = active,
        ["col.inactive_border"] = inactive,
    },
    decoration = {
        rounding         = 5,
        rounding_power   = 4,
        active_opacity   = 0.80,
        inactive_opacity = 0.50,
        shadow = {
            enabled      = false,
            range        = 12,
            render_power = 3,
            color        = 0xaa14110f,
        },
        blur = {
            enabled           = true,
            size              = 2,
            passes            = 3,
            vibrancy          = 0.17,
            noise             = 0.01,
            new_optimizations = true,
        },
    },
})

