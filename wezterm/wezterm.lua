local wezterm = require "wezterm"

local tab_bar_style = {
  -- The color of the strip that goes along the top of the window
  -- (does not apply when fancy tab bar is in use)
  background = "#3c1361",

  -- The active tab is the one that has focus in the window
  active_tab = {
    -- The color of the background area for the tab
    bg_color = "#2b2042",
    -- The color of the text for the tab
    fg_color = "#c0c0c0",

    -- Specify whether you want "Half", "Normal" or "Bold" intensity for the
    -- label shown for this tab.
    -- The default is "Normal"
    intensity = "Normal",

    -- Specify whether you want "None", "Single" or "Double" underline for
    -- label shown for this tab.
    -- The default is "None"
    underline = "None",

    -- Specify whether you want the text to be italic (true) or not (false)
    -- for this tab.  The default is false.
    italic = false,

    -- Specify whether you want the text to be rendered with strikethrough (true)
    -- or not for this tab.  The default is false.
    strikethrough = false,
  },

  -- Inactive tabs are the tabs that do not have focus
  inactive_tab = {
    bg_color = "#1b1032",
    fg_color = "#808080",

    -- The same options that were listed under the `active_tab` section above
    -- can also be used for `inactive_tab`.
  },

  -- You can configure some alternate styling when the mouse pointer
  -- moves over inactive tabs
  inactive_tab_hover = {
    bg_color = "#3b3052",
    fg_color = "#909090",
    italic = true,

    -- The same options that were listed under the `active_tab` section above
    -- can also be used for `inactive_tab_hover`.
  },

  -- The new tab button that let you create new tabs
  new_tab = {
    bg_color = "#1b1032",
    fg_color = "#808080",

    -- The same options that were listed under the `active_tab` section above
    -- can also be used for `new_tab`.
  },

  -- You can configure some alternate styling when the mouse pointer
  -- moves over the new tab button
  new_tab_hover = {
    bg_color = "#3b3052",
    fg_color = "#909090",
    italic = true,

    -- The same options that were listed under the `active_tab` section above
    -- can also be used for `new_tab_hover`.
  },
}

wezterm.on("update-right-status", function(window, pane)
  -- Each element holds the text for a cell in a "powerline" style << fade
  local cells = {}

  local cwd = pane:get_current_working_dir():sub(8) -- remove file:// uri prefix
  local hostname = wezterm.hostname()
  table.insert(cells, cwd)
  table.insert(cells, hostname)

  -- I like my date/time in this style: "Wed Mar 3 08:14"
  local date = wezterm.strftime "%a %b %-d %H:%M"
  table.insert(cells, date)

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
  }

  -- Foreground color for the text across the fade
  local text_fg = "#c0c0c0"

  -- The elements to be formatted
  local elements = {}
  -- How many cells have been formatted
  local num_cells = 0

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

  window:set_right_status(wezterm.format(elements))
end)

local hyperlink_rules = {
  -- Linkify things that look like URLs and the host has a TLD name.
  -- Compiled-in default. Used if you don't specify any hyperlink_rules.
  {
    regex = [[\b\w+://[\w.-]+\.[a-z]{2,15}\S*\b]],
    format = "$0",
  },

  -- linkify email addresses
  -- Compiled-in default. Used if you don't specify any hyperlink_rules.
  {
    regex = [[\b\w+@[\w-]+(\.[\w-]+)+\b]],
    format = "mailto:$0",
  },

  -- file:// URI
  -- Compiled-in default. Used if you don't specify any hyperlink_rules.
  {
    regex = [[\bfile://\S*\b]],
    format = "$0",
  },

  -- Linkify things that look like URLs with numeric addresses as hosts.
  -- E.g. http://127.0.0.1:8000 for a local development server,
  -- or http://192.168.1.1 for the web interface of many routers.
  {
    regex = [[\b\w+://(?:[\d]{1,3}\.){3}[\d]{1,3}\S*\b]],
    format = "$0",
  },

  -- Make username/project paths clickable. This implies paths like the following are for GitHub.
  -- ( "nvim-treesitter/nvim-treesitter" | wbthomason/packer.nvim | wez/wezterm | "wez/wezterm.git" )
  -- As long as a full URL hyperlink regex exists above this it should not match a full URL to
  -- GitHub or GitLab / BitBucket (i.e. https://gitlab.com/user/project.git is still a whole clickable URL)
  {
    regex = [[\bgit@github\.com:([\w\d]{1}[-\w\d]+)(/){1}([-\w\d\.]+)\b]],
    format = "https://www.github.com/$1/$3",
  },
}

return {
  color_scheme = "Gruvbox dark, hard (base16)",
  colors = {
    tab_bar = tab_bar_style,
  },
  font = wezterm.font_with_fallback {
    { family = "JetBrainsMono Nerd Font" },
    { family = "Noto Sans Symbols 2" },
  },
  font_size = 12.0,
  hide_tab_bar_if_only_one_tab = true,
  hyperlink_rules = hyperlink_rules,
  line_height = 1.2,
  tab_bar_at_bottom = true,
  use_fancy_tab_bar = false,
  window_decorations = "RESIZE",
}
