-- Radio Client feature for Bognesferga Radio
-- Allows connecting to and listening to radio stations

local radioProtocol = require("musicplayer.network.radio_protocol")
local radioUI = require("musicplayer.ui.layouts.radio")
local components = require("musicplayer.ui.components")

local radioClient = {}

function radioClient.init(systemModules)
    local state = {
        -- System modules
        system = systemModules.system,
        httpClient = systemModules.httpClient,
        speakerManager = systemModules.speakerManager,
        errorHandler = systemModules.errorHandler,
        logger = systemModules.logger,
        
        -- Radio client state
        tab = 1, -- 1 = Stations, 2 = Now Playing
        width = 0,
        height = 0,
        
        -- Station discovery
        scanning = false,
        scan_error = false,
        stations = {},
        selected_station = 1,
        last_scan_time = 0,
        
        -- Connection state
        connected_station = nil,
        current_station = nil,
        connection_status = "disconnected", -- disconnected, connecting, connected, error
        
        -- Playback state
        now_playing = nil,
        volume = 1.0,
        
        -- Network state
        protocol_available = false,
        listeners = {}
    }
    
    -- Initialize radio protocol
    state.protocol_available = radioProtocol.init(state.errorHandler)
    if not state.protocol_available then
        state.logger.warn("RadioClient", "No wireless modem found - radio features disabled")
    else
        state.logger.info("RadioClient", "Radio protocol initialized")
    end
    
    return state
end

function radioClient.run(state)
    state.logger.info("RadioClient", "Starting radio client")
    
    -- Check if radio is available
    if not state.protocol_available then
        radioClient.showNoModemError(state)
        return "menu"
    end
    
    -- Start background message handler
    local messageHandler = radioClient.startMessageHandler(state)
    
    while true do
        -- Update screen dimensions
        state.width, state.height = term.getSize()
        
        -- Draw UI
        radioUI.redrawScreen(state)
        
        -- Handle input
        local action = radioClient.handleInput(state)
        
        if action == "back_to_menu" then
            radioClient.cleanup(state)
            return "menu"
        elseif action == "refresh_stations" then
            radioClient.scanForStations(state)
        elseif action == "connect_station" then
            radioClient.connectToStation(state)
        elseif action == "disconnect_station" then
            radioClient.disconnectFromStation(state)
        elseif action == "redraw" then
            -- Continue loop to redraw
        end
    end
end

function radioClient.showNoModemError(state)
    components.clearScreen()
    
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.red)
    term.setCursorPos(1, 3)
    print("Radio Client Error")
    print()
    term.setTextColor(colors.white)
    print("No wireless modem detected!")
    print()
    print("To use radio features, you need:")
    print("• A wireless modem attached to this computer")
    print("• The modem must be on any side (top, bottom, left, right, front, back)")
    print()
    term.setTextColor(colors.yellow)
    print("How to add a wireless modem:")
    print("1. Craft a wireless modem (stone + ender pearl + redstone)")
    print("2. Right-click on any side of this computer while sneaking")
    print("3. Restart the radio client")
    print()
    term.setTextColor(colors.lightGray)
    print("Press any key to return to menu...")
    
    os.pullEvent("key")
end

