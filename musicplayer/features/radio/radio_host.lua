-- Radio Host feature for Bognesferga Radio
-- Allows hosting and managing radio stations

local radioProtocol = require("musicplayer.network.radio_protocol")
local components = require("musicplayer.ui.components")
local themes = require("musicplayer.ui.themes")

local radioHost = {}

function radioHost.init(systemModules)
    local state = {
        -- System modules
        system = systemModules.system,
        httpClient = systemModules.httpClient,
        speakerManager = systemModules.speakerManager,
        errorHandler = systemModules.errorHandler,
        logger = systemModules.logger,
        
        -- Host state
        width = 0,
        height = 0,
        
        -- Station configuration
        station_name = "",
        station_description = "",
        station_configured = false,
        
        -- Broadcasting state
        is_broadcasting = false,
        listeners = {},
        max_listeners = 10,
        
        -- Playlist management
        playlist = {},
        current_song_index = 0,
        now_playing = nil,
        
        -- Playback state
        playing = false,
        volume = 1.0,
        loop_mode = "playlist", -- off, playlist, song
        
        -- Network state
        protocol_available = false,
        last_announce_time = 0,
        announce_interval = 30 -- seconds
    }
    
    -- Initialize radio protocol
    state.protocol_available = radioProtocol.init(state.errorHandler)
    if not state.protocol_available then
        state.logger.warn("RadioHost", "No wireless modem found - radio hosting disabled")
    else
        state.logger.info("RadioHost", "Radio protocol initialized for hosting")
    end
    
    return state
end

function radioHost.run(state)
    state.logger.info("RadioHost", "Starting radio host")
    
    -- Check if radio is available
    if not state.protocol_available then
        radioHost.showNoModemError(state)
        return "menu"
    end
    
    -- Setup station if not configured
    if not state.station_configured then
        local result = radioHost.setupStation(state)
        if result == "back_to_menu" then
            return "menu"
        end
    end
    
    -- Start message handler
    radioHost.startMessageHandler(state)
    
    while true do
        -- Update screen dimensions
        state.width, state.height = term.getSize()
        
        -- Handle periodic tasks
        radioHost.handlePeriodicTasks(state)
        
        -- Draw UI
        radioHost.drawHostInterface(state)
        
        -- Handle input
        local action = radioHost.handleInput(state)
        
        if action == "back_to_menu" then
            radioHost.cleanup(state)
            return "menu"
        elseif action == "start_broadcast" then
            radioHost.startBroadcast(state)
        elseif action == "stop_broadcast" then
            radioHost.stopBroadcast(state)
        elseif action == "add_song" then
            radioHost.addSongToPlaylist(state)
        elseif action == "remove_song" then
            radioHost.removeSongFromPlaylist(state)
        elseif action == "play_pause" then
            radioHost.togglePlayback(state)
        elseif action == "next_song" then
            radioHost.nextSong(state)
        elseif action == "redraw" then
            -- Continue loop to redraw
        end
    end
end

function radioHost.showNoModemError(state)
    components.clearScreen()
    
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.red)
    term.setCursorPos(1, 3)
    print("Radio Host Error")
    print()
    term.setTextColor(colors.white)
    print("No wireless modem detected!")
    print()
    print("To host radio stations, you need:")
    print("• A wireless modem attached to this computer")
    print("• The modem must be on any side (top, bottom, left, right, front, back)")
    print()
    term.setTextColor(colors.yellow)
    print("How to add a wireless modem:")
    print("1. Craft a wireless modem (stone + ender pearl + redstone)")
    print("2. Right-click on any side of this computer while sneaking")
    print("3. Restart the radio host")
    print()
    term.setTextColor(colors.lightGray)
    print("Press any key to return to menu...")
    
    os.pullEvent("key")
end

