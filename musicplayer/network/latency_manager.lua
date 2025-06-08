-- Latency Manager for PRE-Buffer Synchronization System
-- Handles ping/pong latency measurement and client tracking

local config = require("musicplayer/config")
local latencyManager = {}

function latencyManager.createTracker(logger)
    local tracker = {
        -- Client latency data
        clients = {},          -- [clientId] = client data
        
        -- Ping management
        pending_pings = {},    -- [sequence] = ping data
        ping_sequence = 0,     -- Incrementing ping sequence number
        
        -- Timing
        last_ping_time = 0,
        ping_interval = config.radio_sync.ping_interval * 1000, -- Convert to ms
        
        -- Configuration
        max_samples = config.radio_sync.latency_samples,
        max_latency = config.radio_sync.max_client_latency,
        timeout_duration = config.radio_sync.slow_client_timeout * 1000,
        
        -- Logger reference
        logger = logger
    }
    
    return tracker
end

-- Add or update client in tracker
function latencyManager.addClient(tracker, clientId)
    if not tracker or not clientId then
        return false
    end
    
    if not tracker.clients[clientId] then
        tracker.clients[clientId] = {
            id = clientId,
            samples = {},          -- Array of latency measurements
            average = 0,           -- Rolling average latency
            last_ping = 0,         -- Last ping timestamp
            last_response = 0,     -- Last response timestamp
            status = "active",     -- active, slow, timeout, removed
            ping_count = 0,        -- Total pings sent
            response_count = 0,    -- Total responses received
            packet_loss = 0,       -- Percentage packet loss
            first_seen = os.epoch("utc"),
            last_seen = os.epoch("utc")
        }
        
        if tracker.logger then
            tracker.logger.info("LatencyManager", string.format("Added client %d to latency tracking", clientId))
        end
    else
        -- Update last seen time
        tracker.clients[clientId].last_seen = os.epoch("utc")
    end
    
    return true
end

-- Remove client from tracker
function latencyManager.removeClient(tracker, clientId)
    if not tracker or not clientId then
        return false
    end
    
    if tracker.clients[clientId] then
        tracker.clients[clientId] = nil
        
        if tracker.logger then
            tracker.logger.info("LatencyManager", string.format("Removed client %d from latency tracking", clientId))
        end
        
        return true
    end
    
    return false
end

-- Send ping to specific client
function latencyManager.sendPing(tracker, clientId, radioProtocol)
    if not tracker or not clientId or not radioProtocol then
        return false
    end
    
    local client = tracker.clients[clientId]
    if not client then
        return false
    end
    
    tracker.ping_sequence = tracker.ping_sequence + 1
    local currentTime = os.epoch("utc")
    
    -- Store pending ping
    tracker.pending_pings[tracker.ping_sequence] = {
        client_id = clientId,
        timestamp = currentTime,
        sequence = tracker.ping_sequence
    }
    
    -- Send ping message
    local pingMessage = {
        type = "ping_request",
        timestamp = currentTime,
        sequence = tracker.ping_sequence
    }
    
    local success = radioProtocol.sendToComputer(clientId, pingMessage)
    
    if success then
        client.last_ping = currentTime
        client.ping_count = client.ping_count + 1
        
        if tracker.logger then
            tracker.logger.debug("LatencyManager", string.format("Sent ping %d to client %d", tracker.ping_sequence, clientId))
        end
    end
    
    return success
end

-- Send ping to all active clients
function latencyManager.sendPingToAll(tracker, radioProtocol)
    if not tracker or not radioProtocol then
        return 0
    end
    
    local sentCount = 0
    local currentTime = os.epoch("utc")
    
    -- Check if it's time to ping
    if (currentTime - tracker.last_ping_time) < tracker.ping_interval then
        return 0
    end
    
    for clientId, client in pairs(tracker.clients) do
        if client.status == "active" or client.status == "slow" then
            if latencyManager.sendPing(tracker, clientId, radioProtocol) then
                sentCount = sentCount + 1
            end
        end
    end
    
    tracker.last_ping_time = currentTime
    
    if sentCount > 0 and tracker.logger then
        tracker.logger.debug("LatencyManager", string.format("Sent pings to %d clients", sentCount))
    end
    
    return sentCount
end

-- Process ping response
function latencyManager.processPingResponse(tracker, message, clientId)
    if not tracker or not message or not clientId then
        return false
    end
    
    local sequence = message.sequence
    local clientTimestamp = message.client_timestamp
    local currentTime = os.epoch("utc")
    
    -- Find pending ping
    local pendingPing = tracker.pending_pings[sequence]
    if not pendingPing or pendingPing.client_id ~= clientId then
        return false
    end
    
    -- Calculate round-trip latency
    local roundTripTime = currentTime - pendingPing.timestamp
    
    -- Get client data
    local client = tracker.clients[clientId]
    if not client then
        return false
    end
    
    -- Add sample to client's latency history
    table.insert(client.samples, roundTripTime)
    
    -- Keep only recent samples
    if #client.samples > tracker.max_samples then
        table.remove(client.samples, 1)
    end
    
    -- Calculate rolling average
    local sum = 0
    for _, sample in ipairs(client.samples) do
        sum = sum + sample
    end
    client.average = sum / #client.samples
    
    -- Update client status
    client.last_response = currentTime
    client.response_count = client.response_count + 1
    client.last_seen = currentTime
    
    -- Calculate packet loss
    if client.ping_count > 0 then
        client.packet_loss = ((client.ping_count - client.response_count) / client.ping_count) * 100
    end
    
    -- Update client status based on latency
    if client.average > tracker.max_latency then
        client.status = "slow"
    else
        client.status = "active"
    end
    
    -- Clean up pending ping
    tracker.pending_pings[sequence] = nil
    
    if tracker.logger then
        tracker.logger.debug("LatencyManager", string.format("Client %d latency: %dms (avg: %.1fms)", 
            clientId, roundTripTime, client.average))
    end
    
    return true
