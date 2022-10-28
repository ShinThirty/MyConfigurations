local wezterm = require 'wezterm'

local home_dir = wezterm.home_dir
local configuration_dir = home_dir .. "/MyConfigurations"

wezterm.on("update-right-status", function(window, pane)
    -- Each element holds the text for a cell in a "powerline" style << fade
    local cells = {};

    local cwd = pane:get_current_working_dir():sub(8); -- remove file:// uri prefix
    local hostname = wezterm.hostname();
    table.insert(cells, cwd);
    table.insert(cells, hostname);

    -- I like my date/time in this style: "Wed Mar 3 08:14"
    local date = wezterm.strftime("%a %b %-d %H:%M");
    table.insert(cells, date);

    -- An entry for each battery (typically 0 or 1 battery)
    for _, b in ipairs(wezterm.battery_info()) do
        table.insert(cells, string.format("%.0f%%", b.state_of_charge * 100))
    end

    -- The filled in variant of the < symbol
    local SOLID_LEFT_ARROW = utf8.char(0xe0b2)

    -- Color palette for the backgrounds of each cell
    local colors = {
        "#3c1361",
        "#52307c",
        "#663a82",
        "#7c5295",
        "#b491c8",
    };

    -- Foreground color for the text across the fade
    local text_fg = "#c0c0c0";

    -- The elements to be formatted
    local elements = {};
    -- How many cells have been formatted
    local num_cells = 0;

    -- Translate a cell into elements
    local function push(text, is_last)
        local cell_no = num_cells + 1
        table.insert(elements, { Foreground = { Color = text_fg } })
        table.insert(elements, { Background = { Color = colors[cell_no] } })
        table.insert(elements, { Text = " " .. text .. " " })
        if not is_last then
            table.insert(elements, { Foreground = { Color = colors[cell_no + 1] } })
            table.insert(elements, { Text = SOLID_LEFT_ARROW })
        end
        num_cells = num_cells + 1
    end

    while #cells > 0 do
        local cell = table.remove(cells, 1)
        push(cell, #cells == 0)
    end

    window:set_right_status(wezterm.format(elements));
end);

local colors, _ = wezterm.color.load_scheme(configuration_dir .. "/wezterm/nightfox_wezterm.toml")
return {
    colors = colors,
    font = wezterm.font_with_fallback {
        { family = 'JetBrainsMono Nerd Font', weight = 'Bold' },
    },
    font_size = 13.0,
    hide_tab_bar_if_only_one_tab = true,
    line_height = 1.2,
    tab_bar_at_bottom = true,
    use_fancy_tab_bar = false,
    window_decorations = 'RESIZE',
}