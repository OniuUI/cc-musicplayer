-- Radio Client feature for Bognesferga Radio
-- Allows listening to network radio stations with synchronized streaming

local radioProtocol = require("musicplayer/network/radio_protocol")

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
        
        -- Synchronization state (NEW - more forgiving)
        current_playback_session = nil, -- Track current session from host
        last_sync_time = 0,
        sync_timeout = 60, -- seconds - much longer timeout, only for detecting truly dead hosts
        host_playback_start_time = 0,
        client_start_offset = 0, -- Offset to sync with host timing
        sync_warnings = 0, -- Count sync warnings before taking action
        
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
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, 9)
        term.write("♪ No song playing")
        term.setCursorPos(3, 10)
        term.write("  Waiting for host to start music")
    end
    
    -- Volume control (local only)
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 13)
    term.write("Local Volume: ")
    
    local volumePercent = math.floor((state.volume / 3.0) * 100)
    term.setTextColor(colors.white)
    term.write(volumePercent .. "%")
    
    -- Volume slider
    term.setCursorPos(3, 14)
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
    
    -- Station playlist (if available)
    if #state.playlist > 0 then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.yellow)
        term.setCursorPos(3, 16)
        term.write("Station Playlist:")
        
        local maxShow = math.min(5, #state.playlist)
        for i = 1, maxShow do
            local song = state.playlist[i]
            local y = 16 + i
            
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
            term.setCursorPos(3, 22)
            term.write("... and " .. (#state.playlist - 5) .. " more songs")
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
    -- Volume slider click
    if y == 11 and x >= 4 and x <= 24 and not state.muted then
        local sliderPos = x - 4
        local newVolume = (sliderPos / 20) * 3.0
        state.volume = math.max(0, math.min(3.0, newVolume))
        state.logger.info("RadioClient", "Volume set to " .. state.volume)
        return
    end
    
    -- Mute/Unmute button
    if y == 11 and x >= 25 and x <= 36 then
        state.muted = not state.muted
        state.logger.info("RadioClient", "Audio " .. (state.muted and "muted" or "unmuted"))
        return
    end
    
    -- Station controls
    if y == 13 then
        if x >= 3 and x <= 12 then -- Connect/Disconnect
            if state.connected then
                radioClient.disconnect(state)
            else
                radioClient.connectToStation(state, speakers)
            end
        elseif x >= 14 and x <= 22 then -- Refresh
            radioClient.refreshStations(state)
        end
    end
end

-- STATION MANAGEMENT
function radioClient.scanForStations(state)
    state.logger.info("RadioClient", "Scanning for radio stations...")
    
    state.scanning = true
    state.scan_start_time = os.clock()
    state.stations = {}
    
    -- Send discovery request
    local discoveryRequest = {
        type = "discovery_request",
        client_id = os.getComputerID(),
        timestamp = os.epoch("utc")
    }
    
    radioProtocol.broadcast(discoveryRequest)
    state.logger.info("RadioClient", "Discovery request sent")
end

function radioClient.connectToStation(state, station)
    if not station then
        return
    end
    
    state.logger.info("RadioClient", "Connecting to station: " .. station.station_name)
    
    state.connection_status = "connecting"
    state.connecting_to_station = station
    state.connection_start_time = os.clock()
    state.connection_error = nil
    
    -- Send join request to station
    local joinRequest = {
        type = "join_request",
        listener_id = os.getComputerID(),
        timestamp = os.epoch("utc")
    }
    
    local stationChannel = radioProtocol.getStationChannel(station.station_id)
    local clientChannel = radioProtocol.getClientChannel(os.getComputerID())
    
    -- Open our client channel to receive response
    radioProtocol.openChannel(clientChannel)
    
    -- Send join request
    radioProtocol.sendToChannel(stationChannel, joinRequest)
    
    state.logger.info("RadioClient", "Join request sent to station " .. station.station_id)
end

function radioClient.disconnect(state)
    if not state.connected or not state.connected_station_id then
        return
    end
    
    state.logger.info("RadioClient", "Disconnecting from station")
    
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
    state.sync_warnings = 0
    
    state.logger.info("RadioClient", "Disconnected from station")
end

-- AUDIO LOOP (handle local audio streaming) - GENTLE SYNC
function radioClient.audioLoop(state, speakers)
    while true do
        -- Handle local audio streaming (when not using network audio)
        if state.playing and state.now_playing and not state.is_playing_audio then
            local thisnowplayingid = state.now_playing.id
            
            if state.playing_id ~= thisnowplayingid then
                state.playing_id = thisnowplayingid
                state.last_download_url = state.api_base_url .. "?v=" .. state.version .. "&id=" .. textutils.urlEncode(state.playing_id)
                state.playing_status = 0
                state.needs_next_chunk = 1

                http.request({url = state.last_download_url, binary = true})
                state.is_loading = true
                state.logger.info("RadioClient", "Requesting local audio stream for: " .. state.now_playing.name)

                os.queueEvent("redraw_screen")
                os.queueEvent("audio_update")
                
            elseif state.playing_status == 1 and state.needs_next_chunk == 1 then
                -- Play local audio stream
                while true do
                    local chunk = state.player_handle.read(state.size)
                    if not chunk then
                        -- Song finished naturally
                        state.logger.info("RadioClient", "Local song finished")
                        
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
                
                        state.buffer = state.decoder(chunk)
                        
                        -- Play audio locally (only if not muted)
                        if not state.muted then
                            local fn = {}
                            for i, speaker in ipairs(speakers) do 
                                fn[i] = function()
                                    local name = peripheral.getName(speaker)
                                    local playVolume = state.volume
                                    
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
                            
                            state.is_playing_audio = true
                        else
                            -- Still process audio timing even when muted
                            sleep(0.05)
                            state.is_playing_audio = true
                        end
                        
                        -- Exit if playback stopped
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

-- NETWORK LOOP (radio communication) - FORGIVING SYNC
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
                state.logger.error("RadioClient", "Connection timeout")
                os.queueEvent("redraw_screen")
            end
        end
        
        -- Send periodic ping to host (keep-alive)
        if state.connected and (currentTime - state.last_ping_time) >= state.ping_interval then
            radioClient.sendPing(state)
            state.last_ping_time = currentTime
        end
        
        -- FORGIVING sync timeout check - only warn, don't disconnect immediately
        if state.connected and state.last_sync_time > 0 then
            local timeSinceSync = currentTime - state.last_sync_time
            
            if timeSinceSync > 30 and state.sync_warnings == 0 then
                -- First warning at 30 seconds
                state.logger.warn("RadioClient", "No sync from host for 30 seconds - connection may be unstable")
                state.sync_warnings = 1
            elseif timeSinceSync > 60 and state.sync_warnings == 1 then
                -- Second warning at 60 seconds
                state.logger.warn("RadioClient", "No sync from host for 60 seconds - host may be unresponsive")
                state.sync_warnings = 2
            elseif timeSinceSync > state.sync_timeout and state.sync_warnings >= 2 then
                -- Only disconnect after multiple warnings and very long timeout
                state.logger.error("RadioClient", "Host completely unresponsive for " .. state.sync_timeout .. " seconds - disconnecting")
                radioClient.disconnect(state)
                return "disconnected"
            end
        end
        
        -- Handle incoming network messages
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        
        if message and type(message) == "table" then
            if radioProtocol.isValidMessage(message) then
                local data = radioProtocol.extractMessageData(message)
                
                -- Handle station discovery responses
                if state.scanning and data and data.type == "station_announcement" then
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
                    
                    if channel == clientChannel and data and data.type == "join_response" then
                        if data.success then
                            state.connection_status = "connected"
                            state.connected = true
                            state.connected_station_id = state.connecting_to_station.station_id
                            state.connected_station = state.connecting_to_station
                            state.connecting_to_station = nil
                            state.last_sync_time = currentTime
                            state.sync_warnings = 0
                            
                            -- Update state from host response
                            if data.now_playing then
                                state.now_playing = data.now_playing
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
                    -- Reset warnings on any valid message from our host
                    if state.sync_warnings > 0 then
                        state.logger.info("RadioClient", "Host communication restored")
                        state.sync_warnings = 0
                    end
                    
                    radioClient.handleNetworkMessage(state, data, replyChannel)
                end
            end
        end
        
        sleep(0.1)
    end
end

function radioClient.handleNetworkMessage(state, data, replyChannel)
    if not data or not data.type then
        return
    end
    
    local currentTime = os.epoch("utc") / 1000
    
    if data.type == "song_change" then
        state.logger.info("RadioClient", "Host changed song: " .. (data.now_playing and data.now_playing.name or "Unknown"))
        
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
        
        if state.playing and state.now_playing then
            state.needs_next_chunk = 1
            state.decoder = require("cc.audio.dfpwm").make_decoder()
            state.playing_id = nil -- Force new download
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
            -- Stop speakers when host pauses
            local speakers = state.speakerManager.getRawSpeakers()
            for _, speaker in ipairs(speakers) do
                speaker.stop()
            end
            state.is_playing_audio = false
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
        
    elseif data.type == "audio_chunk" then
        -- Handle audio streaming from host
        if data.audio_data and state.playing and not state.muted then
            -- Only play if we're supposed to be playing and session matches
            if data.playback_session == state.current_playback_session then
                radioClient.playAudioChunk(state, data.audio_data)
            end
        end
        
    elseif data.type == "sync_status" then
        -- Use the new gentle sync system
        radioClient.handleSyncStatus(state, data)
        os.queueEvent("redraw_screen")
        
    elseif data.type == "broadcast_end" then
        state.logger.info("RadioClient", "Host ended broadcast")
        
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
        -- Keep-alive response from host
        state.last_sync_time = currentTime
        state.sync_warnings = 0 -- Reset warnings on ping response
    end
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

function radioClient.handleSyncStatus(state, data)
    local currentTime = os.epoch("utc") / 1000
    state.last_sync_time = currentTime
    
    -- Update host timing information
    state.host_playback_start_time = data.playback_start_time or 0
    
    -- Check if this is a new playback session
    if data.playback_session and data.playback_session ~= state.current_playback_session then
        state.logger.info("RadioClient", "New playback session detected: " .. data.playback_session)
        
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
        
        -- Update session
        state.current_playback_session = data.playback_session
        state.is_playing_audio = false
        
        -- Reset audio state for new session
        if data.playing and data.now_playing then
            state.now_playing = data.now_playing
            state.playing = true
            state.needs_next_chunk = 1
            state.decoder = require("cc.audio.dfpwm").make_decoder()
            state.playing_id = nil -- Force new download
            
            state.logger.info("RadioClient", "Starting new session: " .. data.now_playing.name)
            os.queueEvent("audio_update")
        end
    end
    
    -- Gentle synchronization - only update if significantly different
    if data.now_playing and state.now_playing then
        if data.now_playing.id ~= state.now_playing.id then
            state.logger.info("RadioClient", "Song change detected via sync")
            state.now_playing = data.now_playing
            state.current_song_index = data.current_song_index or 1
            
            -- Gently restart audio for new song
            if state.player_handle then
                state.player_handle.close()
                state.player_handle = nil
            end
            
            state.playing_id = nil
            state.needs_next_chunk = 1
            os.queueEvent("audio_update")
        end
    end
    
    -- Update playback state gently
    if data.playing ~= state.playing then
        state.logger.info("RadioClient", "Playback state sync: " .. (data.playing and "playing" or "paused"))
        state.playing = data.playing
        
        if not state.playing then
            -- Pause - stop speakers but don't disconnect
            local speakers = state.speakerManager.getRawSpeakers()
            for _, speaker in ipairs(speakers) do
                speaker.stop()
            end
            state.is_playing_audio = false
        end
    end
    
    -- Update playlist if provided
    if data.playlist and type(data.playlist) == "table" then
        state.playlist = data.playlist
        state.current_song_index = data.current_song_index or 1
    end
    
    -- Reset sync warnings since we got a good sync
    state.sync_warnings = 0
    
    state.logger.info("RadioClient", "Gentle sync completed - Session: " .. (state.current_playback_session or "none"))
end

function radioClient.playAudioChunk(state, audioData)
    -- Simple audio chunk playback for network streaming
    if not audioData or state.muted then
        return
    end
    
    local speakers = state.speakerManager.getRawSpeakers()
    if #speakers == 0 then
        return
    end
    
    -- Play audio chunk on all speakers
    for _, speaker in ipairs(speakers) do
        local success = speaker.playAudio(audioData, state.volume)
        if success then
            state.is_playing_audio = true
        end
    end
end

function radioClient.sendPing(state)
    if not state.connected or not state.connected_station_id then
        return
    end
    
    local pingMessage = {
        type = "listener_ping",
        listener_id = os.getComputerID(),
        timestamp = os.epoch("utc")
    }
    
    local stationChannel = radioProtocol.getStationChannel(state.connected_station_id)
    radioProtocol.sendToChannel(stationChannel, pingMessage)
end

return radioClient 