end

-- Get slowest client latency
function latencyManager.getSlowestClientLatency(tracker)
    if not tracker then
        return 0
    end
    
    local maxLatency = 0
    local slowestClient = nil
    
    for clientId, client in pairs(tracker.clients) do
        if (client.status == "active" or client.status == "slow") and client.average > maxLatency then
            maxLatency = client.average
            slowestClient = clientId
        end
    end
    
    return maxLatency, slowestClient
end

-- Calculate optimal sync timing for all clients
function latencyManager.calculateOptimalSync(tracker)
    if not tracker then
        return nil
    end
    
    local maxLatency, slowestClient = latencyManager.getSlowestClientLatency(tracker)
    
    if maxLatency == 0 then
        return nil
    end
    
    -- Add safety margin
    local syncDelay = maxLatency + 200  -- +200ms safety margin
    
    -- Calculate when all clients should start playing
    local syncTimestamp = os.epoch("utc") + syncDelay
    
    return {
        sync_timestamp = syncTimestamp,
        slowest_latency = maxLatency,
        slowest_client = slowestClient,
        recommended_delay = syncDelay,
        active_clients = latencyManager.getActiveClientCount(tracker)
    }
end

-- Get active client count
function latencyManager.getActiveClientCount(tracker)
    if not tracker then
        return 0
    end
    
    local count = 0
    for _, client in pairs(tracker.clients) do
        if client.status == "active" or client.status == "slow" then
            count = count + 1
        end
    end
    
    return count
end

-- Clean up timed out clients
function latencyManager.cleanupTimeoutClients(tracker)
    if not tracker then
        return 0
    end
    
    local currentTime = os.epoch("utc")
    local removedCount = 0
    local toRemove = {}
    
    for clientId, client in pairs(tracker.clients) do
        local timeSinceLastSeen = currentTime - client.last_seen
        
        if timeSinceLastSeen > tracker.timeout_duration then
            table.insert(toRemove, clientId)
        end
    end
    
    -- Remove timed out clients
    for _, clientId in ipairs(toRemove) do
        if tracker.logger then
            tracker.logger.warn("LatencyManager", string.format("Client %d timed out (last seen %.1fs ago)", 
                clientId, (currentTime - tracker.clients[clientId].last_seen) / 1000))
        end
        
        tracker.clients[clientId] = nil
        removedCount = removedCount + 1
    end
    
    return removedCount
end

-- Get client statistics
function latencyManager.getClientStats(tracker, clientId)
    if not tracker or not clientId then
        return nil
    end
    
    local client = tracker.clients[clientId]
    if not client then
        return nil
    end
    
    return {
        id = client.id,
        status = client.status,
        average_latency = client.average,
        sample_count = #client.samples,
        ping_count = client.ping_count,
        response_count = client.response_count,
        packet_loss = client.packet_loss,
        last_seen = client.last_seen,
        uptime = os.epoch("utc") - client.first_seen
    }
end

-- Get all client statistics
function latencyManager.getAllClientStats(tracker)
    if not tracker then
        return {}
    end
    
    local stats = {}
    
    for clientId, _ in pairs(tracker.clients) do
        local clientStats = latencyManager.getClientStats(tracker, clientId)
        if clientStats then
            table.insert(stats, clientStats)
        end
    end
    
    -- Sort by latency (fastest first)
    table.sort(stats, function(a, b) return a.average_latency < b.average_latency end)
    
    return stats
end

-- Clean up old pending pings
function latencyManager.cleanupPendingPings(tracker, maxAge)
    if not tracker then
        return 0
    end
    
    local currentTime = os.epoch("utc")
    local maxAgeMs = (maxAge or 10) * 1000 -- Default 10 seconds
    local cleanedCount = 0
    local toRemove = {}
    
    for sequence, ping in pairs(tracker.pending_pings) do
        if (currentTime - ping.timestamp) > maxAgeMs then
            table.insert(toRemove, sequence)
        end
    end
    
    for _, sequence in ipairs(toRemove) do
        tracker.pending_pings[sequence] = nil
        cleanedCount = cleanedCount + 1
    end
    
    if cleanedCount > 0 and tracker.logger then
        tracker.logger.debug("LatencyManager", string.format("Cleaned %d old pending pings", cleanedCount))
    end
    
    return cleanedCount
end

return latencyManager 