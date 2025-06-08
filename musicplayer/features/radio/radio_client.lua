-- Radio Client feature for Bognesferga Radio
-- Allows listening to network radio stations with synchronized streaming
-- PRE-Buffer Synchronization System Implementation

local radioProtocol = require("musicplayer/network/radio_protocol")
local bufferManager = require("musicplayer/audio/buffer_manager")
local config = require("musicplayer/config")

local radioClient = {}

function radioClient.init(systemModules)
    local state = {
        -- System modules
        logger = systemModules.logger,
        speakerManager = systemModules.speakerManager,
        errorHandler = systemModules.errorHandler,
        
        -- UI state
        width = 0,
        height = 0,
        tab = 1, -- 1 = Station List, 2 = Now Playing
        waiting_for_input = false,
        
        -- Station discovery
        stations = {},
        scanning = false,
        last_scan_time = 0,
        scan_interval = 30, -- seconds
        
        -- Connection state
        connected_station = nil,
        connection_status = "disconnected", -- disconnected, connecting, connected, error
        connection_error = nil,
        
        -- Playback state (synchronized with host)
        now_playing = nil,
        playing = false,
        playlist = {},
        current_song_index = 0,
        
        -- Audio streaming (FIXED with synchronization)
        audio_buffer = {},
        decoder = require("cc.audio.dfpwm").make_decoder(),
        volume = 1.5,
        muted = false, -- NEW: Mute state for client
        is_playing_audio = false, -- Track if we're actively playing audio
        
        -- Audio configuration (from config)
        api_base_url = "https://ipod-2to6magyna-uc.a.run.app/",
        version = "2.1",
        chunk_size = 16 * 1024 - 4,
        initial_read_size = 4,
        
        -- Audio playback state
        playing_id = nil,
        playing_status = 0,
        needs_next_chunk = 0,
        player_handle = nil,
        last_download_url = nil,
        is_loading = false,
        is_error = false,
        start = nil,
        size = 0,
        buffer = nil,
        
        -- PRE-BUFFER SYNCHRONIZATION SYSTEM
        sync_buffer = nil,          -- Buffer manager instance for received chunks
        buffer_ready = false,       -- Whether buffer is ready for synchronized playback
        sync_enabled = true,        -- Enable/disable sync system
        
        -- Latency tracking
        network_latency = 0,        -- Estimated network latency to host
        latency_samples = {},       -- Store recent latency measurements
        last_ping_sent = 0,         -- When we last sent a ping
        ping_sequence = 0,          -- Ping sequence counter
        
        -- Sync coordination
        current_sync_session = nil, -- Current sync session from host
        sync_timestamp = 0,         -- When we should start playing
        sync_delay = 0,             -- How long to delay before playing
        sync_ready = false,         -- Whether we're ready for sync playback
        
        -- Buffer management
        buffer_health = 0,          -- Buffer health percentage
        buffered_duration = 0,      -- How much audio is buffered
        last_buffer_update = 0,     -- When we last updated buffer status
        
        -- Legacy sync system (fallback)
        current_playback_session = nil, -- Track current session from host
        last_sync_time = 0,
        sync_timeout = 60, -- seconds - only for detecting truly dead hosts
        
        -- Song timeline tracking - PROPER TIME-BASED SYNC
        song_start_time = 0, -- When we started playing current song locally
        host_song_start_time = 0, -- When host started playing current song
        song_duration = 0, -- Total length of current song in seconds
        last_timeline_update = 0, -- When we last got timeline info from host
        
        -- Time-based sync system - NEVER STOPS MUSIC
        sync_drift_samples = {}, -- Store recent drift measurements
        max_drift_samples = 3, -- Need 3 consistent measurements (reduced for faster response)
        major_sync_threshold = 5.0, -- Major corrections above 5 seconds
        minor_sync_threshold = 1.0, -- Minor corrections above 1 second
        last_sync_correction = 0, -- When we last made a correction
        sync_correction_cooldown = 10, -- Don't correct more than once per 10 seconds (reduced)
        
        -- Playback speed adjustment for sync - CONTINUOUS MUSIC
        playback_speed_multiplier = 1.0, -- Normal speed = 1.0, faster = >1.0, slower = <1.0
        target_song_position = 0, -- Where we should be in the song based on host timing
        actual_song_position = 0, -- Where we actually are in the song
        position_drift = 0, -- Difference between target and actual position
        
        -- Network state
        protocol_available = false,
        last_ping_time = 0,
        ping_interval = 10, -- seconds
        
        -- UI refresh
        last_ui_update = 0,
        ui_update_interval = 1 -- seconds
    }
    
    -- Initialize radio protocol
    state.protocol_available = radioProtocol.init(state.errorHandler)
    if not state.protocol_available then
        state.logger.warn("RadioClient", "No wireless modem found - radio client disabled")
    else
        state.logger.info("RadioClient", "Radio protocol initialized for client")
    end
    
    -- Initialize PRE-buffer system
    if state.protocol_available then
        state.sync_buffer = bufferManager.createBuffer(state.logger)
        
        state.logger.info("RadioClient", string.format("PRE-buffer system initialized (%.1fs buffer, %.1fs chunks)", 
            config.radio_sync.buffer_duration, config.radio_sync.chunk_duration))
    end
    
    return state
end

function radioClient.run(state)
    state.logger.info("RadioClient", "Starting radio client")
    
    -- Get screen size
    state.width, state.height = term.getSize()
    
    -- Check if radio is available
    if not state.protocol_available then
        radioClient.showNoModemError(state)
        return "menu"
    end
    
    -- Get raw speakers
    local speakers = state.speakerManager.getRawSpeakers()
    if #speakers == 0 then
        state.errorHandler.handleError("RadioClient", "No speakers attached. You need to connect a speaker to this computer.", 3)
        return "menu"
    end
    
    -- Initial station scan
    radioClient.scanForStations(state)
    
    -- Run main loops with proper return handling
    local result = parallel.waitForAny(
        function() return radioClient.uiLoop(state, speakers) end,
        function() return radioClient.audioLoop(state, speakers) end,
        function() return radioClient.networkLoop(state) end
    )
    
    -- Clean up
    radioClient.cleanup(state)
    
    return "menu"
end

