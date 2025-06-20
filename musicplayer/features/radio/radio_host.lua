-- Radio Host feature for Bognesferga Radio
-- Enhanced with YouTube search integration and synchronized streaming
-- PRE-Buffer Synchronization System Implementation

local radioProtocol = require("musicplayer/network/radio_protocol")
local components = require("musicplayer.ui.components")
local themes = require("musicplayer.ui.themes")
local bufferManager = require("musicplayer/audio/buffer_manager")
local latencyManager = require("musicplayer/network/latency_manager")
local config = require("musicplayer/config")

local radioHost = {}

function radioHost.init(systemModules)
    local state = {
        -- System modules
        system = systemModules.system,
        httpClient = systemModules.httpClient,
        speakerManager = systemModules.speakerManager,
        errorHandler = systemModules.errorHandler,
        logger = systemModules.logger,
        
        -- UI state (like YouTube player)
        width = 0,
        height = 0,
        tab = 1, -- 1 = Station Setup, 2 = Playlist, 3 = Now Playing
        waiting_for_input = false,
        
        -- Station configuration
        station_name = "",
        station_description = "",
        station_configured = false,
        
        -- Broadcasting state
        is_broadcasting = false,
        listeners = {},
        max_listeners = 10,
        
        -- YouTube search integration (like YouTube player)
        last_search = nil,
        last_search_url = nil,
        search_results = nil,
        search_error = false,
        in_search_result = false,
        clicked_result = nil,
        current_page = 1,
        results_per_page = 5,
        
        -- Playlist management (enhanced)
        playlist = {},
        current_song_index = 0,
        now_playing = nil,
        
        -- Playback state (like YouTube player)
        playing = false,
        volume = 1.5,
        muted = false, -- NEW: Mute state for host
        looping = 1, -- 0=off, 1=playlist, 2=song
        
        -- Audio streaming (like YouTube player)
        playing_id = nil,
        last_download_url = nil,
        playing_status = 0,
        is_loading = false,
        is_error = false,
        player_handle = nil,
        start = nil,
        pcm = nil,
        size = nil,
        decoder = require("cc.audio.dfpwm").make_decoder(),
        needs_next_chunk = 0,
        buffer = nil,
        
        -- Network state
        protocol_available = false,
        last_announce_time = 0,
        announce_interval = 60, -- seconds - reduced frequency
        last_sync_time = 0,
        sync_interval = 15, -- seconds - sync every 15 seconds instead of 10
        
        -- Playback synchronization
        current_playback_session = nil, -- Unique ID for current playback session
        playback_start_time = 0, -- When current song started playing
        
        -- Song position tracking (like radio client)
        song_start_time = 0, -- When we started playing current song locally
        song_duration = 0, -- Total length of current song in seconds (estimated)
        current_song_position = 0, -- Current position in the song
        last_position_update = 0, -- When we last updated position
        
        -- PRE-BUFFER SYNCHRONIZATION SYSTEM
        audio_buffer = nil,        -- Buffer manager instance
        latency_tracker = nil,     -- Latency tracker instance
        buffer_ready = false,      -- Whether buffer is ready for synchronized playback
        sync_enabled = true,       -- Enable/disable sync system
        
        -- Buffer management
        buffer_fill_rate = 0,      -- How fast we're filling the buffer
        buffer_health = 100,       -- Buffer health percentage
        last_buffer_update = 0,    -- When we last updated buffer
        
        -- Sync coordination
        sync_session_id = nil,     -- Current sync session ID
        next_sync_timestamp = 0,   -- When next sync should happen
        sync_in_progress = false,  -- Whether we're currently syncing
        
        -- API configuration
        api_base_url = "https://ipod-2to6magyna-uc.a.run.app/",
        version = "2.1"
    }
    
    -- Initialize radio protocol
    state.protocol_available = radioProtocol.init(state.errorHandler)
    if not state.protocol_available then
        state.logger.warn("RadioHost", "No wireless modem found - radio hosting disabled")
    else
        state.logger.info("RadioHost", "Radio protocol initialized for hosting")
        -- Open broadcast channel immediately to listen for discovery requests
        radioProtocol.openBroadcastChannel()
        state.logger.info("RadioHost", "Opened broadcast channel for discovery requests")
    end
    
    -- Initialize PRE-buffer system
    if state.protocol_available then
        state.audio_buffer = bufferManager.createBuffer(state.logger)
        state.latency_tracker = latencyManager.createTracker(state.logger)
        
        state.logger.info("RadioHost", string.format("PRE-buffer system initialized (%.1fs buffer, %.1fs chunks)", 
            config.radio_sync.buffer_duration, config.radio_sync.chunk_duration))
    end
    
    return state
end

function radioHost.run(state)
    state.logger.info("RadioHost", "Starting enhanced radio host with YouTube integration")
    
    -- Get screen size
    state.width, state.height = term.getSize()
    
    -- Check if radio is available
    if not state.protocol_available then
        radioHost.showNoModemError(state)
        return "menu"
    end
    
    -- Get raw speakers
    local speakers = state.speakerManager.getRawSpeakers()
    if #speakers == 0 then
        state.errorHandler.handleError("RadioHost", "No speakers attached. You need to connect a speaker to this computer.", 3)
        return "menu"
    end
    
    -- Setup station if not configured
    if not state.station_configured then
        local result = radioHost.setupStation(state)
        if result == "back_to_menu" then
            return "menu"
        end
    end
    
    -- Run main loops (like YouTube player) with proper return handling
    local result = parallel.waitForAny(
        function() return radioHost.uiLoop(state, speakers) end,
        function() return radioHost.audioLoop(state, speakers) end,
        function() return radioHost.httpLoop(state) end,
        function() return radioHost.networkLoop(state) end
    )
    
    -- Clean up
    radioHost.cleanup(state)
    
    return "menu"
end

function radioHost.showNoModemError(state)
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Beautiful header
    term.setBackgroundColor(colors.blue)
    term.setCursorPos(1, 1)
    term.clearLine()
    local title = "Bognesferga Radio Host"
    local fullHeader = "🎙️ " .. title .. " 🎙️"
    local headerX = math.floor((state.width - #fullHeader) / 2) + 1
    term.setCursorPos(headerX, 1)
    term.setTextColor(colors.yellow)
    term.write("🎙️ ")
    term.setTextColor(colors.white)
    term.write(title)
    term.setTextColor(colors.yellow)
    term.write(" 🎙️")
    
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.red)
    term.setCursorPos(3, 4)
    term.write("Radio Host Error")
    
    term.setTextColor(colors.white)
    term.setCursorPos(3, 6)
    term.write("No wireless modem detected!")
    
    term.setCursorPos(3, 8)
    term.write("To host radio stations, you need:")
    term.setCursorPos(3, 9)
    term.write("• A wireless modem attached to this computer")
    term.setCursorPos(3, 10)
    term.write("• The modem must be on any side")
    
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 12)
    term.write("How to add a wireless modem:")
    term.setCursorPos(3, 13)
    term.write("1. Craft a wireless modem")
    term.setCursorPos(3, 14)
    term.write("2. Right-click on any side of this computer")
    term.setCursorPos(3, 15)
    term.write("3. Restart the radio host")
    
    term.setTextColor(colors.lightGray)
    term.setCursorPos(3, 17)
    term.write("Press any key to return to menu...")
    
    os.pullEvent("key")
end

function radioHost.setupStation(state)
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Beautiful header
    term.setBackgroundColor(colors.blue)
    term.setCursorPos(1, 1)
    term.clearLine()
    local title = "Radio Station Setup"
    local fullHeader = "🎙️ " .. title .. " 🎙️"
    local headerX = math.floor((state.width - #fullHeader) / 2) + 1
    term.setCursorPos(headerX, 1)
    term.setTextColor(colors.yellow)
    term.write("🎙️ ")
    term.setTextColor(colors.white)
    term.write(title)
    term.setTextColor(colors.yellow)
    term.write(" 🎙️")
    
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 4)
    term.write("Welcome to Radio Station Setup!")
    
    term.setTextColor(colors.white)
    term.setCursorPos(3, 6)
    term.write("Let's configure your radio station:")
    
    -- Get station name
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 8)
    term.write("Station Name: ")
    term.setTextColor(colors.white)
    state.station_name = read()
    
    if state.station_name == "" then
        state.station_name = "Radio Station " .. os.getComputerID()
    end
    
    -- Get station description
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 10)
    term.write("Description (optional): ")
    term.setTextColor(colors.white)
    state.station_description = read()
    
    if state.station_description == "" then
        state.station_description = "A music radio station"
    end
    
    term.setTextColor(colors.lime)
    term.setCursorPos(3, 12)
    term.write("Station configured successfully!")
    term.setCursorPos(3, 13)
    term.write("Name: " .. state.station_name)
    term.setCursorPos(3, 14)
    term.write("Description: " .. state.station_description)
    
    term.setTextColor(colors.lightGray)
    term.setCursorPos(3, 16)
    term.write("Press any key to continue...")
    
    os.pullEvent("key")
    
    state.station_configured = true
    state.logger.info("RadioHost", "Station configured: " .. state.station_name)
    
    return "continue"
end

