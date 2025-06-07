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
        
        -- Audio streaming
        audio_buffer = {},
        decoder = require("cc.audio.dfpwm").make_decoder(),
        volume = 1.5,
        
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
    if y == 14 and x >= 4 and x <= 24 then
        local sliderPos = x - 4
        local newVolume = (sliderPos / 20) * 3.0
        state.volume = math.max(0, math.min(3.0, newVolume))
        state.speakerManager.setVolume(speakers, state.volume)
        state.logger.info("RadioClient", "Volume set to " .. state.volume)
        return
    end
end

-- STATION MANAGEMENT
function radioClient.scanForStations(state)
    if not state.protocol_available then
        return
    end
    
    if state.scanning then
        return -- Already scanning
    end
    
    state.scanning = true
    state.scan_start_time = os.clock()
    state.logger.info("RadioClient", "Starting station scan...")
    
    -- Open broadcast channel and send discovery request
    radioProtocol.openBroadcastChannel()
    
    local discoveryRequest = {
        type = "discovery_request",
        client_id = os.getComputerID(),
        timestamp = os.epoch("utc")
    }
    
    radioProtocol.broadcast(discoveryRequest)
    
    -- Reset stations list for new scan
    state.stations = {}
end

function radioClient.connectToStation(state, station, speakers)
    if state.connection_status == "connecting" then
        return
    end
    
    state.connection_status = "connecting"
    state.connection_error = nil
    state.connecting_to_station = station
    state.connection_start_time = os.clock()
    state.logger.info("RadioClient", "Connecting to station: " .. station.station_name)
    
    -- Send join request (non-blocking)
    local clientId = os.getComputerID()
    local stationChannel = radioProtocol.getStationChannel(station.station_id)
    local clientChannel = radioProtocol.getClientChannel(clientId)
    
    -- Open channels
    radioProtocol.openChannel(stationChannel)
    radioProtocol.openChannel(clientChannel)
    
    -- Send join request
    local joinRequest = {
        type = "join_request",
        listener_id = clientId,
        timestamp = os.epoch("utc")
    }
    
    local protocolMessage = {
        protocol_version = "1.0",
        timestamp = os.epoch("utc"),
        data = joinRequest
    }
    
    -- Get modem and send request
    local modem = peripheral.find("modem")
    if modem then
        modem.transmit(stationChannel, clientChannel, protocolMessage)
        state.logger.info("RadioClient", "Join request sent to station " .. station.station_id)
    else
        state.connection_status = "error"
        state.connection_error = "No modem available"
        state.logger.error("RadioClient", "No modem available for connection")
    end
end

function radioClient.disconnectFromStation(state)
    if state.connected_station then
        -- Send leave request (non-blocking)
        local clientId = os.getComputerID()
        local stationChannel = radioProtocol.getStationChannel(state.connected_station.station_id)
        
        local leaveRequest = {
            type = "leave_request",
            listener_id = clientId,
            timestamp = os.epoch("utc")
        }
        
        local protocolMessage = {
            protocol_version = "1.0",
            timestamp = os.epoch("utc"),
            data = leaveRequest
        }
        
        -- Get modem and send request
        local modem = peripheral.find("modem")
        if modem then
            modem.transmit(stationChannel, radioProtocol.getClientChannel(clientId), protocolMessage)
            state.logger.info("RadioClient", "Leave request sent to station: " .. state.connected_station.station_name)
        end
        
        state.logger.info("RadioClient", "Disconnected from station: " .. state.connected_station.station_name)
    end
    
    state.connection_status = "disconnected"
    state.connected_station = nil
    state.connecting_to_station = nil
    state.connection_error = nil
    state.now_playing = nil
    state.playing = false
    state.playlist = {}
    state.current_song_index = 0
    state.audio_buffer = {}
end

-- AUDIO LOOP (synchronized streaming)
function radioClient.audioLoop(state, speakers)
    while true do
        if state.connection_status == "connected" and #state.audio_buffer > 0 then
            -- Play buffered audio
            local audioData = table.remove(state.audio_buffer, 1)
            
            while not state.speakerManager.playAudio(speakers, audioData) do
                os.pullEvent("speaker_audio_empty")
            end
        else
            sleep(0.05) -- Small delay when no audio to play
        end
    end
end

-- NETWORK LOOP (receive synchronized data)
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
        
        -- Send periodic ping to maintain connection
        if state.connection_status == "connected" and state.connected_station then
            if (currentTime - state.last_ping_time) >= state.ping_interval then
                radioProtocol.sendPing(state.connected_station.station_id)
                state.last_ping_time = currentTime
            end
        end
        
        -- Handle incoming network messages
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        
        if message and type(message) == "table" then
            -- Handle station discovery responses
            if state.scanning and radioProtocol.isValidMessage(message) then
                local data = radioProtocol.extractMessageData(message)
                if data and data.type == "station_announcement" then
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
            end
            
            -- Handle connection responses
            if state.connection_status == "connecting" and state.connecting_to_station then
                local clientId = os.getComputerID()
                local clientChannel = radioProtocol.getClientChannel(clientId)
                
                if channel == clientChannel and radioProtocol.isValidMessage(message) then
                    local data = radioProtocol.extractMessageData(message)
                    if data and data.type == "join_response" then
                        if data.success then
                            state.connection_status = "connected"
                            state.connected_station = state.connecting_to_station
                            state.connecting_to_station = nil
                            
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
            end
            
            -- Handle other network messages
            radioClient.handleNetworkMessage(state, message)
        end
        
        sleep(0.1)
    end
end

function radioClient.handleNetworkMessage(state, message)
    -- Extract data from protocol message
    local data = radioProtocol.extractMessageData(message)
    if not data then
        return
    end
    
    if data.type == "audio_chunk" then
        -- Buffer audio data for synchronized playback
        if data.audio_data then
            table.insert(state.audio_buffer, data.audio_data)
            
            -- Limit buffer size to prevent memory issues
            if #state.audio_buffer > 10 then
                table.remove(state.audio_buffer, 1)
            end
        end
        
    elseif data.type == "song_change" then
        -- Update current song
        state.now_playing = data.now_playing
        state.current_song_index = data.current_song_index
        state.playing = data.playing
        
        state.logger.info("RadioClient", "Song changed: " .. (state.now_playing and state.now_playing.name or "None"))
        
    elseif data.type == "playback_state" then
        -- Update playback state
        state.playing = data.playing
        state.now_playing = data.now_playing
        
    elseif data.type == "playlist_update" then
        -- Update playlist
        state.playlist = data.playlist
        state.current_song_index = data.current_song_index
        
        state.logger.info("RadioClient", "Playlist updated: " .. #state.playlist .. " songs")
        
    elseif data.type == "broadcast_end" then
        -- Host ended broadcast
        radioClient.disconnectFromStation(state)
        state.connection_status = "error"
        state.connection_error = "Host ended broadcast"
        
        state.logger.info("RadioClient", "Host ended broadcast")
        
    elseif data.type == "ping_response" then
        -- Keep-alive response received
        state.last_ping_response = os.epoch("utc")
    end
end

-- CLEANUP
function radioClient.cleanup(state)
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

return radioClient 