function radioClient.showNoModemError(state)
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Beautiful header
    term.setBackgroundColor(colors.blue)
    term.setCursorPos(1, 1)
    term.clearLine()
    local title = "Bognesferga Radio Client"
    local fullHeader = "📻 " .. title .. " 📻"
    local headerX = math.floor((state.width - #fullHeader) / 2) + 1
    term.setCursorPos(headerX, 1)
    term.setTextColor(colors.yellow)
    term.write("📻 ")
    term.setTextColor(colors.white)
    term.write(title)
    term.setTextColor(colors.yellow)
    term.write(" 📻")
    
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.red)
    term.setCursorPos(3, 4)
    term.write("Radio Client Error")
    
    term.setTextColor(colors.white)
    term.setCursorPos(3, 6)
    term.write("No wireless modem detected!")
    
    term.setCursorPos(3, 8)
    term.write("To listen to radio stations, you need:")
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
    term.write("3. Restart the radio client")
    
    term.setTextColor(colors.lightGray)
    term.setCursorPos(3, 17)
    term.write("Press any key to return to menu...")
    
    os.pullEvent("key")
end

-- BEAUTIFUL UI REDRAW (like YouTube player and radio host)
function radioClient.redrawScreen(state)
    if state.waiting_for_input then
        return
    end

    term.setCursorBlink(false)
    state.width, state.height = term.getSize()
    
    -- Clear screen
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Beautiful main menu style header
    term.setBackgroundColor(colors.blue)
    term.setCursorPos(1, 1)
    term.clearLine()
    local title = "Bognesferga Radio Client"
    local fullHeader = "📻 " .. title .. " 📻"
    local headerX = math.floor((state.width - #fullHeader) / 2) + 1
    term.setCursorPos(headerX, 1)
    term.setTextColor(colors.yellow)
    term.write("📻 ")
    term.setTextColor(colors.white)
    term.write(title)
    term.setTextColor(colors.yellow)
    term.write(" 📻")

    -- Beautiful modern tabs
    local tabs = {" Station List ", " Now Playing "}
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
        radioClient.drawStationList(state)
    elseif state.tab == 2 then
        radioClient.drawNowPlaying(state)
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

function radioClient.drawStationList(state)
    -- Station list header with yellow accent
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 4)
    term.write("Available Radio Stations:")
    
    -- Scan status
    if state.scanning then
        term.setTextColor(colors.cyan)
        term.setCursorPos(3, 5)
        term.write("🔍 Scanning for stations...")
    else
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, 5)
        term.write("Last scan: " .. os.date("%H:%M:%S", state.last_scan_time))
    end
    
    -- Refresh button
    term.setBackgroundColor(colors.cyan)
    term.setTextColor(colors.black)
    term.setCursorPos(state.width - 12, 5)
    term.write(" 🔄 Refresh ")
    
    -- Station list
    if #state.stations > 0 then
        local startY = 7
        local maxStations = math.min(8, #state.stations)
        
        for i = 1, maxStations do
            local station = state.stations[i]
            local y = startY + (i - 1)
            
            -- Highlight connected station
            if state.connected_station and state.connected_station.station_id == station.station_id then
                term.setBackgroundColor(colors.lime)
                term.setTextColor(colors.black)
            else
                term.setBackgroundColor(colors.lightBlue)
                term.setTextColor(colors.black)
            end
            
            term.setCursorPos(3, y)
            
            local stationName = station.station_name
            if #stationName > 20 then
                stationName = stationName:sub(1, 17) .. "..."
            end
            
            local listenerInfo = station.listener_count .. "/" .. station.max_listeners
            local nowPlayingText = ""
            if station.now_playing then
                nowPlayingText = " ♪ " .. station.now_playing.name
                if #nowPlayingText > 25 then
                    nowPlayingText = nowPlayingText:sub(1, 22) .. "..."
                end
            end
            
            local stationText = "📻 " .. stationName .. " (" .. listenerInfo .. ")" .. nowPlayingText
            term.write(stationText .. string.rep(" ", state.width - 6 - #stationText))
        end
        
        if #state.stations > 8 then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(3, startY + 9)
            term.write("... and " .. (#state.stations - 8) .. " more stations")
        end
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, 7)
        term.write("No radio stations found")
        term.setCursorPos(3, 8)
        term.write("Make sure there are radio hosts broadcasting nearby")
        term.setCursorPos(3, 9)
        term.write("Click Refresh to scan again")
    end
    
    -- Connection status
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, state.height - 5)
    term.write("Connection Status:")
    
    if state.connection_status == "connected" and state.connected_station then
        term.setTextColor(colors.lime)
        term.setCursorPos(3, state.height - 4)
        term.write("🔴 Connected to: " .. state.connected_station.station_name)
        
        -- Disconnect button
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.setCursorPos(3, state.height - 3)
        term.write(" 🔌 Disconnect ")
        
    elseif state.connection_status == "connecting" then
        term.setTextColor(colors.yellow)
        term.setCursorPos(3, state.height - 4)
        if state.connecting_to_station then
            term.write("🔄 Connecting to: " .. state.connecting_to_station.station_name)
        else
            term.write("🔄 Connecting...")
        end
        
    elseif state.connection_status == "error" then
        term.setTextColor(colors.red)
        term.setCursorPos(3, state.height - 4)
        term.write("❌ Connection Error: " .. (state.connection_error or "Unknown"))
        
    else
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, state.height - 4)
        term.write("⚫ Not connected")
        term.setCursorPos(3, state.height - 3)
        term.write("   Click on a station to connect")
    end
end

function radioClient.drawNowPlaying(state)
    -- Now playing header with yellow accent
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 4)
    term.write("Now Playing from Radio Station:")
    
    -- Station info
    if state.connected_station then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.setCursorPos(3, 6)
        term.write("📻 " .. state.connected_station.station_name)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, 7)
        term.write("   " .. state.connected_station.station_description)
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, 6)
        term.write("📻 Not connected to any station")
        term.setCursorPos(3, 7)
        term.write("   Go to Station List to connect")
    end
    
    -- Current song info
    if state.now_playing then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.setCursorPos(3, 9)
        term.write("♪ " .. state.now_playing.name)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, 10)
        term.write("  " .. (state.now_playing.artist or "Unknown Artist"))
        
        -- Playback status (synchronized with host)
        if state.playing then
            term.setTextColor(colors.lime)
            term.setCursorPos(3, 11)
            term.write("▶ Playing (Live Stream)")
        else
            term.setTextColor(colors.yellow)
            term.setCursorPos(3, 11)
            term.write("⏸ Paused (Host Paused)")
        end
        
        -- Song time/position display
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.yellow)
        term.setCursorPos(3, 12)
        term.write("Song Position:")
        
        -- Calculate and display current position
        local currentPosition = state.actual_song_position or 0
        local totalDuration = state.song_duration or 0
        local targetPosition = state.target_song_position or 0
        
        -- Format time as MM:SS
        local function formatTime(seconds)
            local mins = math.floor(seconds / 60)
            local secs = math.floor(seconds % 60)
            return string.format("%d:%02d", mins, secs)
        end
        
        term.setTextColor(colors.white)
        term.setCursorPos(3, 13)
        if totalDuration > 0 then
            term.write(formatTime(currentPosition) .. " / " .. formatTime(totalDuration))
            
            -- Show sync info if we have target position
            if targetPosition > 0 and math.abs(currentPosition - targetPosition) > 0.5 then
                term.setTextColor(colors.cyan)
                term.write(" (sync: " .. formatTime(targetPosition) .. ")")
            end
        else
            term.write(formatTime(currentPosition) .. " / --:--")
        end
        
        -- Progress bar
        if totalDuration > 0 then
            term.setCursorPos(3, 14)
            local progressWidth = 30
            local progress = math.min(1.0, currentPosition / totalDuration)
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
        term.setCursorPos(3, 9)
        term.write("♪ No song playing")
        term.setCursorPos(3, 10)
        term.write("  Waiting for host to start music")
    end
    
    -- Volume control (local only) - moved down to accommodate song position
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 16)
    term.write("Local Volume: ")
    
    local volumePercent = math.floor((state.volume / 3.0) * 100)
    term.setTextColor(colors.white)
    term.write(volumePercent .. "%")
    
    -- Volume slider
    term.setCursorPos(3, 17)
    local sliderWidth = 20
    local fillWidth = math.floor((state.volume / 3.0) * sliderWidth)
    
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.write("[")
    
    for i = 1, sliderWidth do
        if i <= fillWidth then
            term.setBackgroundColor(colors.cyan)
            term.write(" ")
        else
            term.setBackgroundColor(colors.gray)
            term.write(" ")
        end
    end
    
    term.setBackgroundColor(colors.gray)
    term.write("]")
    
    -- Bass and Treble Controls - moved down
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 19)
    term.write("Audio Controls:")
    
    -- Bass control
    term.setCursorPos(3, 20)
    term.setTextColor(colors.white)
    term.write("Bass: ")
    
    local bassLevel = state.speakerManager.getBass()
    local bassStr = bassLevel > 0 and ("+" .. bassLevel) or tostring(bassLevel)
    term.setTextColor(colors.cyan)
    term.write(bassStr)
    
    -- Bass adjustment buttons
    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.white)
    term.setCursorPos(15, 20)
    term.write(" - ")
    
    term.setBackgroundColor(colors.lime)
    term.setTextColor(colors.black)
    term.setCursorPos(19, 20)
    term.write(" + ")
    
    -- Treble control
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(25, 20)
    term.write("Treble: ")
    
    local trebleLevel = state.speakerManager.getTreble()
    local trebleStr = trebleLevel > 0 and ("+" .. trebleLevel) or tostring(trebleLevel)
    term.setTextColor(colors.cyan)
    term.write(trebleStr)
    
    -- Treble adjustment buttons
    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.white)
    term.setCursorPos(40, 20)
    term.write(" - ")
    
    term.setBackgroundColor(colors.lime)
    term.setTextColor(colors.black)
    term.setCursorPos(44, 20)
    term.write(" + ")
    
    -- Audio processing toggle
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightGray)
    term.setCursorPos(3, 21)
    term.write("Audio Processing: ")
    
    if state.speakerManager.isAudioProcessingEnabled() then
        term.setBackgroundColor(colors.lime)
        term.setTextColor(colors.black)
        term.write(" ON ")
    else
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write(" OFF ")
    end
    
    -- Station playlist (if available) - moved down to accommodate song position
    local playlistStartY = 23
    if #state.playlist > 0 then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.yellow)
        term.setCursorPos(3, playlistStartY)
        term.write("Station Playlist:")
        
        local maxShow = math.min(4, #state.playlist) -- Reduced to fit audio controls
        for i = 1, maxShow do
            local song = state.playlist[i]
            local y = playlistStartY + i
            
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
        
        if #state.playlist > 4 then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(3, playlistStartY + 5)
            term.write("... and " .. (#state.playlist - 4) .. " more songs")
        end
    end
    
    -- Connection info
    if state.connected_station then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.yellow)
        term.setCursorPos(3, state.height - 5)
        term.write("Connection Info:")
        
        term.setTextColor(colors.cyan)
        term.setCursorPos(3, state.height - 4)
        term.write("🔗 Connected to Computer-" .. state.connected_station.station_id)
        
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, state.height - 3)
        term.write("📡 Receiving live audio stream")
    end
end

-- MAIN UI LOOP (like YouTube player and radio host)
function radioClient.uiLoop(state, speakers)
    while true do
        radioClient.redrawScreen(state)
        
        local event, p1, p2, p3 = os.pullEvent()
        
        -- Handle both mouse_click and monitor_touch events
        if event == "mouse_click" or event == "monitor_touch" then
            local button, x, y
            
            if event == "mouse_click" then
                button, x, y = p1, p2, p3
            else -- monitor_touch
                button, x, y = 1, p2, p3 -- Assume left click for monitor touch
            end
            
            state.logger.info("RadioClient", "Click detected at " .. x .. "," .. y)
            
            -- Back to menu button (footer)
            if y == state.height - 1 and x >= 2 and x <= 16 then
                state.logger.info("RadioClient", "Back to menu clicked")
                return "back_to_menu"
            end
            
            -- Tab switching (header area)
            if y == 2 then
                local tabWidth = math.floor(state.width / 2)
                if x <= tabWidth then
                    state.tab = 1 -- Station List
                else
                    state.tab = 2 -- Now Playing
                end
                state.logger.info("RadioClient", "Switched to tab " .. state.tab)
                goto continue
            end
            
            -- Tab-specific click handling
            if state.tab == 1 then -- Station List tab
                radioClient.handleStationListClicks(state, x, y, speakers)
            elseif state.tab == 2 then -- Now Playing tab
                radioClient.handleNowPlayingClicks(state, x, y, speakers)
            end
        end
        
        ::continue::
    end
end

function radioClient.handleStationListClicks(state, x, y, speakers)
    -- Don't allow clicks while connecting
    if state.connection_status == "connecting" then
        return
    end
    
    -- Refresh button
    if y == 5 and x >= state.width - 12 and x <= state.width - 1 then
        radioClient.scanForStations(state)
        return
    end
    
    -- Station selection
    if y >= 7 and y <= 14 and #state.stations > 0 then
        local stationIndex = y - 6
        if stationIndex >= 1 and stationIndex <= #state.stations then
            local selectedStation = state.stations[stationIndex]
            
            -- Don't reconnect to same station
            if state.connected_station and state.connected_station.station_id == selectedStation.station_id then
                return
            end
            
            radioClient.connectToStation(state, selectedStation, speakers)
        end
        return
    end
    
    -- Disconnect button
    if y == state.height - 3 and x >= 3 and x <= 16 and state.connection_status == "connected" then
        radioClient.disconnectFromStation(state)
        return
    end
end

function radioClient.handleNowPlayingClicks(state, x, y, speakers)
    -- Volume slider click - moved down by 3 lines
    if y == 17 and x >= 4 and x <= 24 and not state.muted then
        local sliderPos = x - 4
        local newVolume = (sliderPos / 20) * 3.0
        state.volume = math.max(0, math.min(3.0, newVolume))
        state.speakerManager.setVolume(state.volume)
        state.logger.info("RadioClient", "Volume set to " .. state.volume)
        return
    end
    
    -- Mute/Unmute toggle (click on volume percentage) - moved down by 3 lines
    if y == 16 and x >= 17 and x <= 25 then
        state.muted = not state.muted
        state.logger.info("RadioClient", "Audio " .. (state.muted and "muted" or "unmuted"))
        return
    end
    
    -- Bass and Treble controls - moved down by 3 lines
    if y == 20 then
        -- Bass controls
        if x >= 15 and x < 18 then -- Bass minus button
            local currentBass = state.speakerManager.getBass()
            state.speakerManager.setBass(currentBass - 1)
            state.logger.info("RadioClient", "Bass decreased to " .. state.speakerManager.getBass())
        elseif x >= 19 and x < 22 then -- Bass plus button
            local currentBass = state.speakerManager.getBass()
            state.speakerManager.setBass(currentBass + 1)
            state.logger.info("RadioClient", "Bass increased to " .. state.speakerManager.getBass())
        end
        
        -- Treble controls
        if x >= 40 and x < 43 then -- Treble minus button
            local currentTreble = state.speakerManager.getTreble()
            state.speakerManager.setTreble(currentTreble - 1)
            state.logger.info("RadioClient", "Treble decreased to " .. state.speakerManager.getTreble())
        elseif x >= 44 and x < 47 then -- Treble plus button
            local currentTreble = state.speakerManager.getTreble()
            state.speakerManager.setTreble(currentTreble + 1)
            state.logger.info("RadioClient", "Treble increased to " .. state.speakerManager.getTreble())
        end
        return
    end
    
    -- Audio processing toggle - moved down by 3 lines
    if y == 21 and x >= 21 and x < 26 then
        local currentEnabled = state.speakerManager.isAudioProcessingEnabled()
        state.speakerManager.setAudioProcessingEnabled(not currentEnabled)
        state.logger.info("RadioClient", "Audio processing " .. (not currentEnabled and "enabled" or "disabled"))
        return
    end
end

-- STATION MANAGEMENT
function radioClient.scanForStations(state)
    state.logger.info("RadioClient", "Scanning for radio stations...")
    
    state.scanning = true
    state.scan_start_time = os.clock()
    state.stations = {}
    
    -- Open broadcast channel to listen for announcements
    radioProtocol.openBroadcastChannel()
    
    -- Send discovery request
    local discoveryRequest = {
        type = "discovery_request",
        client_id = os.getComputerID(),
        timestamp = os.epoch("utc")
    }
    
    radioProtocol.broadcast(discoveryRequest)
    state.logger.info("RadioClient", "Discovery request sent, listening on broadcast channel")
end

function radioClient.connectToStation(state, station)
    if not station then
        return
    end
    
    state.logger.info("RadioClient", "Connecting to station: " .. station.station_name .. " (ID: " .. station.station_id .. ")")
    
    state.connection_status = "connecting"
    state.connecting_to_station = station
    state.connection_start_time = os.clock()
    state.connection_error = nil
    
    -- Record connection attempt time for latency measurement
    state.connection_attempt_time = os.epoch("utc") / 1000
    
    -- Calculate channels
    local stationChannel = radioProtocol.getStationChannel(station.station_id)
    local clientChannel = radioProtocol.getClientChannel(os.getComputerID())
    
    state.logger.info("RadioClient", "Using station channel: " .. stationChannel .. ", client channel: " .. clientChannel)
    
    -- Open our client channel to receive response
    radioProtocol.openChannel(clientChannel)
    
    -- Send join request using the protocol's expected format
    local joinRequest = {
        type = "join_request",
        listener_id = os.getComputerID(),
        timestamp = os.epoch("utc"),
        request_time = state.connection_attempt_time -- For latency calculation
    }
    
    -- Create protocol message manually to control reply channel
    local protocolMessage = {
        protocol_version = "1.0",
        timestamp = os.epoch("utc"),
        data = joinRequest
    }
    
    -- Open station channel and send with proper reply channel
    radioProtocol.openChannel(stationChannel)
    
    -- Get the raw modem to send with specific reply channel
    local modem = nil
    local sides = {"top", "bottom", "left", "right", "front", "back"}
    for _, side in ipairs(sides) do
        if peripheral.isPresent(side) and peripheral.getType(side) == "modem" then
            local testModem = peripheral.wrap(side)
            if testModem.isWireless() then
                modem = testModem
                break
            end
        end
    end
    
    if modem then
        modem.transmit(stationChannel, clientChannel, protocolMessage)
        state.logger.info("RadioClient", "Join request sent to station " .. station.station_id .. " on channel " .. stationChannel .. " with reply channel " .. clientChannel)
    else
        state.connection_status = "error"
        state.connection_error = "No modem available"
        state.logger.error("RadioClient", "No wireless modem found")
    end
end

function radioClient.disconnectFromStation(state)
    if not state.connected or not state.connected_station_id then
        return
    end
    
    state.logger.info("RadioClient", "Disconnecting from station")
    
    -- CLEAR AUDIO STOP LOG
    term.setTextColor(colors.red)
    print("🔌 AUDIO STOPPED: Disconnecting from station")
    term.setTextColor(colors.white)
    
    -- Send leave request
    local leaveRequest = {
        type = "leave_request",
        listener_id = os.getComputerID(),
        timestamp = os.epoch("utc")
    }
    
    local stationChannel = radioProtocol.getStationChannel(state.connected_station_id)
    radioProtocol.sendToChannel(stationChannel, leaveRequest)
    
    -- Stop audio
    if state.player_handle then
        state.player_handle.close()
        state.player_handle = nil
    end
    
    local speakers = state.speakerManager.getRawSpeakers()
    for _, speaker in ipairs(speakers) do
        speaker.stop()
    end
    
    -- Reset connection state
    state.connected = false
    state.connected_station_id = nil
    state.connected_station = nil
    state.connection_status = "disconnected"
    state.playing = false
    state.now_playing = nil
    state.is_playing_audio = false
    state.current_playback_session = nil
    
    state.logger.info("RadioClient", "Disconnected from station")
end

function radioClient.refreshStations(state)
    state.logger.info("RadioClient", "Refreshing station list")
    radioClient.scanForStations(state)
end

-- AUDIO LOOP (handle network audio streaming from host) - SIMPLIFIED SYNC
function radioClient.audioLoop(state, speakers)
    while true do
        -- Handle HTTP responses for audio streaming
        local event, url, handle = os.pullEvent()
        
        if event == "http_success" then
            -- Handle audio stream responses (both local and from radio host songs)
            if url == state.last_download_url then
                state.player_handle = handle
                state.playing_status = 1
                state.is_loading = false
                state.start = state.player_handle.read(state.initial_read_size)
                state.size = state.chunk_size
                
                if state.connected then
                    state.logger.info("RadioClient", "Radio audio stream ready: " .. (state.now_playing and state.now_playing.name or "Unknown") .. " at position " .. string.format("%.1f", state.actual_song_position or 0) .. "s")
                    -- CLEAR AUDIO READY LOG
                    term.setTextColor(colors.lime)
                    print("🎵 AUDIO READY: Radio stream - " .. (state.now_playing and state.now_playing.name or "Unknown"))
                    term.setTextColor(colors.white)
                else
                    state.logger.info("RadioClient", "Local audio stream ready")
                    -- CLEAR AUDIO READY LOG
                    term.setTextColor(colors.lime)
                    print("🎵 AUDIO READY: Local stream")
                    term.setTextColor(colors.white)
                end
                
                -- Now that we have the handle, start playing if we should be
                if state.playing and state.now_playing and not state.is_playing_audio then
                    state.needs_next_chunk = 1
                    local thisnowplayingid = state.now_playing.id
                    if state.playing_id == thisnowplayingid then
                        state.logger.info("RadioClient", "Starting audio playback for: " .. state.now_playing.name .. " at position " .. string.format("%.1f", state.actual_song_position or 0) .. "s")
                        radioClient.playLocalAudio(state, speakers, thisnowplayingid)
                    end
                end
                
                os.queueEvent("redraw_screen")
            end
        elseif event == "http_failure" then
            if url == state.last_download_url then
                state.is_loading = false
                state.is_error = true
                state.playing = false
                state.playing_id = nil
                
                if state.connected then
                    state.logger.error("RadioClient", "Radio audio stream request failed for: " .. (state.now_playing and state.now_playing.name or "Unknown"))
                    -- CLEAR AUDIO STOP LOG
                    term.setTextColor(colors.red)
                    print("🔴 AUDIO STOPPED: HTTP request failed for radio song - " .. (state.now_playing and state.now_playing.name or "Unknown"))
                    term.setTextColor(colors.white)
                else
                    state.logger.error("RadioClient", "Local audio stream request failed")
                    -- CLEAR AUDIO STOP LOG
                    term.setTextColor(colors.red)
                    print("🔴 AUDIO STOPPED: HTTP request failed for local song")
                    term.setTextColor(colors.white)
                end
                
                os.queueEvent("redraw_screen")
            end
        elseif event == "audio_update" then
            -- Handle audio playback for both local and radio streaming - CONTINUOUS PLAYBACK
            if state.playing and state.now_playing and not state.is_playing_audio then
                local thisnowplayingid = state.now_playing.id
                
                if state.playing_id ~= thisnowplayingid then
                    -- New song - start streaming
                    state.logger.info("RadioClient", "New song detected: " .. state.now_playing.name .. " (was: " .. (state.playing_id or "none") .. ")")
                    
                    -- Stop any existing playback
                    if state.player_handle then
                        state.player_handle.close()
                        state.player_handle = nil
                    end
                    
                    state.playing_id = thisnowplayingid
                    state.last_download_url = state.api_base_url .. "?v=" .. state.version .. "&id=" .. textutils.urlEncode(state.playing_id)
                    state.playing_status = 0
                    state.needs_next_chunk = 0 -- Reset until HTTP request completes
                    state.is_loading = true
                    state.is_error = false

                    http.request({url = state.last_download_url, binary = true})
                    
                    -- Record when we started this song locally
                    state.song_start_time = os.epoch("utc") / 1000
                    
                    if state.connected then
                        state.logger.info("RadioClient", "Requesting radio song: " .. state.now_playing.name)
                        -- CLEAR AUDIO START LOG
                        term.setTextColor(colors.lime)
                        print("🎵 RADIO SONG: Requesting " .. state.now_playing.name)
                        term.setTextColor(colors.white)
                    else
                        state.logger.info("RadioClient", "Requesting local song: " .. state.now_playing.name)
                        -- CLEAR AUDIO START LOG
                        term.setTextColor(colors.lime)
                        print("🎵 LOCAL SONG: Requesting " .. state.now_playing.name)
                        term.setTextColor(colors.white)
                    end

                    os.queueEvent("redraw_screen")
                    
                elseif state.playing_status == 1 and state.needs_next_chunk == 1 and state.player_handle then
                    -- Continue playing existing song - only if we have a valid handle
                    state.logger.info("RadioClient", "Continuing audio playback for: " .. state.now_playing.name)
                    radioClient.playLocalAudio(state, speakers, thisnowplayingid)
                elseif state.playing_status == 1 and state.needs_next_chunk == 1 and not state.player_handle then
                    -- We should be playing but don't have a handle - this shouldn't happen
                    state.logger.warn("RadioClient", "Audio update triggered but no player handle available")
                    state.needs_next_chunk = 0
                    state.is_playing_audio = false
                end
            elseif not state.playing then
                state.logger.debug("RadioClient", "Audio update triggered but not playing")
            elseif not state.now_playing then
                state.logger.debug("RadioClient", "Audio update triggered but no song selected")
            elseif state.is_playing_audio then
                state.logger.debug("RadioClient", "Audio update triggered but already playing")
            end
        end
    end
end

function radioClient.playLocalAudio(state, speakers, thisnowplayingid)
    -- Check if we have a valid player handle
    if not state.player_handle then
        state.logger.error("RadioClient", "playLocalAudio called but player_handle is nil")
        -- CLEAR AUDIO STOP LOG
        term.setTextColor(colors.red)
        print("🔴 AUDIO STOPPED: No player handle available")
        term.setTextColor(colors.white)
        state.is_playing_audio = false
        state.needs_next_chunk = 0
        return
    end
    
    -- CLEAR AUDIO START LOG
    term.setTextColor(colors.lime)
    print("🎵 AUDIO STARTED: Playing " .. (state.now_playing and state.now_playing.name or "Unknown") .. " at " .. string.format("%.1f", state.actual_song_position or 0) .. "s")
    term.setTextColor(colors.white)
    
    -- Track playback timing for position calculation
    local playback_start_time = os.epoch("utc") / 1000
    local chunks_played = 0
    local chunk_duration = 0.05 -- Approximate duration per chunk in seconds
    
    -- Continuous audio playback with position tracking
    while true do
        local chunk = state.player_handle.read(state.size)
        if not chunk then
            -- Song finished naturally
            if state.connected then
                state.logger.info("RadioClient", "Radio song finished")
                -- CLEAR AUDIO STOP LOG
                term.setTextColor(colors.yellow)
                print("🎵 SONG FINISHED: " .. (state.now_playing and state.now_playing.name or "Unknown"))
                term.setTextColor(colors.white)
            else
                state.logger.info("RadioClient", "Local song finished")
                -- CLEAR AUDIO STOP LOG
                term.setTextColor(colors.yellow)
                print("🎵 SONG FINISHED: Local playback")
                term.setTextColor(colors.white)
            end
            
            if state.player_handle then
                state.player_handle.close()
                state.player_handle = nil
            end
            state.needs_next_chunk = 0
            state.is_playing_audio = false
            break
        else
            if state.start then
                chunk, state.start = state.start .. chunk, nil
                state.size = state.size + 4
            end
    
            -- Process audio normally
            if #chunk > 0 then
                state.buffer = state.decoder(chunk)
                
                -- Play audio locally (only if not muted)
                if not state.muted then
                    local fn = {}
                    for i, speaker in ipairs(speakers) do 
                        fn[i] = function()
                            local name = peripheral.getName(speaker)
                            local playVolume = state.volume
                            
                            -- Apply audio processing if enabled
                            if state.speakerManager and state.speakerManager.processAudio then
                                state.buffer = state.speakerManager.processAudio(state.buffer)
                            end
                            
                            if #speakers > 1 then
                                if speaker.playAudio(state.buffer, playVolume) then
                                    parallel.waitForAny(
                                        function()
                                            repeat until select(2, os.pullEvent("speaker_audio_empty")) == name
                                        end,
                                        function()
                                            local event = os.pullEvent("playback_stopped")
                                            -- CLEAR AUDIO STOP LOG
                                            term.setTextColor(colors.red)
                                            print("🔴 AUDIO STOPPED: Playback stopped event received")
                                            term.setTextColor(colors.white)
                                            return
                                        end
                                    )
                                    if not state.playing or state.playing_id ~= thisnowplayingid then
                                        -- CLEAR AUDIO STOP LOG
                                        term.setTextColor(colors.red)
                                        print("🔴 AUDIO STOPPED: State changed - Playing: " .. tostring(state.playing) .. ", ID match: " .. tostring(state.playing_id == thisnowplayingid))
                                        term.setTextColor(colors.white)
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
                                            -- CLEAR AUDIO STOP LOG
                                            term.setTextColor(colors.red)
                                            print("🔴 AUDIO STOPPED: Playback stopped event received")
                                            term.setTextColor(colors.white)
                                            return
                                        end
                                    )
                                    if not state.playing or state.playing_id ~= thisnowplayingid then
                                        -- CLEAR AUDIO STOP LOG
                                        term.setTextColor(colors.red)
                                        print("🔴 AUDIO STOPPED: State changed - Playing: " .. tostring(state.playing) .. ", ID match: " .. tostring(state.playing_id == thisnowplayingid))
                                        term.setTextColor(colors.white)
                                        return
                                    end
                                end
                            end
                            if not state.playing or state.playing_id ~= thisnowplayingid then
                                -- CLEAR AUDIO STOP LOG
                                term.setTextColor(colors.red)
                                print("🔴 AUDIO STOPPED: Final state check failed - Playing: " .. tostring(state.playing) .. ", ID match: " .. tostring(state.playing_id == thisnowplayingid))
                                term.setTextColor(colors.white)
                                return
                            end
                        end
                    end
                    
                    local ok, err = pcall(parallel.waitForAll, table.unpack(fn))
                    if not ok then
                        state.logger.error("RadioClient", "Audio playback error: " .. tostring(err))
                        -- CLEAR AUDIO STOP LOG
                        term.setTextColor(colors.red)
                        print("🔴 AUDIO STOPPED: Playback error - " .. tostring(err))
                        term.setTextColor(colors.white)
                        state.needs_next_chunk = 2
                        state.is_error = true
                        break
                    end
                    
                    state.is_playing_audio = true
                else
                    -- Still process audio timing even when muted
                    sleep(0.05)
                    state.is_playing_audio = true
                end
                
                -- Update song position based on playback time and speed multiplier
                chunks_played = chunks_played + 1
                local elapsed_time = (os.epoch("utc") / 1000) - playback_start_time
                local adjusted_elapsed = elapsed_time * (state.playback_speed_multiplier or 1.0)
                state.actual_song_position = (state.actual_song_position or 0) + (chunk_duration * (state.playback_speed_multiplier or 1.0))
                
                -- Apply speed multiplier for sync adjustment
                if state.playback_speed_multiplier and state.playback_speed_multiplier ~= 1.0 then
                    -- Adjust timing based on speed multiplier
                    local base_sleep = 0.05 -- Base timing between chunks
                    local adjusted_sleep = base_sleep / state.playback_speed_multiplier
                    
                    -- Ensure we don't go too fast or too slow
                    adjusted_sleep = math.max(0.01, math.min(0.1, adjusted_sleep))
                    
                    if adjusted_sleep ~= base_sleep then
                        sleep(adjusted_sleep - base_sleep) -- Additional adjustment
                    end
                end
            end
            
            -- Exit only for legitimate stops (not sync corrections)
            if not state.playing or state.playing_id ~= thisnowplayingid then
                -- CLEAR AUDIO STOP LOG - Only for legitimate stops
                term.setTextColor(colors.yellow)
                print("🎵 AUDIO ENDING: Legitimate stop - Playing: " .. tostring(state.playing) .. ", ID match: " .. tostring(state.playing_id == thisnowplayingid))
                term.setTextColor(colors.white)
                break
            end
        end
    end
    
    -- CLEAR AUDIO STOP LOG
    term.setTextColor(colors.yellow)
    print("🎵 AUDIO ENDED: playLocalAudio function completed")
    term.setTextColor(colors.white)
    
    os.queueEvent("audio_update")