function radioHost.drawHostInterface(state)
    components.clearScreen()
    
    local theme = themes.getCurrent()
    
    -- Draw header
    components.drawHeader(state)
    
    -- Station info
    term.setBackgroundColor(theme.colors.background)
    term.setTextColor(theme.colors.text_accent)
    term.setCursorPos(3, 4)
    term.write("🎙️ " .. state.station_name)
    
    term.setTextColor(theme.colors.text_secondary)
    term.setCursorPos(3, 5)
    term.write(state.station_description)
    
    -- Broadcasting status
    local statusY = 7
    if state.is_broadcasting then
        components.drawStatusIndicator(3, statusY, "connected", "Broadcasting Live")
        term.setTextColor(theme.colors.text_secondary)
        term.setCursorPos(25, statusY)
        term.write("👥 " .. #state.listeners .. " listeners")
    else
        components.drawStatusIndicator(3, statusY, "disconnected", "Not Broadcasting")
    end
    
    -- Current song info
    if state.now_playing then
        term.setTextColor(theme.colors.text_accent)
        term.setCursorPos(3, 9)
        term.write("♪ Now Playing:")
        term.setTextColor(theme.colors.text_primary)
        term.setCursorPos(3, 10)
        term.write(state.now_playing.name or "Unknown Song")
        term.setTextColor(theme.colors.text_secondary)
        term.setCursorPos(3, 11)
        term.write("by " .. (state.now_playing.artist or "Unknown Artist"))
    end
    
    -- Playlist
    radioHost.drawPlaylist(state)
    
    -- Control buttons
    radioHost.drawControls(state)
    
    -- Draw footer
    components.drawFooter(state)
end

function radioHost.drawPlaylist(state)
    -- Playlist header with yellow accent
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 4)
    term.write("Radio Playlist Management:")
    
    -- Search box (like YouTube player)
    term.setTextColor(colors.white)
    term.setCursorPos(3, 6)
    term.write("Search for songs to add:")
    
    -- Beautiful search box
    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)
    term.setCursorPos(3, 7)
    local searchText = state.last_search or ""
    local searchDisplay = searchText
    if #searchDisplay > 30 then
        searchDisplay = searchDisplay:sub(1, 27) .. "..."
    end
    term.write(" " .. searchDisplay .. string.rep(" ", 32 - #searchDisplay))
    
    -- Search button
    term.setBackgroundColor(colors.cyan)
    term.setTextColor(colors.black)
    term.setCursorPos(36, 7)
    term.write(" 🔍 Search ")
    
    -- Search results (like YouTube player)
    if state.search_results then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.yellow)
        term.setCursorPos(3, 9)
        term.write("Search Results:")
        
        local startY = 10
        local maxResults = math.min(5, #state.search_results)
        
        for i = 1, maxResults do
            local result = state.search_results[i]
            local y = startY + (i - 1)
            
            -- Beautiful result styling
            term.setBackgroundColor(colors.lightBlue)
            term.setTextColor(colors.black)
            term.setCursorPos(3, y)
            
            if result.type == "playlist" then
                -- Playlist display (like YouTube player)
                local playlistName = result.name
                if #playlistName > 20 then
                    playlistName = playlistName:sub(1, 17) .. "..."
                end
                
                local songCount = #result.playlist_items .. " songs"
                term.write(" 📋 " .. playlistName .. " [Playlist] (" .. songCount .. ")" .. string.rep(" ", 45 - #playlistName - #songCount - 15))
            else
                -- Individual song display
                local songName = result.name
                if #songName > 25 then
                    songName = songName:sub(1, 22) .. "..."
                end
                
                local artistName = result.artist or "Unknown Artist"
                if #artistName > 15 then
                    artistName = artistName:sub(1, 12) .. "..."
                end
                
                term.write(" ♪ " .. songName .. " - " .. artistName .. string.rep(" ", 45 - #songName - #artistName))
            end
        end
    elseif state.search_error then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.red)
        term.setCursorPos(3, 9)
        term.write("Search Error: Unable to search for songs")
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, 10)
        term.write("Check your internet connection and try again")
    end
    
    -- Current playlist display
    local playlistStartY = state.search_results and 16 or 9
    
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, playlistStartY)
    term.write("Current Playlist (" .. #state.playlist .. " songs):")
    
    if #state.playlist > 0 then
        local maxPlaylistShow = math.min(5, #state.playlist)
        
        for i = 1, maxPlaylistShow do
            local song = state.playlist[i]
            local y = playlistStartY + 1 + (i - 1)
            
            -- Highlight current song
            if i == state.current_song_index then
                term.setBackgroundColor(colors.lime)
                term.setTextColor(colors.black)
            else
                term.setBackgroundColor(colors.gray)
                term.setTextColor(colors.white)
            end
            
            term.setCursorPos(3, y)
            
            local songName = song.name
            if #songName > 25 then
                songName = songName:sub(1, 22) .. "..."
            end
            
            local artistName = song.artist or "Unknown Artist"
            if #artistName > 15 then
                artistName = artistName:sub(1, 12) .. "..."
            end
            
            local prefix = (i == state.current_song_index) and "▶ " or "  "
            term.write(prefix .. songName .. " - " .. artistName .. string.rep(" ", 43 - #songName - #artistName))
        end
        
        if #state.playlist > 5 then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(3, playlistStartY + 7)
            term.write("... and " .. (#state.playlist - 5) .. " more songs")
        end
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, playlistStartY + 1)
        term.write("No songs in playlist")
        term.setCursorPos(3, playlistStartY + 2)
        term.write("Search and add songs to get started!")
    end
    
    -- Playlist control buttons
    local buttonY = state.height - 3
    
    if #state.playlist > 0 then
        -- Clear playlist button
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.setCursorPos(3, buttonY)
        term.write(" 🗑️ Clear Playlist ")
        
        -- Shuffle playlist button
        term.setBackgroundColor(colors.purple)
        term.setTextColor(colors.white)
        term.setCursorPos(22, buttonY)
        term.write(" 🔀 Shuffle ")
    end
end

function radioHost.drawControls(state)
    local theme = themes.getCurrent()
    local buttonY = state.height - 7
    
    -- Broadcasting controls
    if state.is_broadcasting then
        components.drawButton(3, buttonY, "Stop Broadcast", true, true)
    else
        local canStart = #state.playlist > 0
        components.drawButton(3, buttonY, "Start Broadcast", false, canStart)
    end
    
    -- Playlist controls
    components.drawButton(20, buttonY, "Add Song", false, true)
    components.drawButton(32, buttonY, "Remove Song", false, #state.playlist > 0)
    
    -- Playback controls
    local playbackY = buttonY + 2
    if state.playing then
        components.drawButton(3, playbackY, "Pause", false, true)
    else
        components.drawButton(3, playbackY, "Play", false, #state.playlist > 0)
    end
    
    components.drawButton(12, playbackY, "Next", false, #state.playlist > 0)
    
    -- Back to menu
    components.drawButton(25, playbackY, "Back to Menu", false, true)
end

function radioHost.handleInput(state)
    while true do
        local event, param1, param2, param3 = os.pullEvent()
        
        -- Handle radio messages
        if event == "rednet_message" then
            radioHost.handleRadioMessage(state, param1, param2, param3)
        elseif event == "key" then
            local key = param1
            
            if key == keys.escape then
                return "back_to_menu"
            elseif key == keys.space then
                return "play_pause"
            elseif key == keys.n then
                return "next_song"
            elseif key == keys.a then
                return "add_song"
            elseif key == keys.r and #state.playlist > 0 then
                return "remove_song"
            elseif key == keys.b then
                if state.is_broadcasting then
                    return "stop_broadcast"
                else
                    return "start_broadcast"
                end
            end
            
        elseif event == "mouse_click" or event == "monitor_touch" then
            local button, x, y
            if event == "mouse_click" then
                button, x, y = param1, param2, param3
            else -- monitor_touch
                -- monitor_touch returns: event, side, x, y (no button parameter)
                -- param1 = side, param2 = x, param3 = y
                button, x, y = 1, param2, param3  -- Treat monitor touch as left click
            end
            
            return radioHost.handleClick(state, x, y)
        end
    end
end

function radioHost.handleClick(state, x, y)
    local buttonY = state.height - 7
    local playbackY = buttonY + 2
    
    -- Broadcasting controls
    if y == buttonY then
        if x >= 3 and x <= 18 then
            if state.is_broadcasting then
                return "stop_broadcast"
            else
                return "start_broadcast"
            end
        elseif x >= 20 and x <= 30 then
            return "add_song"
        elseif x >= 32 and x <= 45 then
            return "remove_song"
        end
    end
    
    -- Playback controls
    if y == playbackY then
        if x >= 3 and x <= 10 then
            return "play_pause"
        elseif x >= 12 and x <= 18 then
            return "next_song"
        elseif x >= 25 then
            return "back_to_menu"
        end
    end
    
    return nil
end

function radioHost.startBroadcast(state)
    if #state.playlist == 0 then
        state.logger.warn("RadioHost", "Cannot start broadcast - no songs in playlist")
        return
    end
    
    state.is_broadcasting = true
    state.listeners = {}
    
    -- Start playing first song if not already playing
    if not state.now_playing then
        state.current_song_index = 1
        state.now_playing = state.playlist[1]
        state.playing = true
        state.needs_next_chunk = 1
        state.decoder = require("cc.audio.dfpwm").make_decoder()
        state.logger.info("RadioHost", "Starting playback of first song: " .. state.now_playing.name)
    end
    
    -- Open modem channels for broadcasting and receiving join requests
    radioProtocol.openBroadcastChannel()
    
    -- Open station channel to receive join requests
    local stationId = os.getComputerID()
    local stationChannel = radioProtocol.getStationChannel(stationId)
    radioProtocol.openChannel(stationChannel)
    
    state.logger.info("RadioHost", "Opened broadcast channel and station channel " .. stationChannel .. " for station ID " .. stationId)
    
    -- Announce station
    radioHost.announceStation(state)
    
    state.logger.info("RadioHost", "Started broadcasting: " .. state.station_name .. " on channel " .. stationChannel)
end

function radioHost.stopBroadcast(state)
    state.is_broadcasting = false
    
    -- Notify listeners that broadcast is ending
    radioHost.broadcastMessage(state, {
        type = "broadcast_end",
        station_id = os.getComputerID(),
        message = "Broadcast ended"
    })
    
    state.listeners = {}
    
    state.logger.info("RadioHost", "Stopped broadcasting")
end

function radioHost.announceStation(state)
    local announcement = {
        type = "station_announcement",
        station_id = os.getComputerID(),
        station_name = state.station_name,
        station_description = state.station_description,
        listener_count = #state.listeners,
        max_listeners = state.max_listeners,
        now_playing = state.now_playing,
        timestamp = os.epoch("utc")
    }
    
    radioProtocol.broadcast(announcement)
    state.logger.info("RadioHost", "Announced station to network")
end

function radioHost.broadcastMessage(state, message)
    if not state.is_broadcasting then
        return
    end
    
    for _, listenerId in ipairs(state.listeners) do
        radioProtocol.sendToComputer(listenerId, message)
    end
end

function radioHost.broadcastPlaylistUpdate(state)
    local message = {
        type = "playlist_update",
        station_id = os.getComputerID(),
        playlist = state.playlist,
        current_song_index = state.current_song_index,
        timestamp = os.epoch("utc")
    }
    
    radioHost.broadcastMessage(state, message)
end

function radioHost.broadcastSongChange(state)
    local message = {
        type = "song_change",
        station_id = os.getComputerID(),
        now_playing = state.now_playing,
        current_song_index = state.current_song_index,
        playing = state.playing,
        timestamp = os.epoch("utc")
    }
    
    radioHost.broadcastMessage(state, message)
end

function radioHost.broadcastPlaybackState(state)
    local message = {
        type = "playback_state",
        station_id = os.getComputerID(),
        playing = state.playing,
        now_playing = state.now_playing,
        timestamp = os.epoch("utc")
    }
    
    radioHost.broadcastMessage(state, message)
end

function radioHost.broadcastAudioChunk(state, audioBuffer)
    local message = {
        type = "audio_chunk",
        station_id = os.getComputerID(),
        audio_data = audioBuffer,
        playback_session = state.current_playback_session,
        timestamp = os.epoch("utc")
    }
    
    radioHost.broadcastMessage(state, message)
end

-- NEW: Broadcast detailed sync status to keep clients synchronized
function radioHost.broadcastSyncStatus(state)
    local currentTime = os.epoch("utc") / 1000
    
    -- Update current song position if playing
    if state.playing and state.song_start_time > 0 then
        state.current_song_position = currentTime - state.song_start_time
    end
    
    local syncMessage = {
        type = "sync_status",
        station_id = os.getComputerID(),
        
        -- Current playback state
        playing = state.playing,
        now_playing = state.now_playing,
        current_song_index = state.current_song_index,
        
        -- Synchronization data
        playback_session = state.current_playback_session,
        playback_start_time = state.playback_start_time,
        server_time = currentTime,
        
        -- Song position data for timeline display
        song_start_time = state.song_start_time,
        song_duration = state.song_duration,
        current_song_position = state.current_song_position,
        
        -- Playlist info
        playlist_size = #state.playlist,
        looping = state.looping,
        
        -- Station info
        listener_count = #state.listeners,
        
        timestamp = os.epoch("utc")
    }
    
    radioHost.broadcastMessage(state, syncMessage)
    state.logger.info("RadioHost", "Sync status broadcast to " .. #state.listeners .. " listeners")
end

function radioHost.handleNetworkMessage(state, message, replyChannel)
    -- Extract data from protocol message
    local data = radioProtocol.extractMessageData(message)
    if not data then
        return
    end
    
    if data.type == "discovery_request" then
        radioHost.handleDiscoveryRequest(state, data, replyChannel)
    elseif data.type == "join_request" then
        radioHost.handleJoinRequest(state, data, replyChannel)
    elseif data.type == "leave_request" then
        radioHost.handleLeaveRequest(state, data)
    elseif data.type == "listener_ping" then
        radioHost.handleListenerPing(state, data, replyChannel)
    end
end

function radioHost.handleDiscoveryRequest(state, data, replyChannel)
    state.logger.info("RadioHost", "Processing discovery request from client " .. (data.client_id or "unknown"))
    
    if not state.is_broadcasting then
        state.logger.info("RadioHost", "Not broadcasting - not responding to discovery request")
        return -- Don't respond if not broadcasting
    end
    
    -- Send station announcement
    local announcement = {
        type = "station_announcement",
        station_id = os.getComputerID(),
        station_name = state.station_name,
        station_description = state.station_description,
        listener_count = #state.listeners,
        max_listeners = state.max_listeners,
        now_playing = state.now_playing,
        timestamp = os.epoch("utc")
    }
    
    state.logger.info("RadioHost", "Sending station announcement: " .. state.station_name)
    radioProtocol.broadcast(announcement)
    state.logger.info("RadioHost", "Responded to discovery request from Computer-" .. (data.client_id or "unknown"))
end

function radioHost.handleJoinRequest(state, data, replyChannel)
    local listenerId = data.listener_id
    
    state.logger.info("RadioHost", "Processing join request from Computer-" .. listenerId .. " on reply channel " .. replyChannel)
    state.logger.info("RadioHost", "Current broadcasting status: " .. tostring(state.is_broadcasting))
    state.logger.info("RadioHost", "Current listeners: " .. #state.listeners .. "/" .. state.max_listeners)
    
    if not state.is_broadcasting then
        -- Not broadcasting - reject the request
        local response = {
            type = "join_response",
            success = false,
            reason = "Station not broadcasting"
        }
        state.logger.info("RadioHost", "Rejecting join request - not broadcasting")
        radioProtocol.sendToChannel(replyChannel, response)
        return
    end
    
    if #state.listeners >= state.max_listeners then
        -- Station full
        local response = {
            type = "join_response",
            success = false,
            reason = "Station full",
            max_listeners = state.max_listeners
        }
        state.logger.info("RadioHost", "Rejecting join request - station full (" .. #state.listeners .. "/" .. state.max_listeners .. ")")
        radioProtocol.sendToChannel(replyChannel, response)
        return
    end
    
    -- Check if already connected
    for _, id in ipairs(state.listeners) do
        if id == listenerId then
            -- Already connected, send current state
            local response = {
                type = "join_response",
                success = true,
                station_name = state.station_name,
                station_description = state.station_description,
                now_playing = state.now_playing,
                playing = state.playing,
                playlist = state.playlist,
                current_song_index = state.current_song_index
            }
            state.logger.info("RadioHost", "Client already connected - sending current state")
            radioProtocol.sendToChannel(replyChannel, response)
            return
        end
    end
    
    -- Add listener
    table.insert(state.listeners, listenerId)
    
    -- Send welcome response with current state
    local response = {
        type = "join_response",
        success = true,
        station_name = state.station_name,
        station_description = state.station_description,
        now_playing = state.now_playing,
        playing = state.playing,
        playlist = state.playlist,
        current_song_index = state.current_song_index
    }
    
    state.logger.info("RadioHost", "Sending join response to Computer-" .. listenerId .. " on channel " .. replyChannel)
    local success = radioProtocol.sendToChannel(replyChannel, response)
    state.logger.info("RadioHost", "Join response sent successfully: " .. tostring(success))
    
    state.logger.info("RadioHost", "Listener joined: Computer-" .. listenerId .. " (" .. #state.listeners .. "/" .. state.max_listeners .. ")")
end

function radioHost.handleLeaveRequest(state, data)
    local listenerId = data.listener_id
    
    -- Remove listener
    for i, id in ipairs(state.listeners) do
        if id == listenerId then
            table.remove(state.listeners, i)
            break
        end
    end
    
    state.logger.info("RadioHost", "Listener left: Computer-" .. listenerId .. " (" .. #state.listeners .. "/" .. state.max_listeners .. ")")
end

function radioHost.handleListenerPing(state, data, replyChannel)
    -- Respond to keep-alive ping
    local response = {
        type = "ping_response",
        station_id = os.getComputerID(),
        timestamp = os.epoch("utc")
    }
    
    radioProtocol.sendToChannel(replyChannel, response)
end

function radioHost.showStationSettings(state)
    state.waiting_for_input = true
    
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Beautiful header
    term.setBackgroundColor(colors.blue)
    term.setCursorPos(1, 1)
    term.clearLine()
    local title = "Station Settings"
    local fullHeader = "⚙️ " .. title .. " ⚙️"
    local headerX = math.floor((state.width - #fullHeader) / 2) + 1
    term.setCursorPos(headerX, 1)
    term.setTextColor(colors.yellow)
    term.write("⚙️ ")
    term.setTextColor(colors.white)
    term.write(title)
    term.setTextColor(colors.yellow)
    term.write(" ⚙️")
    
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 4)
    term.write("Station Configuration:")
    
    -- Current settings
    term.setTextColor(colors.white)
    term.setCursorPos(3, 6)
    term.write("Current Name: " .. state.station_name)
    term.setCursorPos(3, 7)
    term.write("Current Description: " .. state.station_description)
    term.setCursorPos(3, 8)
    term.write("Max Listeners: " .. state.max_listeners)
    
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 10)
    term.write("Update Station Name:")
    term.setTextColor(colors.white)
    term.setCursorPos(3, 11)
    local newName = read()
    
    if newName and newName ~= "" then
        state.station_name = newName
    end
    
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 13)
    term.write("Update Description:")
    term.setTextColor(colors.white)
    term.setCursorPos(3, 14)
    local newDesc = read()
    
    if newDesc and newDesc ~= "" then
        state.station_description = newDesc
    end
    
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 16)
    term.write("Max Listeners (1-50):")
    term.setTextColor(colors.white)
    term.setCursorPos(3, 17)
    local maxStr = read()
    
    if maxStr and maxStr ~= "" then
        local maxNum = tonumber(maxStr)
        if maxNum and maxNum >= 1 and maxNum <= 50 then
            state.max_listeners = maxNum
        end
    end
    
    term.setTextColor(colors.lime)
    term.setCursorPos(3, 19)
    term.write("Settings updated successfully!")
    term.setTextColor(colors.lightGray)
    term.setCursorPos(3, 20)
    term.write("Press any key to continue...")
    
    os.pullEvent("key")
    state.waiting_for_input = false
    
    state.logger.info("RadioHost", "Station settings updated")
end

function radioHost.cleanup(state)
    -- Stop broadcasting
    if state.is_broadcasting then
        radioHost.stopBroadcast(state)
    end
    
    -- Stop audio playback
    if state.player_handle then
        state.player_handle.close()
        state.player_handle = nil
    end
    
    -- Close radio protocol
    if state.protocol_available then
        radioProtocol.cleanup()
    end
    
    state.logger.info("RadioHost", "Radio host cleaned up")
end

-- BEAUTIFUL UI REDRAW (like YouTube player with main menu design)
function radioHost.redrawScreen(state)
    if state.waiting_for_input then
        return
    end

    term.setCursorBlink(false)
    state.width, state.height = term.getSize()
        
    -- CRITICAL: Check for action menu FIRST (for song search results)
    if state.in_search_result == true then
        -- Draw action menu with beautiful main menu design
        term.setBackgroundColor(colors.black)
        term.clear()
        
        -- Beautiful header for action menu
        term.setBackgroundColor(colors.blue)
        term.setCursorPos(1, 1)
        term.clearLine()
        local title = "Bognesferga Radio Host"
        local fullHeader = "🎙️ " .. title .. " 🎙️"
        local headerX = math.floor((state.width - #fullHeader) / 2) + 1
        term.setCursorPos(headerX, 1)
        term.setTextColor(colors.yellow)
        term.write("🎙️ ")
        term.setTextColor(colors.white)
        term.write(title)
        term.setTextColor(colors.yellow)
        term.write(" 🎙️")
        
        -- Song info with yellow accent
        if state.search_results and state.clicked_result then
            local selectedResult = state.search_results[state.clicked_result]
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.yellow)
            term.setCursorPos(2, 3)
            
            if selectedResult.type == "playlist" then
                term.write("Add Playlist to Radio:")
                term.setTextColor(colors.white)
                term.setCursorPos(2, 4)
                term.write("📋 " .. selectedResult.name)
                term.setTextColor(colors.lightGray)
                term.setCursorPos(2, 5)
                term.write("  " .. #selectedResult.playlist_items .. " songs")
            else
                term.write("Add Song to Radio:")
                term.setTextColor(colors.white)
                term.setCursorPos(2, 4)
                term.write("♪ " .. selectedResult.name)
                term.setTextColor(colors.lightGray)
                term.setCursorPos(2, 5)
                term.write("  " .. selectedResult.artist)
            end
        end

        -- Beautiful action buttons with contrasting colors
        term.setCursorPos(2, 7)
        term.setBackgroundColor(colors.lime)
        term.setTextColor(colors.black)
        term.write(" + Add to Playlist ")

        term.setCursorPos(2, 9)
        term.setBackgroundColor(colors.cyan)
        term.setTextColor(colors.black)
        term.write(" ⏭ Add & Play Next ")

        term.setCursorPos(2, 11)
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write(" ✗ Cancel ")
        
        -- Beautiful rainbow footer for action menu
        term.setBackgroundColor(colors.gray)
        term.setCursorPos(1, state.height)
        term.clearLine()
        local devText = "Developed by Forty"
        local footerX = math.floor((state.width - #devText) / 2) + 1
        term.setCursorPos(footerX, state.height)
        local rainbow_colors = {colors.red, colors.orange, colors.yellow, colors.lime, colors.cyan, colors.lightBlue, colors.purple, colors.magenta}
        for i = 1, #devText do
            local colorIndex = ((i - 1) % #rainbow_colors) + 1
            term.setTextColor(rainbow_colors[colorIndex])
            term.write(devText:sub(i, i))
        end
        
        return -- Don't draw anything else
    end
    
    -- Clear screen
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Beautiful main menu style header
    term.setBackgroundColor(colors.blue)
    term.setCursorPos(1, 1)
    term.clearLine()
    local title = "Bognesferga Radio Host"
    local fullHeader = "🎙️ " .. title .. " 🎙️"
    local headerX = math.floor((state.width - #fullHeader) / 2) + 1
    term.setCursorPos(headerX, 1)
    term.setTextColor(colors.yellow)
    term.write("🎙️ ")
    term.setTextColor(colors.white)
    term.write(title)
    term.setTextColor(colors.yellow)
    term.write(" 🎙️")

    -- Beautiful modern tabs with main menu styling
    local tabs = {" Station Info ", " Playlist ", " Now Playing "}
    term.setCursorPos(1, 2)
    term.setBackgroundColor(colors.blue)
    term.clearLine()
    
    for i = 1, #tabs do
        if state.tab == i then
            term.setTextColor(colors.black)
            term.setBackgroundColor(colors.white)
        else
            term.setTextColor(colors.white)
            term.setBackgroundColor(colors.lightGray)
        end
        
        local tabX = math.floor((state.width / #tabs) * (i - 0.5)) - math.ceil(#tabs[i] / 2) + 1
        term.setCursorPos(tabX, 2)
        term.write(tabs[i])
    end

    -- Draw content based on tab
    if state.tab == 1 then
        radioHost.drawStationInfo(state)
    elseif state.tab == 2 then
        radioHost.drawPlaylist(state)
    elseif state.tab == 3 then
        radioHost.drawNowPlaying(state)
    end
    
    -- Beautiful rainbow footer (main menu style)
    term.setBackgroundColor(colors.gray)
    term.setCursorPos(1, state.height - 1)
    term.clearLine()
    term.setCursorPos(1, state.height)
    term.clearLine()
    
    -- Back to menu button with yellow accent
    term.setBackgroundColor(colors.yellow)
    term.setTextColor(colors.black)
    term.setCursorPos(2, state.height - 1)
    term.write(" ← Back to Menu ")
    
    -- Rainbow "Developed by Forty" footer
    term.setBackgroundColor(colors.gray)
    local devText = "Developed by Forty"
    local footerX = math.floor((state.width - #devText) / 2) + 1
    term.setCursorPos(footerX, state.height)
    local rainbow_colors = {colors.red, colors.orange, colors.yellow, colors.lime, colors.cyan, colors.lightBlue, colors.purple, colors.magenta}
    for i = 1, #devText do
        local colorIndex = ((i - 1) % #rainbow_colors) + 1
        term.setTextColor(rainbow_colors[colorIndex])
        term.write(devText:sub(i, i))
    end
end

function radioHost.drawStationInfo(state)
    -- Station info with yellow accent (like main menu)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 4)
    term.write("Station Information:")
    
    -- Station details with beautiful styling
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(3, 6)
    term.write("🎙️ " .. state.station_name)
    term.setTextColor(colors.lightGray)
    term.setCursorPos(3, 7)
    term.write("   " .. state.station_description)
    
    -- Broadcasting status with beautiful colors
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 9)
    term.write("Broadcasting Status:")
    
    if state.is_broadcasting then
        term.setTextColor(colors.lime)
        term.setCursorPos(3, 10)
        term.write("🔴 LIVE - Broadcasting to " .. #state.listeners .. " listeners")
        
        if #state.listeners > 0 then
            term.setTextColor(colors.cyan)
            term.setCursorPos(3, 11)
            term.write("👥 Connected Listeners: " .. #state.listeners .. "/" .. state.max_listeners)
        end
    else
        term.setTextColor(colors.red)
        term.setCursorPos(3, 10)
        term.write("⚫ OFFLINE - Not broadcasting")
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, 11)
        term.write("   Add songs to playlist and start broadcasting")
    end
    
    -- Playlist summary
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 13)
    term.write("Playlist Summary:")
    
    if #state.playlist > 0 then
        term.setTextColor(colors.white)
        term.setCursorPos(3, 14)
        term.write("♪ " .. #state.playlist .. " songs in playlist")
        
        if state.now_playing then
            term.setTextColor(colors.lime)
            term.setCursorPos(3, 15)
            term.write("▶ Now Playing: " .. state.now_playing.name)
        end
    else
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, 14)
        term.write("♪ No songs in playlist")
        term.setCursorPos(3, 15)
        term.write("   Go to Playlist tab to add songs")
    end
    
    -- Control buttons with beautiful styling
    local buttonY = 17
    
    -- Broadcast button
    if state.is_broadcasting then
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.setCursorPos(3, buttonY)
        term.write(" 🔴 Stop Broadcast ")
    else
        if #state.playlist > 0 then
            term.setBackgroundColor(colors.lime)
            term.setTextColor(colors.black)
        else
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.lightGray)
        end
        term.setCursorPos(3, buttonY)
        term.write(" 📡 Start Broadcast ")
    end
    
    -- Station settings button
    term.setBackgroundColor(colors.cyan)
    term.setTextColor(colors.black)
    term.setCursorPos(22, buttonY)
    term.write(" ⚙️ Settings ")
end

function radioHost.drawNowPlaying(state)
    -- Now playing header with yellow accent
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 4)
    term.write("Now Playing & Broadcast Controls:")
    
    -- Current song info
    if state.now_playing then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.setCursorPos(3, 6)
        term.write("♪ " .. state.now_playing.name)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, 7)
        term.write("  " .. (state.now_playing.artist or "Unknown Artist"))
        
        -- Playback status
        if state.playing then
            term.setTextColor(colors.lime)
            term.setCursorPos(3, 8)
            term.write("▶ Playing")
        else
            term.setTextColor(colors.yellow)
            term.setCursorPos(3, 8)
            term.write("⏸ Paused")
        end
        
        -- Song time/position display
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.yellow)
        term.setCursorPos(3, 9)
        term.write("Song Position:")
        
        -- Update current position if playing
        if state.playing and state.song_start_time > 0 then
            local currentTime = os.epoch("utc") / 1000
            state.current_song_position = currentTime - state.song_start_time
        end
        
        -- Format time as MM:SS
        local function formatTime(seconds)
            local mins = math.floor(seconds / 60)
            local secs = math.floor(seconds % 60)
            return string.format("%d:%02d", mins, secs)
        end
        
        term.setTextColor(colors.white)
        term.setCursorPos(3, 10)
        if state.song_duration > 0 then
            term.write(formatTime(state.current_song_position) .. " / " .. formatTime(state.song_duration))
        else
            term.write(formatTime(state.current_song_position) .. " / --:--")
        end
        
        -- Progress bar
        if state.song_duration > 0 then
            term.setCursorPos(3, 11)
            local progressWidth = 30
            local progress = math.min(1.0, state.current_song_position / state.song_duration)
            local fillWidth = math.floor(progress * progressWidth)
            
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.white)
            term.write("[")
            
            for i = 1, progressWidth do
                if i <= fillWidth then
                    term.setBackgroundColor(colors.lime)
                    term.write(" ")
                else
                    term.setBackgroundColor(colors.gray)
                    term.write(" ")
                end
            end
            
            term.setBackgroundColor(colors.gray)
            term.write("]")
            
            -- Show percentage
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.lightGray)
            term.write(" " .. math.floor(progress * 100) .. "%")
        end
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, 6)
        term.write("♪ No song playing")
        term.setCursorPos(3, 7)
        term.write("  Add songs to playlist and start broadcast")
    end
    
    -- Volume control (like YouTube player) - moved down to accommodate song position
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 13)
    if state.muted then
        term.write("Volume: MUTED")
    else
        local volumePercent = math.floor((state.volume / 3.0) * 100)
        term.write("Volume: " .. volumePercent .. "%")
    end
    
    -- Volume slider
    term.setCursorPos(3, 14)
    local sliderWidth = 20
    local fillWidth = state.muted and 0 or math.floor((state.volume / 3.0) * sliderWidth)
    
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.write("[")
    
    for i = 1, sliderWidth do
        if i <= fillWidth then
            term.setBackgroundColor(state.muted and colors.red or colors.cyan)
            term.write(" ")
        else
            term.setBackgroundColor(colors.gray)
            term.write(" ")
        end
    end
    
    term.setBackgroundColor(colors.gray)
    term.write("]")
    
    -- Mute/Unmute button
    term.setCursorPos(25, 14)
    if state.muted then
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write(" 🔇 Unmute ")
    else
        term.setBackgroundColor(colors.orange)
        term.setTextColor(colors.black)
        term.write(" 🔊 Mute ")
    end
    
    -- Playback controls with beautiful styling - moved down
    local controlY = 16
    
    if state.now_playing then
        -- Play/Pause button
        if state.playing then
            term.setBackgroundColor(colors.yellow)
            term.setTextColor(colors.black)
            term.setCursorPos(3, controlY)
            term.write(" ⏸ Pause ")
        else
            term.setBackgroundColor(colors.lime)
            term.setTextColor(colors.black)
            term.setCursorPos(3, controlY)
            term.write(" ▶ Play ")
        end
        
        -- Next song button
        term.setBackgroundColor(colors.cyan)
        term.setTextColor(colors.black)
        term.setCursorPos(14, controlY)
        term.write(" ⏭ Next ")
        
        -- Previous song button
        term.setBackgroundColor(colors.lightBlue)
        term.setTextColor(colors.black)
        term.setCursorPos(24, controlY)
        term.write(" ⏮ Prev ")
    end
    
    -- Loop mode control - moved down
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 18)
    term.write("Loop Mode: ")
    
    local loopModes = {"Off", "Playlist", "Song"}
    local loopColors = {colors.gray, colors.cyan, colors.lime}
    
    for i = 1, #loopModes do
        if state.looping == (i - 1) then
            term.setBackgroundColor(loopColors[i])
            term.setTextColor(colors.black)
        else
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.lightGray)
        end
        
        term.setCursorPos(3 + (i - 1) * 10, 19)
        term.write(" " .. loopModes[i] .. " ")
    end
    
    -- Broadcasting info - moved down
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 21)
    term.write("Broadcasting Status:")
    
    if state.is_broadcasting then
        term.setTextColor(colors.lime)
        term.setCursorPos(3, 22)
        term.write("🔴 LIVE to " .. #state.listeners .. " listeners")
        
        -- Listener list
        if #state.listeners > 0 then
            term.setTextColor(colors.cyan)
            term.setCursorPos(3, 23)
            term.write("👥 Listeners: ")
            
            local listenerText = ""
            for i, listener in ipairs(state.listeners) do
                if i > 1 then listenerText = listenerText .. ", " end
                listenerText = listenerText .. "Computer-" .. listener
                if #listenerText > 30 then
                    listenerText = listenerText .. "..."
                    break
                end
            end
            
            term.write(listenerText)
        end
    else
        term.setTextColor(colors.red)
        term.setCursorPos(3, 22)
        term.write("⚫ Not broadcasting")
    end
end

-- MAIN UI LOOP (like YouTube player)
function radioHost.uiLoop(state, speakers)
    while true do
        radioHost.redrawScreen(state)
        
        local event, p1, p2, p3 = os.pullEvent()
        
        -- Handle both mouse_click and monitor_touch events (universal compatibility)
        if event == "mouse_click" or event == "monitor_touch" then
            local button, x, y
            
            if event == "mouse_click" then
                button, x, y = p1, p2, p3
            else -- monitor_touch
                -- For monitor_touch: p1=side, p2=x, p3=y (no button)
                button, x, y = 1, p2, p3 -- Assume left click for monitor touch
            end
            
            state.logger.info("RadioHost", "Click detected at " .. x .. "," .. y .. " (event: " .. event .. ")")
            
            -- Handle action menu clicks FIRST (critical for search results)
            if state.in_search_result == true then
                state.logger.info("RadioHost", "Processing action menu click")
                
                if y == 7 then -- Add to Playlist
                    state.logger.info("RadioHost", "Add to playlist clicked")
                    if state.search_results and state.clicked_result then
                        local selectedResult = state.search_results[state.clicked_result]
                        
                        -- Handle playlist vs individual song (like YouTube player)
                        if selectedResult.type == "playlist" then
                            -- Add all songs from playlist
                            for i = 1, #selectedResult.playlist_items do
                                table.insert(state.playlist, selectedResult.playlist_items[i])
                            end
                            state.logger.info("RadioHost", "Added playlist to radio playlist: " .. #selectedResult.playlist_items .. " songs")
                            
                            -- Auto-start playing first song if broadcasting and no song is playing
                            if state.is_broadcasting and not state.now_playing and #selectedResult.playlist_items > 0 then
                                state.current_song_index = #state.playlist - #selectedResult.playlist_items + 1
                                state.now_playing = selectedResult.playlist_items[1]
                                state.playing = true
                                state.needs_next_chunk = 1
                                state.decoder = require("cc.audio.dfpwm").make_decoder()
                                state.logger.info("RadioHost", "Auto-started playing first song from playlist: " .. selectedResult.playlist_items[1].name)
                                
                                -- Broadcast song change to listeners
                                radioHost.broadcastSongChange(state)
                                os.queueEvent("audio_update")
                            end
                        else
                            -- Add individual song
                            table.insert(state.playlist, selectedResult)
                            state.logger.info("RadioHost", "Added song to playlist: " .. selectedResult.name)
                            
                            -- Auto-start playing if broadcasting and no song is playing
                            if state.is_broadcasting and not state.now_playing then
                                state.current_song_index = #state.playlist
                                state.now_playing = selectedResult
                                state.playing = true
                                state.needs_next_chunk = 1
                                state.decoder = require("cc.audio.dfpwm").make_decoder()
                                state.logger.info("RadioHost", "Auto-started playing: " .. selectedResult.name)
                                
                                -- Broadcast song change to listeners
                                radioHost.broadcastSongChange(state)
                                os.queueEvent("audio_update")
                            end
                        end
                        
                        -- Broadcast playlist update to listeners
                        if state.is_broadcasting then
                            radioHost.broadcastPlaylistUpdate(state)
                        end
                    end
                    state.in_search_result = false
                    state.clicked_result = nil
                    
                elseif y == 9 then -- Add & Play Next
                    state.logger.info("RadioHost", "Add & play next clicked")
                    if state.search_results and state.clicked_result then
                        local selectedResult = state.search_results[state.clicked_result]
                        
                        -- Handle playlist vs individual song (like YouTube player)
                        if selectedResult.type == "playlist" then
                            -- Add all songs from playlist after current song
                            if state.now_playing then
                                local insertPos = state.current_song_index + 1
                                for i = #selectedResult.playlist_items, 1, -1 do
                                    table.insert(state.playlist, insertPos, selectedResult.playlist_items[i])
                                end
                                state.logger.info("RadioHost", "Added playlist to play next: " .. #selectedResult.playlist_items .. " songs")
                            else
                                -- No song playing, add and start playing first song
                                for i = 1, #selectedResult.playlist_items do
                                    table.insert(state.playlist, selectedResult.playlist_items[i])
                                end
                                state.current_song_index = 1
                                state.now_playing = selectedResult.playlist_items[1]
                                state.playing = true
                                state.needs_next_chunk = 1
                                state.decoder = require("cc.audio.dfpwm").make_decoder()
                                state.logger.info("RadioHost", "Added playlist and started playing: " .. selectedResult.playlist_items[1].name)
                                
                                -- Broadcast song change to listeners
                                if state.is_broadcasting then
                                    radioHost.broadcastSongChange(state)
                                end
                                os.queueEvent("audio_update")
                            end
                        else
                            -- Add individual song
                            if state.now_playing then
                                -- Insert after current song
                                local insertPos = state.current_song_index + 1
                                table.insert(state.playlist, insertPos, selectedResult)
                                state.logger.info("RadioHost", "Added song to play next: " .. selectedResult.name)
                            else
                                -- No song playing, add and start playing
                                table.insert(state.playlist, selectedResult)
                                state.current_song_index = #state.playlist
                                state.now_playing = selectedResult
                                state.playing = true
                                state.needs_next_chunk = 1
                                state.decoder = require("cc.audio.dfpwm").make_decoder()
                                state.logger.info("RadioHost", "Added and started playing: " .. selectedResult.name)
                                
                                -- Broadcast song change to listeners
                                if state.is_broadcasting then
                                    radioHost.broadcastSongChange(state)
                                end
                                os.queueEvent("audio_update")
                            end
                        end
                        
                        -- Broadcast playlist update to listeners
                        if state.is_broadcasting then
                            radioHost.broadcastPlaylistUpdate(state)
                        end
                    end
                    state.in_search_result = false
                    state.clicked_result = nil
                    
                elseif y == 11 then -- Cancel
                    state.logger.info("RadioHost", "Cancel clicked")
                    state.in_search_result = false
                    state.clicked_result = nil
                end
                
                -- Continue to next event after handling action menu
                goto continue
            end
            
            -- Back to menu button (footer)
            if y == state.height - 1 and x >= 2 and x <= 16 then
                state.logger.info("RadioHost", "Back to menu clicked")
                return "back_to_menu"
            end
            
            -- Tab switching (header area)
            if y == 2 then
                local tabWidth = math.floor(state.width / 3)
                if x <= tabWidth then
                    state.tab = 1 -- Station Info
                elseif x <= tabWidth * 2 then
                    state.tab = 2 -- Playlist
                else
                    state.tab = 3 -- Now Playing
                end
                state.logger.info("RadioHost", "Switched to tab " .. state.tab)
                goto continue
            end
            
            -- Tab-specific click handling
            if state.tab == 1 then -- Station Info tab
                radioHost.handleStationInfoClicks(state, x, y)
            elseif state.tab == 2 then -- Playlist tab
                radioHost.handlePlaylistClicks(state, x, y)
            elseif state.tab == 3 then -- Now Playing tab
                radioHost.handleNowPlayingClicks(state, x, y, speakers)
            end
        end
        
        ::continue::
    end
end

function radioHost.handleStationInfoClicks(state, x, y)
    -- Broadcast control button
    if y == 17 then
        if x >= 3 and x <= 21 then -- Start/Stop Broadcast button
            if state.is_broadcasting then
                radioHost.stopBroadcast(state)
            else
                if #state.playlist > 0 then
                    radioHost.startBroadcast(state)
                end
            end
        elseif x >= 22 and x <= 34 then -- Settings button
            radioHost.showStationSettings(state)
        end
    end
end

function radioHost.handlePlaylistClicks(state, x, y)
    -- Search box click
    if y == 7 and x >= 3 and x <= 34 then
        radioHost.handleSearchInput(state)
        return
    end
    
    -- Search button click
    if y == 7 and x >= 36 and x <= 46 then
        if state.last_search and state.last_search ~= "" then
            radioHost.performSearch(state)
        end
        return
    end
    
    -- Search results clicks
    if state.search_results and y >= 10 and y <= 14 then
        local resultIndex = y - 9
        if resultIndex >= 1 and resultIndex <= #state.search_results then
            state.logger.info("RadioHost", "CLICKED on search result " .. resultIndex)
            state.clicked_result = resultIndex
            state.in_search_result = true
            return
        end
    end
    
    -- Playlist control buttons
    local buttonY = state.height - 3
    if y == buttonY and #state.playlist > 0 then
        if x >= 3 and x <= 20 then -- Clear Playlist
            radioHost.clearPlaylist(state)
        elseif x >= 22 and x <= 33 then -- Shuffle
            radioHost.shufflePlaylist(state)
        end
    end
end

function radioHost.handleNowPlayingClicks(state, x, y, speakers)
    -- Volume slider click - moved down by 3 lines
    if y == 14 and x >= 4 and x <= 24 and not state.muted then
        local sliderPos = x - 4
        local newVolume = (sliderPos / 20) * 3.0
        state.volume = math.max(0, math.min(3.0, newVolume))
        state.logger.info("RadioHost", "Volume set to " .. state.volume)
        return
    end
    
    -- Mute/Unmute button - moved down by 3 lines
    if y == 14 and x >= 25 and x <= 36 then
        state.muted = not state.muted
        state.logger.info("RadioHost", "Audio " .. (state.muted and "muted" or "unmuted"))
        return
    end
    
    -- Playback control buttons - moved down by 3 lines
    if y == 16 and state.now_playing then
        if x >= 3 and x <= 12 then -- Play/Pause
            radioHost.togglePlayback(state, speakers)
        elseif x >= 14 and x <= 22 then -- Next
            radioHost.nextSong(state, speakers)
        elseif x >= 24 and x <= 32 then -- Previous
            radioHost.previousSong(state, speakers)
        end
    end
    
    -- Loop mode buttons - moved down by 3 lines
    if y == 19 then
        if x >= 3 and x <= 7 then -- Off
            state.looping = 0
        elseif x >= 13 and x <= 21 then -- Playlist
            state.looping = 1
        elseif x >= 23 and x <= 27 then -- Song
            state.looping = 2
        end
        state.logger.info("RadioHost", "Loop mode set to " .. state.looping)
    end
end

function radioHost.handleSearchInput(state)
    state.waiting_for_input = true
    
    -- Clear search area and show input prompt
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 6)
    term.write("Search for songs to add:")
    
    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)
    term.setCursorPos(3, 7)
    term.write(string.rep(" ", 33))
    term.setCursorPos(4, 7)
    
    -- Get user input
    local searchQuery = read()
    
    state.waiting_for_input = false
    
    if searchQuery and searchQuery ~= "" then
        state.last_search = searchQuery
        state.logger.info("RadioHost", "Search query entered: " .. searchQuery)
        radioHost.performSearch(state)
    end
end

-- SEARCH FUNCTIONALITY (like YouTube player)
function radioHost.performSearch(state)
    state.logger.info("RadioHost", "Performing search for: " .. state.last_search)
    
    -- Reset search state
    state.search_results = nil
    state.search_error = false
    state.in_search_result = false
    state.clicked_result = nil
    
    -- Build search URL (same format as YouTube player)
    local searchUrl = state.api_base_url .. "?v=" .. state.version .. "&search=" .. textutils.urlEncode(state.last_search)
    state.last_search_url = searchUrl
    
    state.logger.info("RadioHost", "Search URL: " .. searchUrl)
    state.logger.info("RadioHost", "Making HTTP request to: " .. searchUrl)
    
    -- Make asynchronous HTTP request (like YouTube player)
    http.request(searchUrl)
end

-- AUDIO LOOP (like YouTube player - FIXED)
function radioHost.audioLoop(state, speakers)
    while true do
        -- AUDIO STREAMING (like YouTube player)
        if state.playing and state.now_playing then
            local thisnowplayingid = state.now_playing.id
            if state.playing_id ~= thisnowplayingid then
                state.playing_id = thisnowplayingid
                state.last_download_url = state.api_base_url .. "?v=" .. state.version .. "&id=" .. textutils.urlEncode(state.playing_id)
                state.playing_status = 0
                state.needs_next_chunk = 1

                http.request({url = state.last_download_url, binary = true})
                state.is_loading = true
                state.logger.info("RadioHost", "Requesting audio stream for: " .. state.now_playing.name)

                os.queueEvent("redraw_screen")
                os.queueEvent("audio_update")
            elseif state.playing_status == 1 and state.needs_next_chunk == 1 then

                while true do
                    local chunk = state.player_handle.read(state.size)
                    if not chunk then
                        -- Song finished, move to next
                        state.logger.info("RadioHost", "Song finished, moving to next")
                        radioHost.nextSong(state, speakers)
                        
                        if state.player_handle then
                            state.player_handle.close()
                            state.player_handle = nil
                        end
                        state.needs_next_chunk = 0
                        break
                    else
                        if state.start then
                            chunk, state.start = state.start .. chunk, nil
                            state.size = state.size + 4
                        end
                
                        state.buffer = state.decoder(chunk)
                        
                        -- Play audio on local speakers (FIXED - only if not muted)
                        if not state.muted then
                            local fn = {}
                            for i, speaker in ipairs(speakers) do 
                                fn[i] = function()
                                    local name = peripheral.getName(speaker)
                                    local playVolume = state.muted and 0 or state.volume
                                    if #speakers > 1 then
                                        if speaker.playAudio(state.buffer, playVolume) then
                                            parallel.waitForAny(
                                                function()
                                                    repeat until select(2, os.pullEvent("speaker_audio_empty")) == name
                                                end,
                                                function()
                                                    local event = os.pullEvent("playback_stopped")
                                                    return
                                                end
                                            )
                                            if not state.playing or state.playing_id ~= thisnowplayingid then
                                                return
                                            end
                                        end
                                    else
                                        while not speaker.playAudio(state.buffer, playVolume) do
                                            parallel.waitForAny(
                                                function()
                                                    repeat until select(2, os.pullEvent("speaker_audio_empty")) == name
                                                end,
                                                function()
                                                    local event = os.pullEvent("playback_stopped")
                                                    return
                                                end
                                            )
                                            if not state.playing or state.playing_id ~= thisnowplayingid then
                                                return
                                            end
                                        end
                                    end
                                    if not state.playing or state.playing_id ~= thisnowplayingid then
                                        return
                                    end
                                end
                            end
                            
                            local ok, err = pcall(parallel.waitForAll, table.unpack(fn))
                            if not ok then
                                state.needs_next_chunk = 2
                                state.is_error = true
                                break
                            end
                        else
                            -- Still need to process audio for network streaming even when muted
                            sleep(0.05)
                        end
                        
                        -- Broadcast audio chunk to listeners (ALWAYS - even when host is muted)
                        if state.is_broadcasting then
                            radioHost.broadcastAudioChunk(state, state.buffer)
                        end
                        
                        -- If we're not playing anymore, exit the chunk processing loop
                        if not state.playing or state.playing_id ~= thisnowplayingid then
                            break
                        end
                    end
                end
                os.queueEvent("audio_update")
            end
        end

        os.pullEvent("audio_update")
    end
end

-- HTTP LOOP (like YouTube player - asynchronous)
function radioHost.httpLoop(state)
    while true do
        parallel.waitForAny(
            function()
                local event, url, handle = os.pullEvent("http_success")
                
                if url == state.last_search_url then
                    local success, results = pcall(function()
                        local responseText = handle.readAll()
                        handle.close()
                        if not responseText or responseText == "" then
                            error("Empty response from search API")
                        end
                        return textutils.unserialiseJSON(responseText)
                    end)
                    
                    if success and results then
                        state.search_results = results
                        state.search_error = false
                        state.logger.info("RadioHost", "Search completed: " .. #results .. " results found")
                    else
                        state.search_results = nil
                        state.search_error = true
                        state.logger.error("RadioHost", "Failed to parse search results")
                    end
                    os.queueEvent("redraw_screen")
                end
                
                if url == state.last_download_url then
                    state.is_loading = false
                    state.player_handle = handle
                    state.start = handle.read(4)
                    state.size = 16 * 1024 - 4
                    state.playing_status = 1
                    state.logger.info("RadioHost", "Audio stream ready for: " .. (state.now_playing and state.now_playing.name or "Unknown"))
                    os.queueEvent("redraw_screen")
                    os.queueEvent("audio_update")
                end
            end,
            function()
                local event, url = os.pullEvent("http_failure")
                
                if url == state.last_search_url then
                    state.search_error = true
                    state.search_results = nil
                    state.logger.error("RadioHost", "HTTP request failed")
                    os.queueEvent("redraw_screen")
                end
                
                if url == state.last_download_url then
                    state.is_loading = false
                    state.is_error = true
                    state.playing = false
                    state.playing_id = nil
                    state.logger.error("RadioHost", "Audio stream request failed")
                    os.queueEvent("redraw_screen")
                    os.queueEvent("audio_update")
                end
            end
        )
    end
end

-- NETWORK LOOP (radio broadcasting)
function radioHost.networkLoop(state)
    while true do
        local currentTime = os.epoch("utc") / 1000
        
        -- Announce station periodically
        if state.is_broadcasting and (currentTime - state.last_announce_time) >= state.announce_interval then
            radioHost.announceStation(state)
            state.last_announce_time = currentTime
        end
        
        -- PRE-BUFFER: Send latency pings to all clients
        if state.is_broadcasting and state.sync_enabled and state.latency_tracker then
            latencyManager.sendPingToAll(state.latency_tracker, radioProtocol)
            latencyManager.cleanupTimeoutClients(state.latency_tracker)
            latencyManager.cleanupPendingPings(state.latency_tracker)
        end
        
        -- PRE-BUFFER: Send sync commands based on latency measurements
        if state.is_broadcasting and #state.listeners > 0 and (currentTime - state.last_sync_time) >= state.sync_interval then
            if state.sync_enabled and state.latency_tracker then
                radioHost.sendSyncCommand(state)
            else
                -- Fallback to old sync system
                radioHost.broadcastSyncStatus(state)
            end
            state.last_sync_time = currentTime
        end
        
        -- PRE-BUFFER: Update buffer status
        if state.audio_buffer and state.is_broadcasting then
            local bufferStatus = bufferManager.getBufferStatus(state.audio_buffer)
            if bufferStatus then
                state.buffer_health = bufferStatus.buffer_health
                state.buffer_ready = bufferStatus.buffer_ready
                
                -- Clean up old chunks periodically
                if (currentTime - state.last_buffer_update) >= 30 then -- Every 30 seconds
                    bufferManager.cleanupOldChunks(state.audio_buffer, 60)
                    state.last_buffer_update = currentTime
                end
            end
        end
        
        -- Handle incoming network messages
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        
        if message and type(message) == "table" then
            state.logger.debug("RadioHost", "Received message on channel " .. channel .. " (reply: " .. replyChannel .. ") from distance " .. (distance or "unknown"))
            
            if radioProtocol.isValidMessage(message) then
                local data = radioProtocol.extractMessageData(message)
                if data then
                    state.logger.debug("RadioHost", "Valid message type: " .. (data.type or "unknown") .. " from client " .. (data.client_id or data.listener_id or "unknown"))
                    
                    -- PRE-BUFFER: Handle ping responses
                    if data.type == "ping_response" and state.latency_tracker then
                        local clientId = data.client_id or replyChannel
                        latencyManager.processPingResponse(state.latency_tracker, data, clientId)
                        
                    -- PRE-BUFFER: Handle client buffer ready notifications
                    elseif data.type == "client_buffer_ready" and state.latency_tracker then
                        local clientId = data.client_id
                        latencyManager.addClient(state.latency_tracker, clientId)
                        state.logger.info("RadioHost", string.format("Client %d buffer ready (%.1fs buffered)", 
                            clientId, data.buffer_duration or 0))
                        
                    -- PRE-BUFFER: Handle emergency resync requests
                    elseif data.type == "emergency_resync" then
                        local clientId = data.client_id
                        local reason = data.reason or "Unknown"
                        state.logger.warn("RadioHost", string.format("Emergency resync requested by client %d: %s", 
                            clientId, reason))
                        
                        -- Force immediate sync
                        if state.sync_enabled and state.latency_tracker then
                            radioHost.sendSyncCommand(state, true) -- Force sync
                        end
                        
                    -- Debug join requests specifically
                    elseif data.type == "join_request" then
                        state.logger.info("RadioHost", "JOIN REQUEST received from Computer-" .. (data.listener_id or "unknown") .. " - Broadcasting: " .. tostring(state.is_broadcasting))
                        
                        -- Add client to latency tracker when they join
                        if state.latency_tracker and data.listener_id then
                            latencyManager.addClient(state.latency_tracker, data.listener_id)
                        end
                        
                    -- Handle discovery requests even when not broadcasting (for debugging)
                    elseif data.type == "discovery_request" then
                        state.logger.debug("RadioHost", "Discovery request received - Broadcasting: " .. tostring(state.is_broadcasting))
                    end
                end
                
                radioHost.handleNetworkMessage(state, message, replyChannel)
            else
                state.logger.warn("RadioHost", "Invalid message received on channel " .. channel)
            end
        end
        
        sleep(0.2)
    end
end

-- PLAYBACK CONTROL FUNCTIONS (FIXED with synchronization)
function radioHost.togglePlayback(state, speakers)
    if state.now_playing then
        state.playing = not state.playing
        
        if state.playing and not state.player_handle then
            -- Generate new playback session when starting
            state.current_playback_session = os.getComputerID() .. "_" .. os.epoch("utc")
            state.playback_start_time = os.epoch("utc") / 1000
            -- Reset song position tracking
            state.song_start_time = os.epoch("utc") / 1000
            state.current_song_position = 0
            state.song_duration = 0 -- Will be estimated during playback
            state.needs_next_chunk = 1
            os.queueEvent("audio_update")
        elseif not state.playing then
            -- Stop speakers when pausing
            for _, speaker in ipairs(speakers) do
                speaker.stop()
            end
            os.queueEvent("playback_stopped")
        end
        
        state.logger.info("RadioHost", "Playback " .. (state.playing and "started" or "paused") .. " - Session: " .. (state.current_playback_session or "none"))
        
        -- Broadcast playback state to listeners
        if state.is_broadcasting then
            radioHost.broadcastPlaybackState(state)
            -- Send immediate sync to ensure clients are updated
            radioHost.broadcastSyncStatus(state)
        end
    elseif #state.playlist > 0 then
        -- Start playing first song if no song is selected
        state.current_song_index = 1
        state.now_playing = state.playlist[1]
        state.playing = true
        state.current_playback_session = os.getComputerID() .. "_" .. os.epoch("utc")
        state.playback_start_time = os.epoch("utc") / 1000
        -- Reset song position tracking
        state.song_start_time = os.epoch("utc") / 1000
        state.current_song_position = 0
        state.song_duration = 0 -- Will be estimated during playback
        state.needs_next_chunk = 1
        state.decoder = require("cc.audio.dfpwm").make_decoder()
        state.logger.info("RadioHost", "Started playing: " .. state.now_playing.name .. " - Session: " .. state.current_playback_session)
        
        if state.is_broadcasting then
            radioHost.broadcastSongChange(state)
            radioHost.broadcastSyncStatus(state)
        end
        
        os.queueEvent("audio_update")
    end
end

function radioHost.nextSong(state, speakers)
    if #state.playlist == 0 then
        return
    end
    
    -- Stop current playback COMPLETELY
    if state.player_handle then
        state.player_handle.close()
        state.player_handle = nil
    end
    
    -- Stop speakers and clear any pending audio
    for _, speaker in ipairs(speakers) do
        speaker.stop()
    end
    os.queueEvent("playback_stopped")
    
    -- Clear playback session to prevent overlapping
    state.current_playback_session = nil
    state.playback_start_time = 0
    -- Reset song position tracking
    state.song_start_time = 0
    state.current_song_position = 0
    state.song_duration = 0
    
    -- Move to next song
    if state.looping == 2 then -- Song loop
        -- Keep current song but reset session
    elseif state.current_song_index < #state.playlist then
        state.current_song_index = state.current_song_index + 1
    elseif state.looping == 1 then -- Playlist loop
        state.current_song_index = 1
    else
        -- End of playlist, stop playing
        state.playing = false
        state.now_playing = nil
        state.current_song_index = 0
        state.current_playback_session = nil
        state.playback_start_time = 0
        -- Reset song position tracking
        state.song_start_time = 0
        state.current_song_position = 0
        state.song_duration = 0
        
        if state.is_broadcasting then
            radioHost.broadcastPlaybackState(state)
            radioHost.broadcastSyncStatus(state)
        end
        return
    end
    
    -- Start new song with new session
    state.now_playing = state.playlist[state.current_song_index]
    state.current_playback_session = os.getComputerID() .. "_" .. os.epoch("utc")
    state.playback_start_time = os.epoch("utc") / 1000
    -- Reset song position tracking for new song
    state.song_start_time = os.epoch("utc") / 1000
    state.current_song_position = 0
    state.song_duration = 0 -- Will be estimated during playback
    state.needs_next_chunk = 1
    state.decoder = require("cc.audio.dfpwm").make_decoder()
    state.playing_id = nil -- Reset to trigger new download
    
    state.logger.info("RadioHost", "Next song: " .. state.now_playing.name .. " - New Session: " .. state.current_playback_session)
    
    -- Broadcast song change to listeners
    if state.is_broadcasting then
        radioHost.broadcastSongChange(state)
        radioHost.broadcastSyncStatus(state)
    end
    
    os.queueEvent("audio_update")
end

function radioHost.previousSong(state, speakers)
    if #state.playlist == 0 then
        return
    end
    
    -- Stop current playback COMPLETELY
    if state.player_handle then
        state.player_handle.close()
        state.player_handle = nil
    end
    
    -- Stop speakers and clear any pending audio
    for _, speaker in ipairs(speakers) do
        speaker.stop()
    end
    os.queueEvent("playback_stopped")
    
    -- Clear playback session to prevent overlapping
    state.current_playback_session = nil
    state.playback_start_time = 0
    -- Reset song position tracking
    state.song_start_time = 0
    state.current_song_position = 0
    state.song_duration = 0
    
    -- Move to previous song
    if state.current_song_index > 1 then
        state.current_song_index = state.current_song_index - 1
    elseif state.looping == 1 then -- Playlist loop
        state.current_song_index = #state.playlist
    else
        -- Stay at first song
        state.current_song_index = 1
    end
    
    -- Start song with new session
    state.now_playing = state.playlist[state.current_song_index]
    state.current_playback_session = os.getComputerID() .. "_" .. os.epoch("utc")
    state.playback_start_time = os.epoch("utc") / 1000
    -- Reset song position tracking for new song
    state.song_start_time = os.epoch("utc") / 1000
    state.current_song_position = 0
    state.song_duration = 0 -- Will be estimated during playback
    state.needs_next_chunk = 1
    state.decoder = require("cc.audio.dfpwm").make_decoder()
    state.playing_id = nil -- Reset to trigger new download
    
    state.logger.info("RadioHost", "Previous song: " .. state.now_playing.name .. " - New Session: " .. state.current_playback_session)
    
    -- Broadcast song change to listeners
    if state.is_broadcasting then
        radioHost.broadcastSongChange(state)
        radioHost.broadcastSyncStatus(state)
    end
    
    os.queueEvent("audio_update")
end

-- PLAYLIST MANAGEMENT
function radioHost.clearPlaylist(state)
    -- Stop current playback
    if state.player_handle then
        state.player_handle.close()
        state.player_handle = nil
    end
    
    state.playlist = {}
    state.current_song_index = 0
    state.now_playing = nil
    state.playing = false
    
    state.logger.info("RadioHost", "Playlist cleared")
    
    -- Broadcast playlist update to listeners
    if state.is_broadcasting then
        radioHost.broadcastPlaylistUpdate(state)
    end
end

function radioHost.shufflePlaylist(state)
    if #state.playlist <= 1 then
        return
    end
    
    -- Save current song
    local currentSong = state.now_playing
    
    -- Shuffle playlist
    for i = #state.playlist, 2, -1 do
        local j = math.random(i)
        state.playlist[i], state.playlist[j] = state.playlist[j], state.playlist[i]
    end
    
    -- Find new position of current song
    if currentSong then
        for i, song in ipairs(state.playlist) do
            if song.id == currentSong.id then
                state.current_song_index = i
                break
            end
        end
    end
    
    state.logger.info("RadioHost", "Playlist shuffled")
    
    -- Broadcast playlist update to listeners
    if state.is_broadcasting then
        radioHost.broadcastPlaylistUpdate(state)
    end
end

-- PRE-BUFFER SYNCHRONIZATION FUNCTIONS

-- Send sync command based on latency measurements
function radioHost.sendSyncCommand(state, forceSync)
    if not state.latency_tracker or not state.audio_buffer then
        return false
    end
    
    -- Calculate optimal sync timing
    local syncData = latencyManager.calculateOptimalSync(state.latency_tracker)
    if not syncData and not forceSync then
        return false
    end
    
    -- Generate new sync session if needed
    if not state.sync_session_id or forceSync then
        state.sync_session_id = os.getComputerID() .. "_sync_" .. os.epoch("utc")
    end
    
    -- Get current buffer status
    local bufferStatus = bufferManager.getBufferStatus(state.audio_buffer)
    if not bufferStatus then
        return false
    end
    
    -- Prepare sync command data
    local syncCommandData = {
        target_position = bufferStatus.current_position,
        sync_timestamp = syncData and syncData.sync_timestamp or (os.epoch("utc") + 1000),
        slowest_client_latency = syncData and syncData.slowest_latency or 0,
        buffer_offset = bufferStatus.buffered_duration,
        song_id = state.audio_buffer.song_id,
        session_id = state.sync_session_id
    }
    
    -- Send sync command to all listeners
    local stationId = os.getComputerID()
    local success = radioProtocol.sendSyncCommand(stationId, syncCommandData)
    
    if success then
        state.logger.info("RadioHost", string.format("Sync command sent: session=%s, latency=%.1fms, clients=%d", 
            state.sync_session_id, syncData and syncData.slowest_latency or 0, syncData and syncData.active_clients or 0))
    end
    
    return success
end

-- Enhanced audio loop with PRE-buffer support
function radioHost.enhancedAudioLoop(state, speakers)
    while true do
        if state.playing and state.now_playing and not state.is_error then
            -- Initialize buffer for new song
            if state.audio_buffer and not state.audio_buffer.song_id then
                local songId = state.now_playing.id or state.now_playing.name
                bufferManager.resetBuffer(state.audio_buffer, songId, state.song_duration or 0)
                state.logger.info("RadioHost", "Buffer initialized for song: " .. songId)
            end
            
            -- Download and buffer audio chunks
            if state.needs_next_chunk > 0 then
                local success = radioHost.downloadAndBufferChunk(state)
                if success then
                    state.needs_next_chunk = state.needs_next_chunk - 1
                    
                    -- Broadcast chunk to clients if buffer system is enabled
                    if state.audio_buffer and state.is_broadcasting then
                        radioHost.broadcastBufferChunk(state)
                    end
                else
                    state.needs_next_chunk = 0
                end
            end
            
            -- Play audio from buffer if ready
            if state.audio_buffer and state.buffer_ready then
                radioHost.playFromBuffer(state, speakers)
            end
        end
        
        sleep(0.1)
    end
end

-- Download and buffer audio chunk
function radioHost.downloadAndBufferChunk(state)
    if not state.now_playing or not state.audio_buffer then
        return false
    end
    
    -- This is a simplified version - in reality you'd integrate with the existing HTTP download logic
    -- For now, we'll simulate adding chunks to the buffer
    
    local currentTime = os.epoch("utc") / 1000
    local songPosition = state.current_song_position
    
    -- Simulate audio data (in reality this would come from HTTP download)
    local simulatedAudioData = string.rep("\x00", 1024) -- 1KB of silence as placeholder
    
    -- Add chunk to buffer
    local success = bufferManager.addChunk(state.audio_buffer, simulatedAudioData, songPosition)
    
    if success then
        state.current_song_position = songPosition + config.radio_sync.chunk_duration
        state.logger.debug("RadioHost", string.format("Buffered chunk at position %.1fs", songPosition))
    end
    
    return success
end

-- Broadcast buffer chunk to clients
function radioHost.broadcastBufferChunk(state)
    if not state.audio_buffer or not state.is_broadcasting then
        return false
    end
    
    -- Get the most recent chunk
    local bufferStatus = bufferManager.getBufferStatus(state.audio_buffer)
    if not bufferStatus or bufferStatus.active_chunks == 0 then
        return false
    end
    
    -- Find the latest chunk to broadcast
    local latestChunk = nil
    local latestTimestamp = 0
    
    for i = 1, state.audio_buffer.max_chunks do
        local chunk = state.audio_buffer.chunks[i]
        if chunk.id and chunk.timestamp > latestTimestamp then
            latestChunk = chunk
            latestTimestamp = chunk.timestamp
        end
    end
    
    if latestChunk then
        -- Add song_id to chunk data
        latestChunk.song_id = state.audio_buffer.song_id
        
        -- Broadcast to all clients
        local stationId = os.getComputerID()
        local success = radioProtocol.broadcastBufferChunk(stationId, latestChunk)
        
        if success then
            state.logger.debug("RadioHost", string.format("Broadcasted chunk %s (%.1fs)", 
                latestChunk.id, latestChunk.buffer_position))
        end
        
        return success
    end
    
    return false
end

-- Play audio from buffer
function radioHost.playFromBuffer(state, speakers)
    if not state.audio_buffer or not speakers then
        return false
    end
    
    local currentTime = os.epoch("utc") / 1000
    local playbackPosition = currentTime - state.song_start_time
    
    -- Get chunk at current playback position
    local chunk = bufferManager.getChunkAtPosition(state.audio_buffer, playbackPosition)
    
    if chunk and chunk.audio_data then
        -- Play the chunk (simplified - in reality you'd use the existing audio playback logic)
        for _, speaker in ipairs(speakers) do
            if speaker and speaker.playAudio then
                speaker.playAudio(chunk.audio_data)
            end
        end
        
        -- Advance buffer position
        bufferManager.advancePosition(state.audio_buffer, config.radio_sync.chunk_duration)
        
        state.logger.debug("RadioHost", string.format("Played chunk from buffer at position %.1fs", playbackPosition))
        return true
    end
    
    return false
end

-- Get PRE-buffer system status for UI display
function radioHost.getBufferSystemStatus(state)
    if not state.audio_buffer or not state.latency_tracker then
        return {
            enabled = false,
            status = "Disabled"
        }
    end
    
    local bufferStatus = bufferManager.getBufferStatus(state.audio_buffer)
    local clientStats = latencyManager.getAllClientStats(state.latency_tracker)
    local activeClients = latencyManager.getActiveClientCount(state.latency_tracker)
    
    return {
        enabled = state.sync_enabled,
        status = state.buffer_ready and "Ready" or "Buffering",
        buffer_health = bufferStatus and bufferStatus.buffer_health or 0,
        buffered_duration = bufferStatus and bufferStatus.buffered_duration or 0,
        active_chunks = bufferStatus and bufferStatus.active_chunks or 0,
        active_clients = activeClients,
        slowest_latency = clientStats[#clientStats] and clientStats[#clientStats].average_latency or 0,
        sync_session = state.sync_session_id
    }
end

return radioHost 