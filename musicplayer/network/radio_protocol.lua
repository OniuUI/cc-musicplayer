-- Radio Protocol for Bognesferga Radio Network
-- Handles communication between radio hosts and clients

local radioProtocol = {}

-- Protocol configuration
local BROADCAST_CHANNEL = 65000
local STATION_CHANNEL_BASE = 65100
local CLIENT_CHANNEL_BASE = 65200
local PROTOCOL_VERSION = "1.0"

-- State
local modem = nil
local errorHandler = nil
local isInitialized = false
local openChannels = {}

function radioProtocol.init(errorHandlerModule)
    errorHandler = errorHandlerModule
    
    -- Find wireless modem
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
    
    if not modem then
        return false
    end
    
    isInitialized = true
    return true
end

function radioProtocol.cleanup()
    if modem then
        -- Close all opened channels
        for channel, _ in pairs(openChannels) do
            modem.close(channel)
        end
        openChannels = {}
    end
    
    isInitialized = false
end

-- CHANNEL MANAGEMENT
function radioProtocol.openChannel(channel)
    if not modem or not isInitialized then
        return false
    end
    
    if not openChannels[channel] then
        modem.open(channel)
        openChannels[channel] = true
    end
    
    return true
end

function radioProtocol.closeChannel(channel)
    if not modem or not isInitialized then
        return false
    end
    
    if openChannels[channel] then
        modem.close(channel)
        openChannels[channel] = nil
    end
    
    return true
end

function radioProtocol.openBroadcastChannel()
    return radioProtocol.openChannel(BROADCAST_CHANNEL)
end

function radioProtocol.getStationChannel(stationId)
    return STATION_CHANNEL_BASE + (stationId % 100)
end

function radioProtocol.getClientChannel(clientId)
    return CLIENT_CHANNEL_BASE + (clientId % 100)
end

-- BROADCASTING (HOST FUNCTIONS)
function radioProtocol.broadcast(message)
    if not modem or not isInitialized then
        return false
    end
    
    -- Add protocol metadata
    local protocolMessage = {
        protocol_version = PROTOCOL_VERSION,
        timestamp = os.epoch("utc"),
        data = message
    }
    
    radioProtocol.openBroadcastChannel()
    modem.transmit(BROADCAST_CHANNEL, BROADCAST_CHANNEL, protocolMessage)
    
    return true
end

function radioProtocol.sendToComputer(computerId, message)
    if not modem or not isInitialized then
        return false
    end
    
    local clientChannel = radioProtocol.getClientChannel(computerId)
    local protocolMessage = {
        protocol_version = PROTOCOL_VERSION,
        timestamp = os.epoch("utc"),
        target_computer = computerId,
        data = message
    }
    
    radioProtocol.openChannel(clientChannel)
    modem.transmit(clientChannel, clientChannel, protocolMessage)
    
    return true
end

function radioProtocol.sendToChannel(channel, message)
    if not modem or not isInitialized then
        return false
    end
    
    local protocolMessage = {
        protocol_version = PROTOCOL_VERSION,
        timestamp = os.epoch("utc"),
        data = message
    }
    
    radioProtocol.openChannel(channel)
    modem.transmit(channel, channel, protocolMessage)
    
    return true
end

-- STATION DISCOVERY (CLIENT FUNCTIONS)
function radioProtocol.scanForStations(timeoutSeconds)
    if not modem or not isInitialized then
        return {}
    end
    
    local stations = {}
    local startTime = os.clock()
    local timeout = timeoutSeconds or 5
    
    -- Open broadcast channel to listen for announcements
    radioProtocol.openBroadcastChannel()
    
    -- Send discovery request
    local discoveryRequest = {
        type = "discovery_request",
        client_id = os.getComputerID(),
        timestamp = os.epoch("utc")
    }
    
    radioProtocol.broadcast(discoveryRequest)
    
    -- Listen for responses using proper ComputerCraft event handling
    while (os.clock() - startTime) < timeout do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        
        if channel == BROADCAST_CHANNEL and message and type(message) == "table" then
            if message.protocol_version == PROTOCOL_VERSION and message.data then
                local data = message.data
                
                if data.type == "station_announcement" then
                    -- Check if we already have this station
                    local found = false
                    for _, station in ipairs(stations) do
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
                        table.insert(stations, {
                            station_id = data.station_id,
                            station_name = data.station_name,
                            station_description = data.station_description,
                            listener_count = data.listener_count or 0,
                            max_listeners = data.max_listeners or 10,
                            now_playing = data.now_playing,
                            last_seen = data.timestamp,
                            distance = distance
                        })
                    end
                end
            end
        end
        
        sleep(0.1)
    end
    
    return stations
