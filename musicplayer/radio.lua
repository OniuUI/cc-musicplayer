-- Network radio module for synchronized playback
local config = require("musicplayer.config")
local network = require("musicplayer.network")
local audio = require("musicplayer.audio")

local radio = {}

-- Radio protocols
local RADIO_PROTOCOL = "bognesferga_radio"
local STATION_PROTOCOL = "radio_station"

function radio.initClient()
    return {
        mode = "client",
        connected_station = nil,
        station_list = {},
        selected_station = 1,
        is_scanning = false,
        last_scan = 0,
        current_song = nil,
        sync_offset = 0,
        connection_status = "disconnected"
    }
end

function radio.initHost(station_name)
    return {
        mode = "host",
        station_name = station_name or "Unnamed Station",
        clients = {},
        current_song = nil,
        song_start_time = 0,
        playlist = {},
        current_track = 1,
        is_playing = false,
        volume = config.default_volume
    }
end

function radio.startClient(radioState)
    -- Open rednet on any available modem
    local modem = peripheral.find("modem")
    if not modem then
        return false, "No modem found! Please attach a wireless modem."
    end
    
    rednet.open(peripheral.getName(modem))
    radioState.connection_status = "scanning"
    return true, "Rednet opened successfully"
end

function radio.startHost(radioState)
    -- Open rednet and host the station
    local modem = peripheral.find("modem")
    if not modem then
        return false, "No modem found! Please attach a wireless modem."
    end
    
    rednet.open(peripheral.getName(modem))
    rednet.host(STATION_PROTOCOL, radioState.station_name)
    radioState.connection_status = "hosting"
    return true, "Radio station '" .. radioState.station_name .. "' is now broadcasting!"
end

function radio.scanForStations(radioState)
    if radioState.mode ~= "client" then return end
    
    radioState.is_scanning = true
    radioState.station_list = {}
    
    -- Look for radio stations
    local stations = {rednet.lookup(STATION_PROTOCOL)}
    
    for _, stationId in ipairs(stations) do
        -- Request station info
        rednet.send(stationId, {type = "info_request"}, RADIO_PROTOCOL)
    end
    
    radioState.last_scan = os.clock()
    radioState.is_scanning = false
end

function radio.connectToStation(radioState, stationId)
    if radioState.mode ~= "client" then return false end
    
    radioState.connected_station = stationId
    radioState.connection_status = "connecting"
    
    -- Send connection request
    rednet.send(stationId, {
        type = "connect",
        client_id = os.getComputerID()
    }, RADIO_PROTOCOL)
    
    return true
end

function radio.disconnectFromStation(radioState)
    if radioState.mode ~= "client" or not radioState.connected_station then return end
    
    -- Send disconnect message
    rednet.send(radioState.connected_station, {
        type = "disconnect",
        client_id = os.getComputerID()
    }, RADIO_PROTOCOL)
    
    radioState.connected_station = nil
    radioState.connection_status = "disconnected"
    radioState.current_song = nil
    
    -- Stop any playing audio
    audio.stopAudio()
end

function radio.handleClientMessages(radioState)
    if radioState.mode ~= "client" then return end
    
    local senderId, message, protocol = rednet.receive(RADIO_PROTOCOL, 0.1)
    if not senderId or not message then return end
    
    if message.type == "info_response" then
        -- Add station to list
        local stationInfo = {
            id = senderId,
            name = message.station_name,
            current_song = message.current_song,
            listeners = message.listener_count
        }
        
        -- Check if station already exists in list
        local exists = false
        for i, station in ipairs(radioState.station_list) do
            if station.id == senderId then
                radioState.station_list[i] = stationInfo
                exists = true
                break
            end
        end
        
        if not exists then
            table.insert(radioState.station_list, stationInfo)
        end
        
    elseif message.type == "connect_response" then
        if message.success then
            radioState.connection_status = "connected"
            radioState.current_song = message.current_song
            radioState.sync_offset = message.sync_offset or 0
            
            -- Start playing if there's a current song
            if radioState.current_song then
                radio.startSyncedPlayback(radioState)
            end
        else
            radioState.connection_status = "connection_failed"
        end
        
    elseif message.type == "song_change" and senderId == radioState.connected_station then
        radioState.current_song = message.song
        radioState.sync_offset = message.sync_offset or 0
        radio.startSyncedPlayback(radioState)
        
    elseif message.type == "station_stop" and senderId == radioState.connected_station then
        radioState.current_song = nil
        audio.stopAudio()
        
    elseif message.type == "disconnect_notice" and senderId == radioState.connected_station then
        radioState.connected_station = nil
        radioState.connection_status = "disconnected"
        radioState.current_song = nil
        audio.stopAudio()
    end