function radioHost.setupStation(state)
    components.clearScreen()
    
    local theme = themes.getCurrent()
    
    -- Draw header
    term.setBackgroundColor(theme.colors.header_bg)
    term.setCursorPos(1, 1)
    term.clearLine()
    term.setTextColor(theme.colors.text_primary)
    term.setCursorPos(3, 1)
    term.write("🎙️ Radio Station Setup")
    
    term.setBackgroundColor(theme.colors.background)
    term.setTextColor(theme.colors.text_primary)
    term.setCursorPos(1, 3)
    print("Welcome to Radio Station Setup!")
    print()
    print("Let's configure your radio station:")
    print()
    
    -- Get station name
    term.setTextColor(theme.colors.text_accent)
    term.write("Station Name: ")
    term.setTextColor(theme.colors.text_primary)
    state.station_name = read()
    
    if state.station_name == "" then
        state.station_name = "Radio Station " .. radioProtocol.getComputerId()
    end
    
    print()
    
    -- Get station description
    term.setTextColor(theme.colors.text_accent)
    term.write("Description (optional): ")
    term.setTextColor(theme.colors.text_primary)
    state.station_description = read()
    
    if state.station_description == "" then
        state.station_description = "A music radio station"
    end
    
    print()
    print()
    term.setTextColor(theme.colors.text_success)
    print("Station configured successfully!")
    print("Name: " .. state.station_name)
    print("Description: " .. state.station_description)
    print()
    term.setTextColor(theme.colors.text_secondary)
    print("Press any key to continue...")
    
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
    local theme = themes.getCurrent()
    local playlistY = 13
    
    term.setTextColor(theme.colors.text_accent)
    term.setCursorPos(3, playlistY)
    term.write("📋 Playlist (" .. #state.playlist .. " songs):")
    
    if #state.playlist == 0 then
        term.setTextColor(theme.colors.text_disabled)
        term.setCursorPos(3, playlistY + 2)
        term.write("No songs in playlist. Add songs to start broadcasting.")
    else
        local maxSongs = math.min(5, #state.playlist)
        for i = 1, maxSongs do
            local song = state.playlist[i]
            local y = playlistY + 1 + i
            local isPlaying = (i == state.current_song_index)
            
            if isPlaying then
                term.setTextColor(theme.colors.playing)
                term.setCursorPos(3, y)
                term.write("▶ ")
            else
                term.setTextColor(theme.colors.text_secondary)
                term.setCursorPos(3, y)
                term.write("  ")
            end
            
            term.setTextColor(isPlaying and theme.colors.text_primary or theme.colors.text_secondary)
            term.write(song.name or "Unknown Song")
        end
        
        if #state.playlist > maxSongs then
            term.setTextColor(theme.colors.text_disabled)
            term.setCursorPos(3, playlistY + 1 + maxSongs + 1)
            term.write("... and " .. (#state.playlist - maxSongs) .. " more songs")
        end
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
            else
                button, x, y = 1, param2, param3
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
        state.logger.warn("RadioHost", "Cannot start broadcast: playlist is empty")
        return
    end
    
    state.logger.info("RadioHost", "Starting radio broadcast")
    state.is_broadcasting = true
    
    -- Start playing if not already playing
    if not state.playing then
        radioHost.startPlayback(state)
    end
    
    -- Announce station
    radioHost.announceStation(state)
end

function radioHost.stopBroadcast(state)
    state.logger.info("RadioHost", "Stopping radio broadcast")
    state.is_broadcasting = false
    
    -- Disconnect all listeners
    for _, listenerId in ipairs(state.listeners) do
        radioProtocol.sendMessage(listenerId, radioProtocol.MESSAGE_TYPES.SONG_UPDATE, {
            type = "station_offline"
        })
    end
    
    state.listeners = {}
end

function radioHost.addSongToPlaylist(state)
    -- For now, this is a placeholder - in a full implementation,
    -- this would integrate with the YouTube search system
    components.clearScreen()
    
    term.setTextColor(colors.white)
    term.setCursorPos(1, 3)
    print("Add Song to Playlist")
    print()
    print("Enter song name (or YouTube search term):")
    
    local songName = read()
    if songName and songName ~= "" then
        local song = {
            name = songName,
            artist = "Unknown Artist",
            url = "placeholder_url",
            duration = "3:30"
        }
        
        table.insert(state.playlist, song)
        state.logger.info("RadioHost", "Added song to playlist: " .. songName)
    end
end

function radioHost.removeSongFromPlaylist(state)
    if #state.playlist == 0 then
        return
    end
    
    -- Remove the last song for simplicity
    local removedSong = table.remove(state.playlist)
    state.logger.info("RadioHost", "Removed song from playlist: " .. (removedSong.name or "Unknown"))
    
    -- Adjust current song index if necessary
    if state.current_song_index > #state.playlist then
        state.current_song_index = math.max(1, #state.playlist)
    end
end

function radioHost.togglePlayback(state)
    if state.playing then
        radioHost.pausePlayback(state)
    else
        radioHost.startPlayback(state)
    end
end

function radioHost.startPlayback(state)
    if #state.playlist == 0 then
        return
    end
    
    if state.current_song_index == 0 then
        state.current_song_index = 1
    end
    
    state.playing = true
    state.now_playing = state.playlist[state.current_song_index]
    
    state.logger.info("RadioHost", "Started playback: " .. (state.now_playing.name or "Unknown"))
    
    -- Broadcast to listeners
    if state.is_broadcasting then
        radioHost.broadcastSongUpdate(state)
    end
end

function radioHost.pausePlayback(state)
    state.playing = false
    state.logger.info("RadioHost", "Paused playback")
end

function radioHost.nextSong(state)
    if #state.playlist == 0 then
        return
    end
    
    state.current_song_index = state.current_song_index + 1
    if state.current_song_index > #state.playlist then
        if state.loop_mode == "playlist" then
            state.current_song_index = 1
        else
            state.playing = false
            state.now_playing = nil
            return
        end
    end
    
    state.now_playing = state.playlist[state.current_song_index]
    state.logger.info("RadioHost", "Next song: " .. (state.now_playing.name or "Unknown"))
    
    -- Broadcast to listeners
    if state.is_broadcasting then
        radioHost.broadcastSongUpdate(state)
    end
end

function radioHost.handleRadioMessage(state, senderId, message, protocol)
    if message.type == radioProtocol.MESSAGE_TYPES.STATION_DISCOVERY then
        -- Respond with station info
        radioHost.respondToDiscovery(state, senderId)
        
    elseif message.type == radioProtocol.MESSAGE_TYPES.JOIN_REQUEST then
        -- Handle join request
        radioHost.handleJoinRequest(state, senderId, message.data)
        
    elseif message.type == radioProtocol.MESSAGE_TYPES.LEAVE_REQUEST then
        -- Handle leave request
        radioHost.handleLeaveRequest(state, senderId)
        
    elseif message.type == radioProtocol.MESSAGE_TYPES.SYNC_REQUEST then
        -- Handle sync request
        radioHost.handleSyncRequest(state, senderId)
    end
end

function radioHost.respondToDiscovery(state, requesterId)
    if not state.is_broadcasting then
        return
    end
    
    local stationInfo = {
        {
            id = radioProtocol.getComputerId(),
            name = state.station_name,
            description = state.station_description,
            listeners = #state.listeners,
            now_playing = state.now_playing
        }
    }
    
    radioProtocol.sendStationList(requesterId, stationInfo)
end

function radioHost.handleJoinRequest(state, clientId, clientInfo)
    if not state.is_broadcasting then
        radioProtocol.respondToJoin(clientId, false, {reason = "Station not broadcasting"})
        return
    end
    
    if #state.listeners >= state.max_listeners then
        radioProtocol.respondToJoin(clientId, false, {reason = "Station full"})
        return
    end
    
    -- Accept the client
    table.insert(state.listeners, clientId)
    
    local stationInfo = {
        name = state.station_name,
        description = state.station_description,
        now_playing = state.now_playing
    }
    
    radioProtocol.respondToJoin(clientId, true, stationInfo)
    state.logger.info("RadioHost", "Client connected: " .. (clientInfo.name or clientId))
end

function radioHost.handleLeaveRequest(state, clientId)
    for i, listenerId in ipairs(state.listeners) do
        if listenerId == clientId then
            table.remove(state.listeners, i)
            state.logger.info("RadioHost", "Client disconnected: " .. clientId)
            break
        end
    end
end

function radioHost.handleSyncRequest(state, clientId)
    local syncInfo = {
        now_playing = state.now_playing,
        playing = state.playing,
        timestamp = os.epoch("utc")
    }
    
    radioProtocol.respondToSync(clientId, syncInfo)
end

function radioHost.broadcastSongUpdate(state)
    if #state.listeners == 0 then
        return
    end
    
    radioProtocol.broadcastSongUpdate(state.listeners, state.now_playing)
end

function radioHost.announceStation(state)
    if not state.is_broadcasting then
        return
    end
    
    local stationInfo = {
        id = radioProtocol.getComputerId(),
        name = state.station_name,
        description = state.station_description,
        listeners = #state.listeners,
        now_playing = state.now_playing
    }
    
    radioProtocol.announceStation(stationInfo)
    state.last_announce_time = os.epoch("utc")
end

function radioHost.handlePeriodicTasks(state)
    local currentTime = os.epoch("utc")
    
    -- Periodic station announcements
    if state.is_broadcasting and (currentTime - state.last_announce_time) > (state.announce_interval * 1000) then
        radioHost.announceStation(state)
    end
end

function radioHost.cleanup(state)
    if state.is_broadcasting then
        radioHost.stopBroadcast(state)
    end
    
    if state.protocol_available then
        radioProtocol.close()
    end
    
    state.logger.info("RadioHost", "Radio host cleanup complete")
end

return radioHost 