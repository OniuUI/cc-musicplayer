-- Configuration and constants for the music player
local config = {}

config.api_base_url = "https://ipod-2to6magyna-uc.a.run.app/"
config.version = "2.1"
config.default_volume = 1.5
config.max_volume = 3.0
config.chunk_size = 16 * 1024 - 4
config.initial_read_size = 4

-- UI Configuration
config.ui = {
    tabs = {" Now Playing ", " Search "},
    colors = {
        background = colors.black,
        tab_active = colors.white,
        tab_inactive = colors.gray,
        text_primary = colors.white,
        text_secondary = colors.lightGray,
        text_disabled = colors.gray,
        button = colors.gray,
        button_active = colors.white,
        search_box = colors.lightGray,
        error = colors.red,
        loading = colors.gray
    }
}

return config 