-- Radio Protocol for Bognesferga Radio
-- Handles network communication between radio hosts and clients using rednet

local radioProtocol = {}

-- Protocol constants
radioProtocol.PROTOCOL_NAME = "bognesferga_radio"
radioProtocol.DISCOVERY_PROTOCOL = "radio_discovery"
radioProtocol.BROADCAST_PROTOCOL = "radio_broadcast"

-- Message types
radioProtocol.MESSAGE_TYPES = {
    STATION_ANNOUNCE = "station_announce",
    STATION_DISCOVERY = "station_discovery", 
    STATION_LIST = "station_list",
    JOIN_REQUEST = "join_request",
    JOIN_RESPONSE = "join_response",
    LEAVE_REQUEST = "leave_request",
    SONG_UPDATE = "song_update",
    SYNC_REQUEST = "sync_request",
    SYNC_RESPONSE = "sync_response",
    HEARTBEAT = "heartbeat"
}

-- Initialize radio protocol
function radioProtocol.init(errorHandler)
    radioProtocol.errorHandler = errorHandler
    radioProtocol.modem = nil
    radioProtocol.isOpen = false
    
    -- Find and open modem
    local modemSide = radioProtocol.findModem()
    if modemSide then
        radioProtocol.modem = peripheral.wrap(modemSide)
        rednet.open(modemSide)
        radioProtocol.isOpen = true
        return true
    end
    
    return false
end

-- Find available wireless modem
function radioProtocol.findModem()
    local sides = {"top", "bottom", "left", "right", "front", "back"}
    
    for _, side in ipairs(sides) do
        if peripheral.isPresent(side) then
            local peripheralType = peripheral.getType(side)
            if peripheralType == "modem" then
                local modem = peripheral.wrap(side)
                if modem.isWireless() then
                    return side
                end
            end
        end
    end
    
    return nil
end

-- Check if radio protocol is available
function radioProtocol.isAvailable()
    return radioProtocol.isOpen and radioProtocol.modem ~= nil
end

-- Close radio protocol
function radioProtocol.close()
    if radioProtocol.isOpen then
        rednet.close()
        radioProtocol.isOpen = false
    end
end

-- Send message with error handling
function radioProtocol.sendMessage(recipient, messageType, data)
    if not radioProtocol.isAvailable() then
        return false, "Radio protocol not available"
    end
    
    local message = {
        type = messageType,
        timestamp = os.epoch("utc"),
        sender = os.getComputerID(),
        data = data or {}
    }
    
    local success, error = pcall(function()
        if recipient then
            rednet.send(recipient, message, radioProtocol.PROTOCOL_NAME)
        else
            rednet.broadcast(message, radioProtocol.PROTOCOL_NAME)
        end
    end)
    
    if not success and radioProtocol.errorHandler then
        radioProtocol.errorHandler.handleNetworkError("radio_send", "RadioProtocol", {
            reason = error,
            messageType = messageType,
            recipient = recipient
        })
    end
    
    return success, error
end

-- Receive message with timeout
function radioProtocol.receiveMessage(timeout)
    if not radioProtocol.isAvailable() then
        return nil, nil, "Radio protocol not available"
    end
    
    local senderId, message, protocol = rednet.receive(radioProtocol.PROTOCOL_NAME, timeout or 1)
    
    if senderId and message and protocol == radioProtocol.PROTOCOL_NAME then
        -- Validate message structure
        if type(message) == "table" and message.type and message.sender and message.timestamp then
            return senderId, message, nil
        else
            return nil, nil, "Invalid message format"
        end
    end
    
    return nil, nil, "No message received"
end

-- Station discovery functions
function radioProtocol.announceStation(stationInfo)
    return radioProtocol.sendMessage(nil, radioProtocol.MESSAGE_TYPES.STATION_ANNOUNCE, stationInfo)
end

function radioProtocol.requestStationList()
    return radioProtocol.sendMessage(nil, radioProtocol.MESSAGE_TYPES.STATION_DISCOVERY, {})
end

function radioProtocol.sendStationList(recipient, stations)
    return radioProtocol.sendMessage(recipient, radioProtocol.MESSAGE_TYPES.STATION_LIST, {stations = stations})
end

-- Client connection functions
function radioProtocol.requestJoin(stationId, clientInfo)
    return radioProtocol.sendMessage(stationId, radioProtocol.MESSAGE_TYPES.JOIN_REQUEST, clientInfo)
end

function radioProtocol.respondToJoin(clientId, accepted, stationInfo)
    local responseData = {
        accepted = accepted,
        station = stationInfo or {}
    }
    return radioProtocol.sendMessage(clientId, radioProtocol.MESSAGE_TYPES.JOIN_RESPONSE, responseData)
end

function radioProtocol.requestLeave(stationId)
    return radioProtocol.sendMessage(stationId, radioProtocol.MESSAGE_TYPES.LEAVE_REQUEST, {})
end

-- Synchronization functions
function radioProtocol.broadcastSongUpdate(listeners, songInfo)
    local success = true
    for _, listenerId in ipairs(listeners) do
        local result = radioProtocol.sendMessage(listenerId, radioProtocol.MESSAGE_TYPES.SONG_UPDATE, songInfo)
        if not result then
            success = false
        end
    end
    return success
end

function radioProtocol.requestSync(stationId)
    return radioProtocol.sendMessage(stationId, radioProtocol.MESSAGE_TYPES.SYNC_REQUEST, {})
end

function radioProtocol.respondToSync(clientId, syncInfo)
    return radioProtocol.sendMessage(clientId, radioProtocol.MESSAGE_TYPES.SYNC_RESPONSE, syncInfo)
end

-- Heartbeat functions
function radioProtocol.sendHeartbeat(recipient, data)
    return radioProtocol.sendMessage(recipient, radioProtocol.MESSAGE_TYPES.HEARTBEAT, data or {})
end

-- Utility functions
function radioProtocol.getComputerId()
    return os.getComputerID()
end

function radioProtocol.getComputerLabel()
    return os.getComputerLabel() or ("Computer_" .. os.getComputerID())
end

return radioProtocol 