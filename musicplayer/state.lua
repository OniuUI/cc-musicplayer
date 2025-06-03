-- State management for the music player
local config = require("musicplayer.config")

local state = {}

-- Initialize all state variables
function state.init()
    local width, height = term.getSize()
    
    return {
        -- UI State
        width = width,
        height = height,
        tab = 1,
        waiting_for_input = false,
        in_search_result = false,
        clicked_result = nil,
        
        -- Search State
        last_search = nil,
        last_search_url = nil,
        search_results = nil,
        search_error = false,
        
        -- Playback State
        playing = false,
        queue = {},
        now_playing = nil,
        looping = 0, -- 0=off, 1=queue, 2=song
        volume = config.default_volume,
        
        -- Audio State
        playing_id = nil,
        last_download_url = nil,
        playing_status = 0,
        is_loading = false,
        is_error = false,
        player_handle = nil,
        start = nil,
        size = nil,
        needs_next_chunk = 0,
        buffer = nil,
        
        -- Audio decoder
        decoder = require("cc.audio.dfpwm").make_decoder(),
        
        -- Speakers
        speakers = { peripheral.find("speaker") }
    }
end

return state 