function radioClient.scanForStations(state)
    if not state.protocol_available then
        return
    end
    
    state.logger.info("RadioClient", "Scanning for radio stations")
    state.scanning = true
    state.scan_error = false
    state.stations = {}
    state.last_scan_time = os.epoch("utc")
    
    -- Request station list from all hosts
    local success = radioProtocol.requestStationList()
    if not success then
        state.scan_error = true
        state.scanning = false
        state.logger.error("RadioClient", "Failed to send station discovery request")
        return
    end
    
    -- Wait for responses (non-blocking)
    local scanTimeout = 5 -- seconds
    local startTime = os.clock()
    local foundStations = {}
    
    while (os.clock() - startTime) < scanTimeout do
        local senderId, message, error = radioProtocol.receiveMessage(0.5)
        
        if senderId and message then
            if message.type == radioProtocol.MESSAGE_TYPES.STATION_LIST then
                -- Process station list
                if message.data and message.data.stations then
                    for _, station in ipairs(message.data.stations) do
                        station.host_id = senderId
                        table.insert(foundStations, station)
                    end
                end
            elseif message.type == radioProtocol.MESSAGE_TYPES.STATION_ANNOUNCE then
                -- Process individual station announcement
                local station = message.data
                station.host_id = senderId
                table.insert(foundStations, station)
            end
        end
        
        -- Allow UI updates during scan
        if math.random() < 0.3 then -- 30% chance to update UI
            radioUI.redrawScreen(state)
        end
    end
    
    state.stations = foundStations
    state.scanning = false
    state.selected_station = #state.stations > 0 and 1 or 0
    
    state.logger.info("RadioClient", "Scan complete: found " .. #state.stations .. " stations")
end

function radioClient.connectToStation(state)
    if not state.protocol_available or not state.stations or #state.stations == 0 or not state.selected_station then
        return
    end
    
    local station = state.stations[state.selected_station]
    if not station then
        return
    end
    
    state.logger.info("RadioClient", "Connecting to station: " .. station.name)
    state.connection_status = "connecting"
    
    -- Send join request
    local clientInfo = {
        name = radioProtocol.getComputerLabel(),
        id = radioProtocol.getComputerId(),
        capabilities = {"audio_playback"}
    }
    
    local success = radioProtocol.requestJoin(station.host_id, clientInfo)
    if not success then
        state.connection_status = "error"
        state.logger.error("RadioClient", "Failed to send join request")
        return
    end
    
    -- Wait for response
    local timeout = 10 -- seconds
    local startTime = os.clock()
    
    while (os.clock() - startTime) < timeout do
        local senderId, message, error = radioProtocol.receiveMessage(1)
        
        if senderId == station.host_id and message and message.type == radioProtocol.MESSAGE_TYPES.JOIN_RESPONSE then
            if message.data.accepted then
                state.connected_station = station.host_id
                state.current_station = message.data.station
                state.connection_status = "connected"
                state.tab = 2 -- Switch to Now Playing tab
                state.logger.info("RadioClient", "Successfully connected to station")
                return
            else
                state.connection_status = "error"
                state.logger.warn("RadioClient", "Connection rejected by station")
                return
            end
        end
    end
    
    state.connection_status = "error"
    state.logger.error("RadioClient", "Connection timeout")
end

function radioClient.disconnectFromStation(state)
    if not state.protocol_available or not state.connected_station then
        return
    end
    
    state.logger.info("RadioClient", "Disconnecting from station")
    
    -- Send leave request
    radioProtocol.requestLeave(state.connected_station)
    
    -- Reset connection state
    state.connected_station = nil
    state.current_station = nil
    state.connection_status = "disconnected"
    state.now_playing = nil
    state.tab = 1 -- Switch back to Stations tab
    
    -- Stop any playing audio
    state.speakerManager.stopAll()
end

function radioClient.startMessageHandler(state)
    -- This would ideally run in a coroutine, but ComputerCraft doesn't support true multithreading
    -- Instead, we'll handle messages during input polling
    return true
end

function radioClient.handleInput(state)
    while true do
        local event, param1, param2, param3 = os.pullEvent()
        
        -- Handle radio messages during input
        if event == "rednet_message" then
            radioClient.handleRadioMessage(state, param1, param2, param3)
        elseif event == "key" then
            local key = param1
            
            if key == keys.escape then
                return "back_to_menu"
            elseif key == keys.tab then
                state.tab = (state.tab % 2) + 1
                return "redraw"
            elseif key == keys.r and state.tab == 1 then
                return "refresh_stations"
            elseif key == keys.enter and state.tab == 1 then
                return "connect_station"
            elseif key == keys.d and state.tab == 2 and state.connected_station then
                return "disconnect_station"
            end
            
        elseif event == "mouse_click" or event == "monitor_touch" then
            local button, x, y
            if event == "mouse_click" then
                button, x, y = param1, param2, param3
            else
                button, x, y = 1, param2, param3
            end
            
            return radioClient.handleClick(state, x, y)
        end
    end
end

function radioClient.handleClick(state, x, y)
    -- Tab clicks
    if y == 3 then
        if x >= 3 and x <= 13 then -- Stations tab
            state.tab = 1
            return "redraw"
        elseif x >= 14 and x <= 27 then -- Now Playing tab
            state.tab = 2
            return "redraw"
        end
    end
    
    if state.tab == 1 then
        return radioClient.handleStationsClick(state, x, y)
    elseif state.tab == 2 then
        return radioClient.handleNowPlayingClick(state, x, y)
    end
    
    return nil
end

function radioClient.handleStationsClick(state, x, y)
    -- Station list clicks
    if state.stations and #state.stations > 0 and y >= 8 and y <= 15 then
        local stationIndex = y - 7
        if stationIndex <= #state.stations then
            state.selected_station = stationIndex
            return "connect_station"
        end
    end
    
    -- Button clicks
    local buttonY = state.height - 5
    if y == buttonY then
        if x >= 3 and x <= 12 then -- Refresh
            return "refresh_stations"
        elseif x >= 15 and x <= 28 then -- Connect/Disconnect
            if state.connected_station then
                return "disconnect_station"
            else
                return "connect_station"
            end
        elseif x >= 30 then -- Back to Menu
            return "back_to_menu"
        end
    end
    
    return nil
end

function radioClient.handleNowPlayingClick(state, x, y)
    local buttonY = state.height - 5
    if y == buttonY then
        if x >= 3 and x <= 15 and state.connected_station then -- Disconnect
            return "disconnect_station"
        elseif x >= 35 then -- Back to Stations
            state.tab = 1
            return "redraw"
        end
    end
    
    return nil
end

function radioClient.handleRadioMessage(state, senderId, message, protocol)
    if not state.connected_station or senderId ~= state.connected_station then
        return
    end
    
    if message.type == radioProtocol.MESSAGE_TYPES.SONG_UPDATE then
        -- Update now playing information
        state.now_playing = message.data
        state.logger.debug("RadioClient", "Received song update: " .. (message.data.name or "Unknown"))
        
        -- Start playing the new song
        if message.data.url then
            radioClient.playRadioSong(state, message.data)
        end
        
    elseif message.type == radioProtocol.MESSAGE_TYPES.SYNC_RESPONSE then
        -- Handle synchronization response
        if message.data.now_playing then
            state.now_playing = message.data.now_playing
            if message.data.now_playing.url then
                radioClient.playRadioSong(state, message.data.now_playing)
            end
        end
    end
end

function radioClient.playRadioSong(state, songInfo)
    -- This would integrate with the audio system to play the synchronized song
    state.logger.info("RadioClient", "Playing radio song: " .. (songInfo.name or "Unknown"))
    
    -- For now, just update the display
    -- In a full implementation, this would:
    -- 1. Download the audio stream
    -- 2. Synchronize playback timing with the host
    -- 3. Handle buffering and network issues
end

function radioClient.cleanup(state)
    if state.connected_station then
        radioClient.disconnectFromStation(state)
    end
    
    if state.protocol_available then
        radioProtocol.close()
    end
    
    state.logger.info("RadioClient", "Radio client cleanup complete")
end

return radioClient 