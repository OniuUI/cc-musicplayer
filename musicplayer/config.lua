-- Configuration and constants for the radio player
local config = {}

config.api_base_url = "https://ipod-2to6magyna-uc.a.run.app/"
config.version = "2.1"
config.default_volume = 1.5
config.max_volume = 3.0
config.chunk_size = 16 * 1024 - 4
config.initial_read_size = 4

-- Branding Configuration
config.branding = {
    title = "Bognesferga Radio",
    developer = "Developed by Forty",
    rainbow_colors = {colors.red, colors.orange, colors.yellow, colors.lime, colors.cyan, colors.lightBlue, colors.purple, colors.magenta}
}

-- UI Configuration
config.ui = {
    tabs = {" Now Playing ", " Search "},
    colors = {
        -- Main interface
        background = colors.black,
        header_bg = colors.blue,
        footer_bg = colors.gray,
        
        -- Tabs
        tab_active = colors.white,
        tab_inactive = colors.lightGray,
        tab_bg = colors.blue,
        
        -- Text colors
        text_primary = colors.white,
        text_secondary = colors.lightGray,
        text_disabled = colors.gray,
        text_accent = colors.yellow,
        text_success = colors.lime,
        text_error = colors.red,
        
        -- Interactive elements
        button = colors.lightBlue,
        button_active = colors.cyan,
        button_hover = colors.blue,
        search_box = colors.lightGray,
        
        -- Status colors
        playing = colors.lime,
        loading = colors.yellow,
        error = colors.red,
        
        -- Volume slider
        volume_bg = colors.gray,
        volume_fill = colors.cyan,
        volume_text = colors.white
    }
}

return config 