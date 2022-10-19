local wezterm = require 'wezterm'

return {
    color_scheme = 'Dracula (Official)',
    font = wezterm.font_with_fallback {
        { family = 'JetBrainsMono Nerd Font', weight = 'Bold' },
    },
    font_size = 13.0,
    line_height = 1.2,
}