end

-- CONNECTION MANAGEMENT (CLIENT FUNCTIONS)
function radioProtocol.joinStation(stationId)
    if not modem or not isInitialized then
        return false, "No modem available"
    end
    
    local clientId = os.getComputerID()
    local stationChannel = radioProtocol.getStationChannel(stationId)
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
        protocol_version = PROTOCOL_VERSION,
        timestamp = os.epoch("utc"),
        data = joinRequest
    }
    
    modem.transmit(stationChannel, clientChannel, protocolMessage)
    
    -- Wait for response using proper ComputerCraft event handling
    local timeout = 10 -- seconds
    local startTime = os.clock()
    
    while (os.clock() - startTime) < timeout do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        
        if channel == clientChannel and message and type(message) == "table" then
            if message.protocol_version == PROTOCOL_VERSION and message.data then
                local data = message.data
                
                if data.type == "join_response" then
                    if data.success then
                        return true, data
                    else
                        return false, data.reason or "Join request rejected"
                    end
                end
            end
        end
        
        sleep(0.1)
    end
    
    return false, "Connection timeout"
end

function radioProtocol.leaveStation(stationId)
    if not modem or not isInitialized then
        return false
    end
    
    local clientId = os.getComputerID()
    local stationChannel = radioProtocol.getStationChannel(stationId)
    
    -- Send leave request
    local leaveRequest = {
        type = "leave_request",
        listener_id = clientId,
        timestamp = os.epoch("utc")
    }
    
    local protocolMessage = {
        protocol_version = PROTOCOL_VERSION,
        timestamp = os.epoch("utc"),
        data = leaveRequest
    }
    
    radioProtocol.openChannel(stationChannel)
    modem.transmit(stationChannel, stationChannel, protocolMessage)
    
    -- Close client channel
    local clientChannel = radioProtocol.getClientChannel(clientId)
    radioProtocol.closeChannel(clientChannel)
    
    return true
end

function radioProtocol.sendPing(stationId)
    if not modem or not isInitialized then
        return false
    end
    
    local clientId = os.getComputerID()
    local stationChannel = radioProtocol.getStationChannel(stationId)
    local clientChannel = radioProtocol.getClientChannel(clientId)
    
    -- Send ping
    local pingMessage = {
        type = "listener_ping",
        listener_id = clientId,
        timestamp = os.epoch("utc")
    }
    
    local protocolMessage = {
        protocol_version = PROTOCOL_VERSION,
        timestamp = os.epoch("utc"),
        data = pingMessage
    }
    
    radioProtocol.openChannel(stationChannel)
    modem.transmit(stationChannel, clientChannel, protocolMessage)
    
    return true
end

-- MESSAGE HANDLING UTILITIES
function radioProtocol.isValidMessage(message)
    if not message or type(message) ~= "table" then
        return false
    end
    
    if message.protocol_version ~= PROTOCOL_VERSION then
        return false
    end
    
    if not message.data or type(message.data) ~= "table" then
        return false
    end
    
    return true
end

function radioProtocol.extractMessageData(message)
    if radioProtocol.isValidMessage(message) then
        return message.data
    end
    return nil
end

-- DEBUGGING AND MONITORING
function radioProtocol.getStatus()
    return {
        initialized = isInitialized,
        modem_available = modem ~= nil,
        open_channels = openChannels,
        protocol_version = PROTOCOL_VERSION
    }
end

function radioProtocol.listOpenChannels()
    local channels = {}
    for channel, _ in pairs(openChannels) do
        table.insert(channels, channel)
    end
    return channels
end

-- ERROR HANDLING
function radioProtocol.handleError(context, message)
    if errorHandler then
        errorHandler.handleError("RadioProtocol", context .. ": " .. message, 2)
    else
        print("RadioProtocol Error [" .. context .. "]: " .. message)
    end
end

return radioProtocol 