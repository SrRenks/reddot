hl.config({
    input = {
        kb_layout          = "us,us",
        kb_variant       = ",intl",
        kb_model         = "",
        follow_mouse       = 1,
        sensitivity        = 0,
        accel_profile      = "adaptive",
        repeat_rate        = 40,
        repeat_delay       = 400,
        numlock_by_default = false,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
            clickfinger_behavior = false,
            middle_button_emulation = false,
        },
    },
    binds = {
        scroll_event_delay = 40,
    },
})