end

function radio.handleHostMessages(radioState)
    if radioState.mode ~= "host" then return end
    
    local senderId, message, protocol = rednet.receive(RADIO_PROTOCOL, 0.1)
    if not senderId or not message then return end
    
    if message.type == "info_request" then
        -- Send station information
        rednet.send(senderId, {
            type = "info_response",
            station_name = radioState.station_name,
            current_song = radioState.current_song,
            listener_count = #radioState.clients
        }, RADIO_PROTOCOL)
        
    elseif message.type == "connect" then
        -- Add client to list
        local clientExists = false
        for _, clientId in ipairs(radioState.clients) do
            if clientId == senderId then
                clientExists = true
                break
            end
        end
        
        if not clientExists then
            table.insert(radioState.clients, senderId)
        end
        
        -- Send connection response
        local syncOffset = 0
        if radioState.current_song and radioState.is_playing then
            syncOffset = os.clock() - radioState.song_start_time
        end
        
        rednet.send(senderId, {
            type = "connect_response",
            success = true,
            current_song = radioState.current_song,
            sync_offset = syncOffset
        }, RADIO_PROTOCOL)
        
    elseif message.type == "disconnect" then
        -- Remove client from list
        for i, clientId in ipairs(radioState.clients) do
            if clientId == senderId then
                table.remove(radioState.clients, i)
                break
            end
        end
    end
end

function radio.startSyncedPlayback(radioState)
    if not radioState.current_song then return end
    
    -- Calculate the position in the song based on sync offset
    local startPosition = radioState.sync_offset or 0
    
    -- Start audio playback with offset
    audio.stopAudio()
    audio.playFromUrl(radioState.current_song.stream_url, startPosition)
end

function radio.hostPlaySong(radioState, song)
    if radioState.mode ~= "host" then return end
    
    radioState.current_song = song
    radioState.song_start_time = os.clock()
    radioState.is_playing = true
    
    -- Notify all connected clients
    for _, clientId in ipairs(radioState.clients) do
        rednet.send(clientId, {
            type = "song_change",
            song = song,
            sync_offset = 0
        }, RADIO_PROTOCOL)
    end
    
    -- Start playing locally
    audio.stopAudio()
    audio.playFromUrl(song.stream_url)
end

function radio.hostStopPlayback(radioState)
    if radioState.mode ~= "host" then return end
    
    radioState.current_song = nil
    radioState.is_playing = false
    
    -- Notify all connected clients
    for _, clientId in ipairs(radioState.clients) do
        rednet.send(clientId, {
            type = "station_stop"
        }, RADIO_PROTOCOL)
    end
    
    -- Stop local playback
    audio.stopAudio()
end

function radio.hostNextTrack(radioState)
    if radioState.mode ~= "host" or #radioState.playlist == 0 then return end
    
    radioState.current_track = radioState.current_track + 1
    if radioState.current_track > #radioState.playlist then
        radioState.current_track = 1
    end
    
    local nextSong = radioState.playlist[radioState.current_track]
    radio.hostPlaySong(radioState, nextSong)
end

function radio.addToPlaylist(radioState, song)
    if radioState.mode ~= "host" then return end
    
    table.insert(radioState.playlist, song)
end

function radio.shutdown(radioState)
    if radioState.mode == "host" then
        -- Notify all clients that station is shutting down
        for _, clientId in ipairs(radioState.clients) do
            rednet.send(clientId, {
                type = "disconnect_notice"
            }, RADIO_PROTOCOL)
        end
        
        -- Unhost the station
        rednet.unhost(STATION_PROTOCOL)
    elseif radioState.mode == "client" and radioState.connected_station then
        radio.disconnectFromStation(radioState)
    end
    
    -- Close rednet
    local modem = peripheral.find("modem")
    if modem then
        rednet.close(peripheral.getName(modem))
    end
end

return radio 