end

-- NETWORK LOOP (radio communication) - PRE-BUFFER SYNC
function radioClient.networkLoop(state)
    while true do
        local currentTime = os.epoch("utc") / 1000
        
        -- Handle station scanning timeout
        if state.scanning and state.scan_start_time then
            if (os.clock() - state.scan_start_time) >= 5 then -- 5 second timeout
                state.scanning = false
                state.last_scan_time = currentTime
                state.logger.info("RadioClient", "Station scan completed: " .. #state.stations .. " stations found")
                os.queueEvent("redraw_screen")
            end
        end
        
        -- Handle connection timeout
        if state.connection_status == "connecting" and state.connection_start_time then
            if (os.clock() - state.connection_start_time) >= 10 then -- 10 second timeout
                state.connection_status = "error"
                state.connection_error = "Connection timeout"
                state.connecting_to_station = nil
                state.logger.error("RadioClient", "Connection timeout - no response from host")
                os.queueEvent("redraw_screen")
            end
        end
        
        -- PRE-BUFFER: Update buffer status
        if state.sync_buffer and state.connected then
            local bufferStatus = bufferManager.getBufferStatus(state.sync_buffer)
            if bufferStatus then
                state.buffer_health = bufferStatus.buffer_health
                state.buffer_ready = bufferStatus.buffer_ready
                state.buffered_duration = bufferStatus.buffered_duration
                
                -- Send buffer ready notification to host
                if state.buffer_ready and not state.sync_ready then
                    radioClient.sendBufferReadyNotification(state)
                    state.sync_ready = true
                end
                
                -- Clean up old chunks periodically
                if (currentTime - state.last_buffer_update) >= 30 then -- Every 30 seconds
                    bufferManager.cleanupOldChunks(state.sync_buffer, 60)
                    state.last_buffer_update = currentTime
                end
            end
        end
        
        -- Send periodic ping to host (keep-alive)
        if state.connected and (currentTime - state.last_ping_time) >= state.ping_interval then
            radioClient.sendPing(state)
            state.last_ping_time = currentTime
        end
        
        -- Check for host timeout (very forgiving)
        if state.connected and state.last_sync_time > 0 then
            local timeSinceSync = currentTime - state.last_sync_time
            
            if timeSinceSync > state.sync_timeout then
                state.logger.error("RadioClient", "Host unresponsive for " .. state.sync_timeout .. " seconds - disconnecting")
                radioClient.disconnectFromStation(state)
                return "disconnected"
            end
        end
        
        -- Handle incoming network messages
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        
        if message and type(message) == "table" then
            state.logger.debug("RadioClient", "Received message on channel " .. channel .. " (reply: " .. replyChannel .. ") from distance " .. (distance or "unknown"))
            
            if radioProtocol.isValidMessage(message) then
                local data = radioProtocol.extractMessageData(message)
                if data then
                    state.logger.debug("RadioClient", "Valid message type: " .. (data.type or "unknown") .. " from station " .. (data.station_id or "unknown"))
                    
                    -- PRE-BUFFER: Handle ping requests from host
                    if data.type == "ping_request" and state.connected then
                        radioClient.handlePingRequest(state, data, replyChannel)
                        
                    -- PRE-BUFFER: Handle buffer chunks from host
                    elseif data.type == "buffer_chunk" and state.connected and state.sync_buffer then
                        radioClient.handleBufferChunk(state, data)
                        
                    -- PRE-BUFFER: Handle sync commands from host
                    elseif data.type == "sync_command" and state.connected then
                        radioClient.handleSyncCommand(state, data)
                        
                    -- Debug connection process
                    elseif state.connection_status == "connecting" and state.connecting_to_station then
                        state.logger.debug("RadioClient", "Currently connecting to station " .. state.connecting_to_station.station_id .. ", received message from station " .. (data.station_id or "unknown"))
                    end
                end
                
                -- Handle station discovery responses
                if state.scanning and data and data.type == "station_announcement" then
                    state.logger.info("RadioClient", "Station announcement received from " .. (data.station_id or "unknown") .. ": " .. (data.station_name or "Unknown"))
                    
                    -- Check if we already have this station
                    local found = false
                    for _, station in ipairs(state.stations) do
                        if station.station_id == data.station_id then
                            -- Update existing station info
                            station.station_name = data.station_name
                            station.station_description = data.station_description
                            station.listener_count = data.listener_count
                            station.max_listeners = data.max_listeners
                            station.now_playing = data.now_playing
                            station.last_seen = data.timestamp
                            found = true
                            break
                        end
                    end

                    if not found then
                        -- Add new station
                        table.insert(state.stations, {
                            station_id = data.station_id,
                            station_name = data.station_name,
                            station_description = data.station_description,
                            listener_count = data.listener_count or 0,
                            max_listeners = data.max_listeners or 10,
                            now_playing = data.now_playing,
                            last_seen = data.timestamp,
                            distance = distance
                        })
                        
                        state.logger.info("RadioClient", "Found station: " .. data.station_name)
                        os.queueEvent("redraw_screen")
                    end
                end
    
                -- Handle connection responses
                if state.connection_status == "connecting" and state.connecting_to_station then
                    local clientId = os.getComputerID()
                    local clientChannel = radioProtocol.getClientChannel(clientId)
                    
                    state.logger.debug("RadioClient", "Checking for join response - our channel: " .. clientChannel .. ", message channel: " .. channel)
                    
                    if channel == clientChannel and data and data.type == "join_response" then
                        state.logger.info("RadioClient", "Join response received! Success: " .. tostring(data.success))
                        
                        -- Calculate initial latency from connection attempt
                        if state.connection_attempt_time and data.response_time then
                            local latency = (currentTime - state.connection_attempt_time) / 2
                            table.insert(state.latency_samples, latency)
                            state.network_latency = latency
                            state.logger.info("RadioClient", "Initial network latency: " .. string.format("%.3f", latency) .. "s")
                        end
                        
                        if data.success then
                            state.connection_status = "connected"
                            state.connected = true
                            state.connected_station_id = state.connecting_to_station.station_id
                            state.connected_station = state.connecting_to_station
                            state.connecting_to_station = nil
                            state.last_sync_time = currentTime
                            
                            -- Initialize PRE-buffer for this connection
                            if state.sync_buffer then
                                bufferManager.resetBuffer(state.sync_buffer, nil, 0)
                                state.buffer_ready = false
                                state.sync_ready = false
                                state.logger.info("RadioClient", "PRE-buffer initialized for connection")
                            end
                            
                            -- Update state from host response
                            if data.now_playing then
                                state.now_playing = data.now_playing
                                state.song_duration = data.song_duration or 0
                            end
                            
                            if data.playing ~= nil then
                                state.playing = data.playing
                            end
                            
                            if data.playlist then
                                state.playlist = data.playlist
                            end
                            
                            if data.current_song_index then
                                state.current_song_index = data.current_song_index
                            end
                            
                            state.logger.info("RadioClient", "Connected to station: " .. state.connected_station.station_name)
                            
                            -- If we have a song and should be playing, start at correct position
                            if state.playing and state.now_playing then
                                -- Calculate where we should start with latency compensation
                                local host_song_position = 0
                                if data.playback_start_time then
                                    state.host_song_start_time = data.playback_start_time
                                    host_song_position = (currentTime + state.network_latency) - state.host_song_start_time
                                end
                                
                                state.target_song_position = math.max(0, host_song_position)
                                state.logger.info("RadioClient", "Connection established - starting audio for: " .. state.now_playing.name .. " at position " .. string.format("%.1f", state.target_song_position) .. "s")
                                
                                -- CLEAR CONNECTION LOG
                                term.setTextColor(colors.lime)
                                print("🔗 CONNECTED: Starting " .. state.now_playing.name .. " at " .. string.format("%.1f", state.target_song_position) .. "s")
                                term.setTextColor(colors.white)
                                
                                radioClient.startAudioAtPosition(state, state.target_song_position)
                            end
                        else
                            state.connection_status = "error"
                            state.connection_error = data.reason or "Connection rejected"
                            state.connecting_to_station = nil
                            state.logger.error("RadioClient", "Connection rejected: " .. (data.reason or "Unknown reason"))
                        end
                        
                        os.queueEvent("redraw_screen")
                    end
                end
    
                -- Handle messages from connected station
                if data and data.station_id == state.connected_station_id then
                    radioClient.handleNetworkMessage(state, data, replyChannel)
                end
            else
                state.logger.warn("RadioClient", "Invalid message received on channel " .. channel)
            end
        end
        
        sleep(0.2)
    end
end

function radioClient.handleNetworkMessage(state, data, replyChannel)
    if not data or not data.type then
        return
    end
    
    local currentTime = os.epoch("utc") / 1000
    state.last_sync_time = currentTime -- Update sync time on any valid message
    
    if data.type == "song_change" then
        state.logger.info("RadioClient", "Host changed song: " .. (data.now_playing and data.now_playing.name or "Unknown"))
        
        -- CLEAR AUDIO STOP LOG
        term.setTextColor(colors.cyan)
        print("🔄 AUDIO STOPPED: Host changed song to " .. (data.now_playing and data.now_playing.name or "Unknown"))
        term.setTextColor(colors.white)
        
        -- Stop current audio to prevent overlap
        if state.player_handle then
            state.player_handle.close()
            state.player_handle = nil
        end
        
        -- Stop speakers
        local speakers = state.speakerManager.getRawSpeakers()
        for _, speaker in ipairs(speakers) do
            speaker.stop()
        end
        
        -- Update to new song
        state.now_playing = data.now_playing
        state.current_song_index = data.current_song_index or 1
        state.playing = data.playing or false
        state.is_playing_audio = false
        
        -- Reset sync tracking for new song
        state.sync_drift_samples = {}
        state.allow_playback = true -- Always allow playback for new songs
        
        -- Record host's song start time
        if data.playback_start_time then
            state.host_song_start_time = data.playback_start_time
        end
        
        state.logger.info("RadioClient", "Song change processed - Playing: " .. tostring(state.playing) .. ", Song: " .. (state.now_playing and state.now_playing.name or "none") .. ", Allow playback: " .. tostring(state.allow_playback))
        
        -- Start streaming the new song
        if state.playing and state.now_playing then
            state.logger.info("RadioClient", "Starting new song from host: " .. state.now_playing.name)
            -- CLEAR AUDIO START LOG
            term.setTextColor(colors.lime)
            print("🎵 AUDIO STARTING: New song from host - " .. state.now_playing.name)
            term.setTextColor(colors.white)
            os.queueEvent("audio_update")
        end
        
        os.queueEvent("redraw_screen")
        
    elseif data.type == "playback_state" then
        state.logger.info("RadioClient", "Host playback state: " .. (data.playing and "playing" or "paused"))
        
        state.playing = data.playing or false
        if data.now_playing then
            state.now_playing = data.now_playing
        end
        
        if not state.playing then
            -- CLEAR AUDIO STOP LOG
            term.setTextColor(colors.orange)
            print("⏸️ AUDIO STOPPED: Host paused playback")
            term.setTextColor(colors.white)
            
            -- Stop speakers when host pauses
            local speakers = state.speakerManager.getRawSpeakers()
            for _, speaker in ipairs(speakers) do
                speaker.stop()
            end
            state.is_playing_audio = false
        elseif state.playing and state.now_playing and not state.is_playing_audio then
            -- Start playing when host resumes
            state.allow_playback = true
            state.logger.info("RadioClient", "Host resumed - triggering audio update")
            -- CLEAR AUDIO START LOG
            term.setTextColor(colors.lime)
            print("▶️ AUDIO STARTING: Host resumed playback - " .. (state.now_playing and state.now_playing.name or "Unknown"))
            term.setTextColor(colors.white)
            os.queueEvent("audio_update")
        end
        
        os.queueEvent("redraw_screen")
        
    elseif data.type == "playlist_update" then
        state.logger.info("RadioClient", "Host updated playlist: " .. #(data.playlist or {}) .. " songs")
        
        if data.playlist then
            state.playlist = data.playlist
        end
        if data.current_song_index then
            state.current_song_index = data.current_song_index
        end
        
        os.queueEvent("redraw_screen")
        
    elseif data.type == "sync_status" then
        -- Use the new simplified sync system
        radioClient.handleSyncStatus(state, data)
        os.queueEvent("redraw_screen")
        
    elseif data.type == "broadcast_end" then
        state.logger.info("RadioClient", "Host ended broadcast")
        
        -- CLEAR AUDIO STOP LOG
        term.setTextColor(colors.red)
        print("📻 AUDIO STOPPED: Host ended broadcast")
        term.setTextColor(colors.white)
        
        -- Stop audio but don't disconnect - stay connected for when broadcast resumes
        if state.player_handle then
            state.player_handle.close()
            state.player_handle = nil
        end
        
        local speakers = state.speakerManager.getRawSpeakers()
        for _, speaker in ipairs(speakers) do
            speaker.stop()
        end
        
        state.playing = false
        state.now_playing = nil
        state.is_playing_audio = false
        
        os.queueEvent("redraw_screen")
        
    elseif data.type == "ping_response" then
        -- Keep-alive response from host with latency measurement
        if state.last_ping_sent and data.ping_time then
            local latency = (currentTime - state.last_ping_sent) / 2
            table.insert(state.latency_samples, latency)
            
            -- Keep only recent samples
            if #state.latency_samples > 10 then
                table.remove(state.latency_samples, 1)
            end
            
            -- Calculate average latency
            local total_latency = 0
            for _, sample in ipairs(state.latency_samples) do
                total_latency = total_latency + sample
            end
            state.network_latency = total_latency / #state.latency_samples
            
            state.logger.debug("RadioClient", "Ping response - latency: " .. string.format("%.3f", latency) .. "s, avg: " .. string.format("%.3f", state.network_latency) .. "s")
        end
        -- Already updated last_sync_time at start of function
    end
end

function radioClient.handleSyncStatus(state, data)
    local currentTime = os.epoch("utc") / 1000
    state.last_timeline_update = currentTime
    
    -- Calculate network latency if we have ping data
    if data.ping_response and state.last_ping_sent then
        local latency = (currentTime - state.last_ping_sent) / 2 -- Round trip time / 2
        table.insert(state.latency_samples, latency)
        
        -- Keep only recent samples
        if #state.latency_samples > 10 then
            table.remove(state.latency_samples, 1)
        end
        
        -- Calculate average latency
        local total_latency = 0
        for _, sample in ipairs(state.latency_samples) do
            total_latency = total_latency + sample
        end
        state.network_latency = total_latency / #state.latency_samples
        
        state.logger.debug("RadioClient", "Network latency: " .. string.format("%.3f", state.network_latency) .. "s")
    end
    
    -- Update host timing information
    if data.playback_start_time then
        state.host_song_start_time = data.playback_start_time
    end
    
    -- Update song duration if provided
    if data.song_duration then
        state.song_duration = data.song_duration
    end
    
    -- Check if this is a new playback session (song change)
    if data.playback_session and data.playback_session ~= state.current_playback_session then
        state.logger.info("RadioClient", "New playback session detected: " .. data.playback_session)
        
        -- CLEAR SONG CHANGE LOG
        term.setTextColor(colors.cyan)
        print("🔄 SONG CHANGE: New session - " .. (data.now_playing and data.now_playing.name or "Unknown"))
        term.setTextColor(colors.white)
        
        -- Reset sync tracking for new session
        state.sync_drift_samples = {}
        state.current_playback_session = data.playback_session
        state.playback_speed_multiplier = 1.0
        
        -- Stop current audio ONLY for song changes
        if state.player_handle then
            state.player_handle.close()
            state.player_handle = nil
        end
        
        local speakers = state.speakerManager.getRawSpeakers()
        for _, speaker in ipairs(speakers) do
            speaker.stop()
        end
        
        state.is_playing_audio = false
        
        -- Start new session with proper timing
        if data.playing and data.now_playing then
            state.now_playing = data.now_playing
            state.playing = true
            state.host_song_start_time = data.playback_start_time or currentTime
            state.song_duration = data.song_duration or 0
            
            -- Calculate where we should start in the song (with latency compensation)
            local host_song_position = (currentTime + state.network_latency) - state.host_song_start_time
            state.target_song_position = math.max(0, host_song_position)
            
            state.logger.info("RadioClient", "Starting new session: " .. data.now_playing.name .. " at position " .. string.format("%.1f", state.target_song_position) .. "s")
            
            -- CLEAR AUDIO START LOG
            term.setTextColor(colors.lime)
            print("🎵 SONG STARTING: " .. data.now_playing.name .. " at " .. string.format("%.1f", state.target_song_position) .. "s")
            term.setTextColor(colors.white)
            
            -- Start audio with proper position
            radioClient.startAudioAtPosition(state, state.target_song_position)
        end
        
        return -- Exit early for new sessions
    end
    
    -- TIME-BASED SYNC FOR EXISTING SESSION - CONTINUOUS PLAYBACK
    if state.current_playback_session and data.playback_session == state.current_playback_session and 
       state.playing and state.now_playing and state.host_song_start_time > 0 then
        
        -- Calculate current positions with latency compensation
        local host_song_position = (currentTime + state.network_latency) - state.host_song_start_time
        local client_song_position = currentTime - state.song_start_time
        
        -- Update target position
        state.target_song_position = host_song_position
        state.actual_song_position = client_song_position
        state.position_drift = state.target_song_position - state.actual_song_position
        
        -- Store drift sample
        table.insert(state.sync_drift_samples, {
            timestamp = currentTime,
            target_position = state.target_song_position,
            actual_position = state.actual_song_position,
            drift = state.position_drift
        })
        
        -- Keep only recent samples
        if #state.sync_drift_samples > state.max_drift_samples then
            table.remove(state.sync_drift_samples, 1)
        end
        
        state.logger.info("RadioClient", "Position sync: target=" .. string.format("%.1f", state.target_song_position) .. "s, actual=" .. string.format("%.1f", state.actual_song_position) .. "s, drift=" .. string.format("%.1f", state.position_drift) .. "s")
        
        -- CONTINUOUS PLAYBACK: Adjust speed based on position drift
        if #state.sync_drift_samples >= state.max_drift_samples and 
           (currentTime - state.last_sync_correction) >= state.sync_correction_cooldown then
            
            -- Calculate average drift
            local total_drift = 0
            for _, sample in ipairs(state.sync_drift_samples) do
                total_drift = total_drift + sample.drift
            end
            local average_drift = total_drift / #state.sync_drift_samples
            
            state.logger.info("RadioClient", "Sync analysis: avg_drift=" .. string.format("%.1f", average_drift) .. "s")
            
            -- MAJOR DRIFT: Significant speed adjustment
            if math.abs(average_drift) > state.major_sync_threshold then
                local speed_adjustment = 1.0 + (average_drift * 0.1) -- 10% per second of drift
                speed_adjustment = math.max(0.5, math.min(2.0, speed_adjustment)) -- Limit to 50%-200%
                
                state.playback_speed_multiplier = speed_adjustment
                state.logger.warn("RadioClient", "Major position drift (" .. string.format("%.1f", average_drift) .. "s) - adjusting speed to " .. string.format("%.2f", speed_adjustment))
                
                -- CLEAR SYNC LOG
                term.setTextColor(colors.lightBlue)
                print("🎵 SYNC MAJOR: Drift " .. string.format("%.1f", average_drift) .. "s - speed " .. string.format("%.2f", speed_adjustment) .. "x")
                term.setTextColor(colors.white)
                
                -- Reset speed after adjustment period
                local function resetSpeed()
                    sleep(math.min(10, math.abs(average_drift) * 2)) -- Adjust for up to 10 seconds
                    state.playback_speed_multiplier = 1.0
                    state.logger.info("RadioClient", "Speed reset to normal")
                    term.setTextColor(colors.lightBlue)
                    print("🎵 SYNC NORMAL: Speed reset to 1.0x")
                    term.setTextColor(colors.white)
                end
                
                parallel.waitForAny(resetSpeed, function() sleep(0.01) end)
                
            -- MINOR DRIFT: Subtle speed adjustment
            elseif math.abs(average_drift) > state.minor_sync_threshold then
                local speed_adjustment = 1.0 + (average_drift * 0.05) -- 5% per second of drift
                speed_adjustment = math.max(0.8, math.min(1.2, speed_adjustment)) -- Limit to 80%-120%
                
                state.playback_speed_multiplier = speed_adjustment
                state.logger.info("RadioClient", "Minor position drift (" .. string.format("%.1f", average_drift) .. "s) - adjusting speed to " .. string.format("%.2f", speed_adjustment))
                
                -- CLEAR SYNC LOG
                term.setTextColor(colors.lightBlue)
                print("🎵 SYNC MINOR: Drift " .. string.format("%.1f", average_drift) .. "s - speed " .. string.format("%.2f", speed_adjustment) .. "x")
                term.setTextColor(colors.white)
                
                -- Reset speed after shorter period
                local function resetMicroSpeed()
                    sleep(5) -- Adjust for 5 seconds
                    state.playback_speed_multiplier = 1.0
                end
                
                parallel.waitForAny(resetMicroSpeed, function() sleep(0.01) end)
                
            else
                -- Drift within acceptable range - ensure normal speed
                state.playback_speed_multiplier = 1.0
            end
            
            state.sync_drift_samples = {} -- Clear samples after adjustment
            state.last_sync_correction = currentTime
        end
    end
    
    -- Handle song changes - ONLY stop for actual song changes
    if data.now_playing and state.now_playing then
        if data.now_playing.id ~= state.now_playing.id then
            state.logger.info("RadioClient", "Song change detected via sync")
            
            -- CLEAR SONG CHANGE LOG
            term.setTextColor(colors.cyan)
            print("🔄 SONG CHANGE: " .. data.now_playing.name)
            term.setTextColor(colors.white)
            
            state.now_playing = data.now_playing
            state.current_song_index = data.current_song_index or 1
            state.song_duration = data.song_duration or 0
            
            -- Reset sync tracking for new song
            state.sync_drift_samples = {}
            state.playback_speed_multiplier = 1.0
            state.host_song_start_time = data.playback_start_time or currentTime
            
            -- Calculate starting position with latency compensation
            local host_song_position = (currentTime + state.network_latency) - state.host_song_start_time
            state.target_song_position = math.max(0, host_song_position)
            
            -- Stop current audio for song change
            if state.player_handle then
                state.player_handle.close()
                state.player_handle = nil
            end
            
            local speakers = state.speakerManager.getRawSpeakers()
            for _, speaker in ipairs(speakers) do
                speaker.stop()
            end
            
            state.is_playing_audio = false
            
            state.logger.info("RadioClient", "Song change: " .. state.now_playing.name .. " at position " .. string.format("%.1f", state.target_song_position) .. "s")
            
            -- CLEAR AUDIO START LOG
            term.setTextColor(colors.lime)
            print("🎵 SONG STARTING: " .. state.now_playing.name .. " at " .. string.format("%.1f", state.target_song_position) .. "s")
            term.setTextColor(colors.white)
            
            -- Start new song at correct position
            radioClient.startAudioAtPosition(state, state.target_song_position)
        end
    elseif data.now_playing and not state.now_playing then
        -- First time receiving song info
        state.logger.info("RadioClient", "Received initial song info: " .. data.now_playing.name)
        
        state.now_playing = data.now_playing
        state.current_song_index = data.current_song_index or 1
        state.playing = data.playing or false
        state.song_duration = data.song_duration or 0
        state.host_song_start_time = data.playback_start_time or currentTime
        state.playback_speed_multiplier = 1.0
        
        if state.playing then
            -- Calculate starting position with latency compensation
            local host_song_position = (currentTime + state.network_latency) - state.host_song_start_time
            state.target_song_position = math.max(0, host_song_position)
            
            state.logger.info("RadioClient", "Initial sync: " .. state.now_playing.name .. " at position " .. string.format("%.1f", state.target_song_position) .. "s")
            
            -- CLEAR AUDIO START LOG
            term.setTextColor(colors.lime)
            print("🎵 SONG STARTING: Initial - " .. state.now_playing.name .. " at " .. string.format("%.1f", state.target_song_position) .. "s")
            term.setTextColor(colors.white)
            
            radioClient.startAudioAtPosition(state, state.target_song_position)
        end
    end
    
    -- Handle playback state changes - ONLY stop if host actually pauses
    if data.playing ~= nil and data.playing ~= state.playing then
        state.logger.info("RadioClient", "Playback state sync: " .. (data.playing and "playing" or "paused"))
        state.playing = data.playing
        
        if not state.playing then
            -- CLEAR PAUSE LOG
            term.setTextColor(colors.orange)
            print("⏸️ MUSIC PAUSED: Host paused the station")
            term.setTextColor(colors.white)
            
            -- Pause - stop speakers but don't disconnect
            local speakers = state.speakerManager.getRawSpeakers()
            for _, speaker in ipairs(speakers) do
                speaker.stop()
            end
            state.is_playing_audio = false
        elseif state.playing and state.now_playing and not state.is_playing_audio then
            -- Resume with proper position
            state.playback_speed_multiplier = 1.0
            state.host_song_start_time = data.playback_start_time or currentTime
            
            -- Calculate resume position with latency compensation
            local host_song_position = (currentTime + state.network_latency) - state.host_song_start_time
            state.target_song_position = math.max(0, host_song_position)
            
            state.logger.info("RadioClient", "Resume: " .. state.now_playing.name .. " at position " .. string.format("%.1f", state.target_song_position) .. "s")
            
            -- CLEAR RESUME LOG
            term.setTextColor(colors.lime)
            print("▶️ MUSIC RESUMED: " .. state.now_playing.name .. " at " .. string.format("%.1f", state.target_song_position) .. "s")
            term.setTextColor(colors.white)
            
            radioClient.startAudioAtPosition(state, state.target_song_position)
        end
    end
    
    -- Update playlist if provided
    if data.playlist and type(data.playlist) == "table" then
        state.playlist = data.playlist
        state.current_song_index = data.current_song_index or 1
    end
    
    state.logger.info("RadioClient", "Sync completed - Position: " .. string.format("%.1f", state.actual_song_position or 0) .. "/" .. string.format("%.1f", state.target_song_position or 0) .. "s, Speed: " .. string.format("%.2f", state.playback_speed_multiplier) .. "x, Latency: " .. string.format("%.3f", state.network_latency) .. "s")
end

-- CLEANUP (FIXED)
function radioClient.cleanup(state)
    -- Stop audio playback
    if state.speakerManager then
        state.speakerManager.stopAll()
    end
    
    -- Clear audio buffer
    state.audio_buffer = {}
    state.is_playing_audio = false
    
    -- Disconnect from station
    if state.connected_station then
        radioClient.disconnectFromStation(state)
    end
    
    -- Close radio protocol
    if state.protocol_available then
        radioProtocol.cleanup()
    end
    
    state.logger.info("RadioClient", "Radio client cleaned up")
end

function radioClient.sendPing(state)
    if not state.connected or not state.connected_station_id then
        return
    end
    
    local currentTime = os.epoch("utc") / 1000
    
    local pingMessage = {
        type = "listener_ping",
        listener_id = os.getComputerID(),
        timestamp = os.epoch("utc"),
        ping_time = currentTime -- For latency calculation
    }
    
    -- Store ping time for latency calculation
    state.last_ping_sent = currentTime
    
    local stationChannel = radioProtocol.getStationChannel(state.connected_station_id)
    radioProtocol.sendToChannel(stationChannel, pingMessage)
    
    state.logger.debug("RadioClient", "Ping sent to measure latency")
end

-- Start audio at a specific position in the song (for proper sync)
function radioClient.startAudioAtPosition(state, startPosition)
    if not state.now_playing or not state.now_playing.id then
        state.logger.error("RadioClient", "Cannot start audio - no song selected")
        return
    end
    
    -- Stop any existing playback
    if state.player_handle then
        state.player_handle.close()
        state.player_handle = nil
    end
    
    local speakers = state.speakerManager.getRawSpeakers()
    for _, speaker in ipairs(speakers) do
        speaker.stop()
    end
    
    -- Set up for new audio stream
    state.playing_id = state.now_playing.id
    state.song_start_time = os.epoch("utc") / 1000 -- Record when we start locally
    state.actual_song_position = startPosition -- We're starting at this position
    
    -- Build URL with start position parameter
    local url = state.api_base_url .. "?v=" .. state.version .. "&id=" .. textutils.urlEncode(state.playing_id)
    
    -- Add start position parameter if not starting from beginning
    if startPosition > 0 then
        url = url .. "&t=" .. math.floor(startPosition) -- Add start time in seconds
        state.logger.info("RadioClient", "Requesting song with start position: " .. string.format("%.1f", startPosition) .. "s")
    end
    
    state.last_download_url = url
    state.playing_status = 0
    state.needs_next_chunk = 0
    state.is_loading = true
    state.is_error = false
    state.is_playing_audio = false
    
    -- Request the audio stream
    http.request({url = url, binary = true})
    
    state.logger.info("RadioClient", "Audio stream requested for: " .. state.now_playing.name .. " at position " .. string.format("%.1f", startPosition) .. "s")
    
    -- CLEAR AUDIO REQUEST LOG
    term.setTextColor(colors.cyan)
    print("🎵 AUDIO REQUEST: " .. state.now_playing.name .. " at " .. string.format("%.1f", startPosition) .. "s")
    term.setTextColor(colors.white)
end

-- PRE-BUFFER SYNCHRONIZATION FUNCTIONS

-- Handle ping request from host for latency measurement
function radioClient.handlePingRequest(state, data, replyChannel)
    if not data.sequence or not data.timestamp then
        return
    end
    
    local currentTime = os.epoch("utc")
    local clientId = os.getComputerID()
    
    -- Send ping response
    local response = radioProtocol.sendPingResponse(clientId, data.sequence, currentTime)
    
    if response then
        state.logger.debug("RadioClient", string.format("Ping response sent (seq=%d)", data.sequence))
    end
end

-- Handle buffer chunk from host
function radioClient.handleBufferChunk(state, data)
    if not state.sync_buffer or not data.chunk_id or not data.audio_data then
        return
    end
    
    -- Verify chunk belongs to current song
    if data.song_id and state.now_playing then
        local currentSongId = state.now_playing.id or state.now_playing.name
        if data.song_id ~= currentSongId then
            state.logger.debug("RadioClient", string.format("Ignoring chunk for different song: %s (current: %s)", 
                data.song_id, currentSongId))
            return
        end
    end
    
    -- Add chunk to buffer
    local success = bufferManager.addChunk(state.sync_buffer, data.audio_data, data.buffer_position)
    
    if success then
        state.logger.debug("RadioClient", string.format("Buffered chunk %s (%.1fs, %d bytes)", 
            data.chunk_id, data.buffer_position, #data.audio_data))
        
        -- Update buffer status
        local bufferStatus = bufferManager.getBufferStatus(state.sync_buffer)
        if bufferStatus then
            state.buffer_health = bufferStatus.buffer_health
            state.buffered_duration = bufferStatus.buffered_duration
        end
    else
        state.logger.warn("RadioClient", string.format("Failed to buffer chunk %s", data.chunk_id))
    end
end

-- Handle sync command from host
function radioClient.handleSyncCommand(state, data)
    if not data.sync_timestamp or not data.session_id then
        state.logger.warn("RadioClient", "Invalid sync command received")
        return
    end
    
    local currentTime = os.epoch("utc")
    
    -- Update sync session
    state.current_sync_session = data.session_id
    state.sync_timestamp = data.sync_timestamp
    
    -- Calculate sync delay with latency compensation
    local syncDelay = (data.sync_timestamp - currentTime) / 1000 -- Convert to seconds
    syncDelay = syncDelay - state.network_latency -- Compensate for network latency
    
    state.sync_delay = math.max(0, syncDelay)
    
    state.logger.info("RadioClient", string.format("Sync command received: session=%s, delay=%.3fs, target_pos=%.1fs", 
        data.session_id, state.sync_delay, data.target_position or 0))
    
    -- If we have enough buffer and sync delay is reasonable, prepare for synchronized playback
    if state.buffer_ready and state.sync_delay < config.radio_sync.max_sync_delay then
        radioClient.prepareSynchronizedPlayback(state, data)
    else
        -- Fall back to immediate playback or request emergency resync
        if not state.buffer_ready then
            state.logger.warn("RadioClient", "Buffer not ready for sync - requesting emergency resync")
            radioClient.requestEmergencyResync(state, "Buffer not ready")
        else
            state.logger.warn("RadioClient", "Sync delay too large - requesting emergency resync")
            radioClient.requestEmergencyResync(state, "Sync delay too large")
        end
    end
end

-- Prepare for synchronized playback
function radioClient.prepareSynchronizedPlayback(state, syncData)
    if not state.sync_buffer then
        return false
    end
    
    -- Set target playback position
    state.target_song_position = syncData.target_position or 0
    
    -- Schedule synchronized start
    local startTime = os.epoch("utc") / 1000 + state.sync_delay
    
    -- Use timer to start playback at exact time
    os.startTimer(state.sync_delay)
    
    state.logger.info("RadioClient", string.format("Synchronized playback scheduled in %.3fs at position %.1fs", 
        state.sync_delay, state.target_song_position))
    
    -- CLEAR SYNC LOG
    term.setTextColor(colors.cyan)
    print(string.format("🔄 SYNC SCHEDULED: %.3fs delay, position %.1fs", state.sync_delay, state.target_song_position))
    term.setTextColor(colors.white)
    
    return true
end

-- Start synchronized playback from buffer
function radioClient.startSynchronizedPlayback(state)
    if not state.sync_buffer or not state.buffer_ready then
        return false
    end
    
    -- Stop any existing playback
    if state.player_handle then
        state.player_handle.close()
        state.player_handle = nil
    end
    
    local speakers = state.speakerManager.getRawSpeakers()
    for _, speaker in ipairs(speakers) do
        speaker.stop()
    end
    
    -- Start playing from buffer at target position
    local chunk = bufferManager.getChunkAtPosition(state.sync_buffer, state.target_song_position)
    
    if chunk and chunk.audio_data then
        -- Play the chunk
        for _, speaker in ipairs(speakers) do
            if speaker and speaker.playAudio then
                speaker.playAudio(chunk.audio_data)
            end
        end
        
        state.is_playing_audio = true
        state.song_start_time = os.epoch("utc") / 1000
        state.actual_song_position = state.target_song_position
        
        state.logger.info("RadioClient", string.format("Synchronized playback started at position %.1fs", 
            state.target_song_position))
        
        -- CLEAR SYNC START LOG
        term.setTextColor(colors.lime)
        print(string.format("🎵 SYNC PLAYBACK: Started at %.1fs", state.target_song_position))
        term.setTextColor(colors.white)
        
        return true
    else
        state.logger.error("RadioClient", "No audio chunk available at target position")
        radioClient.requestEmergencyResync(state, "No audio chunk available")
        return false
    end
end

-- Send buffer ready notification to host
function radioClient.sendBufferReadyNotification(state)
    if not state.connected_station_id or not state.sync_buffer then
        return false
    end
    
    local bufferStatus = bufferManager.getBufferStatus(state.sync_buffer)
    if not bufferStatus then
        return false
    end
    
    local clientId = os.getComputerID()
    local success = radioProtocol.sendClientBufferReady(clientId, bufferStatus.buffered_duration)
    
    if success then
        state.logger.info("RadioClient", string.format("Buffer ready notification sent (%.1fs buffered)", 
            bufferStatus.buffered_duration))
    end
    
    return success
end

-- Request emergency resync from host
function radioClient.requestEmergencyResync(state, reason)
    if not state.connected_station_id then
        return false
    end
    
    local clientId = os.getComputerID()
    local success = radioProtocol.sendEmergencyResync(clientId, reason)
    
    if success then
        state.logger.warn("RadioClient", string.format("Emergency resync requested: %s", reason))
        
        -- CLEAR EMERGENCY LOG
        term.setTextColor(colors.red)
        print(string.format("🚨 EMERGENCY RESYNC: %s", reason))
        term.setTextColor(colors.white)
    end
    
    return success
end

-- Enhanced audio loop with PRE-buffer support
function radioClient.enhancedAudioLoop(state, speakers)
    while true do
        local currentTime = os.epoch("utc") / 1000
        
        -- Handle synchronized playback from buffer
        if state.sync_buffer and state.buffer_ready and state.is_playing_audio then
            local playbackPosition = currentTime - state.song_start_time + state.actual_song_position
            
            -- Get next chunk from buffer
            local chunk = bufferManager.getChunkAtPosition(state.sync_buffer, playbackPosition)
            
            if chunk and chunk.audio_data then
                -- Play the chunk
                for _, speaker in ipairs(speakers) do
                    if speaker and speaker.playAudio then
                        speaker.playAudio(chunk.audio_data)
                    end
                end
                
                -- Advance position
                state.actual_song_position = playbackPosition + config.radio_sync.chunk_duration
                
                state.logger.debug("RadioClient", string.format("Played buffer chunk at position %.1fs", playbackPosition))
            else
                -- No chunk available - request emergency resync
                state.logger.warn("RadioClient", "Buffer underrun - requesting emergency resync")
                radioClient.requestEmergencyResync(state, "Buffer underrun")
                state.is_playing_audio = false
            end
        end
        
        -- Handle timer events for synchronized start
        local event = {os.pullEvent("timer")}
        if event[1] == "timer" and state.sync_delay > 0 then
            -- Time to start synchronized playback
            radioClient.startSynchronizedPlayback(state)
            state.sync_delay = 0
        end
        
        sleep(0.05) -- 50ms for smooth playback
    end
end

-- Get PRE-buffer system status for UI display
function radioClient.getBufferSystemStatus(state)
    if not state.sync_buffer then
        return {
            enabled = false,
            status = "Disabled"
        }
    end
    
    local bufferStatus = bufferManager.getBufferStatus(state.sync_buffer)
    
    return {
        enabled = state.sync_enabled,
        status = state.buffer_ready and "Ready" or "Buffering",
        buffer_health = state.buffer_health,
        buffered_duration = state.buffered_duration,
        active_chunks = bufferStatus and bufferStatus.active_chunks or 0,
        network_latency = state.network_latency * 1000, -- Convert to ms
        sync_session = state.current_sync_session,
        sync_ready = state.sync_ready
    }
end

return radioClient 