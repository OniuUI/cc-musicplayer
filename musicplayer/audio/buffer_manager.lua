-- Audio Buffer Manager for PRE-Buffer Synchronization System
-- Handles buffering, timestamping, and synchronized playback coordination

local config = require("musicplayer/config")
local bufferManager = {}

function bufferManager.createBuffer(logger)
    local buffer = {
        -- Core buffer data
        chunks = {},           -- Array of audio chunks with timestamps
        buffer_duration = config.radio_sync.buffer_duration,
        chunk_duration = config.radio_sync.chunk_duration,
        current_position = 0,  -- Current playback position in buffer (seconds)
        buffer_start_time = 0, -- When buffer started (UTC timestamp)
        
        -- Audio metadata
        song_id = nil,         -- Current song identifier
        song_duration = 0,     -- Total song duration
        song_start_position = 0, -- Position in song where buffer starts
        
        -- Buffer management
        max_chunks = math.ceil(config.radio_sync.buffer_duration / config.radio_sync.chunk_duration),
        chunk_counter = 0,     -- Unique ID for each chunk
        
        -- State tracking
        is_buffering = false,
        buffer_ready = false,
        last_chunk_time = 0,
        
        -- Logger reference
        logger = logger
    }
    
    -- Initialize chunk array
    for i = 1, buffer.max_chunks do
        buffer.chunks[i] = {
            id = nil,
            audio_data = nil,
            buffer_position = 0,
            song_position = 0,
            timestamp = 0,
            size = 0
        }
    end
    
    return buffer
end

-- Add audio chunk to buffer with precise timing
function bufferManager.addChunk(buffer, audioData, songPosition)
    if not buffer or not audioData then
        return false
    end
    
    local currentTime = os.epoch("utc")
    buffer.chunk_counter = buffer.chunk_counter + 1
    
    -- Calculate buffer position
    local bufferPosition = buffer.current_position + (#buffer.chunks * buffer.chunk_duration)
    
    -- Find next available slot (circular buffer)
    local slotIndex = (buffer.chunk_counter % buffer.max_chunks) + 1
    
    -- Store chunk with metadata
    buffer.chunks[slotIndex] = {
        id = buffer.song_id .. "_chunk_" .. buffer.chunk_counter,
        audio_data = audioData,
        buffer_position = bufferPosition,
        song_position = songPosition,
        timestamp = currentTime,
        size = #audioData
    }
    
    buffer.last_chunk_time = currentTime
    
    -- Check if buffer is ready for playback
    if not buffer.buffer_ready then
        local bufferedDuration = buffer.chunk_counter * buffer.chunk_duration
        if bufferedDuration >= config.radio_sync.safety_margin then
            buffer.buffer_ready = true
            if buffer.logger then
                buffer.logger.info("BufferManager", string.format("Buffer ready: %.1fs buffered", bufferedDuration))
            end
        end
    end
    
    return true
end

-- Get chunk at specific buffer position
function bufferManager.getChunkAtPosition(buffer, position)
    if not buffer or not buffer.buffer_ready then
        return nil
    end
    
    -- Find chunk that contains this position
    for i = 1, buffer.max_chunks do
        local chunk = buffer.chunks[i]
        if chunk.id and chunk.buffer_position <= position and 
           (chunk.buffer_position + buffer.chunk_duration) > position then
            return chunk
        end
    end
    
    return nil
end

-- Get all chunks in time range
function bufferManager.getChunksInRange(buffer, startPos, endPos)
    if not buffer or not buffer.buffer_ready then
        return {}
    end
    
    local chunks = {}
    
    for i = 1, buffer.max_chunks do
        local chunk = buffer.chunks[i]
        if chunk.id and chunk.buffer_position >= startPos and chunk.buffer_position <= endPos then
            table.insert(chunks, chunk)
        end
    end
    
    -- Sort by buffer position
    table.sort(chunks, function(a, b) return a.buffer_position < b.buffer_position end)
    
    return chunks
end

-- Update buffer position (advance playback)
function bufferManager.advancePosition(buffer, deltaTime)
    if not buffer then
        return false
    end
    
    buffer.current_position = buffer.current_position + deltaTime
    return true
end

-- Reset buffer for new song
function bufferManager.resetBuffer(buffer, songId, songDuration)
    if not buffer then
        return false
    end
    
    buffer.song_id = songId
    buffer.song_duration = songDuration
    buffer.current_position = 0
    buffer.buffer_start_time = os.epoch("utc")
    buffer.song_start_position = 0
    buffer.chunk_counter = 0
    buffer.buffer_ready = false
    buffer.is_buffering = true
    
    -- Clear all chunks
    for i = 1, buffer.max_chunks do
        buffer.chunks[i] = {
            id = nil,
            audio_data = nil,
            buffer_position = 0,
            song_position = 0,
            timestamp = 0,
            size = 0
        }
    end
    
    if buffer.logger then
        buffer.logger.info("BufferManager", string.format("Buffer reset for song: %s (%.1fs)", songId, songDuration))
    end
    
    return true
end

-- Get buffer status information
function bufferManager.getBufferStatus(buffer)
    if not buffer then
        return nil
    end
    
    local activeChunks = 0
    local totalSize = 0
    local oldestChunk = math.huge
    local newestChunk = 0
    
    for i = 1, buffer.max_chunks do
        local chunk = buffer.chunks[i]
        if chunk.id then
            activeChunks = activeChunks + 1
            totalSize = totalSize + chunk.size
            oldestChunk = math.min(oldestChunk, chunk.timestamp)
            newestChunk = math.max(newestChunk, chunk.timestamp)
        end
    end
    
    local bufferedDuration = activeChunks * buffer.chunk_duration
    local bufferHealth = math.min(100, (bufferedDuration / buffer.buffer_duration) * 100)
    
    return {
        active_chunks = activeChunks,
        max_chunks = buffer.max_chunks,
        buffered_duration = bufferedDuration,
        buffer_health = bufferHealth,
        total_size = totalSize,
        current_position = buffer.current_position,
        buffer_ready = buffer.buffer_ready,
        is_buffering = buffer.is_buffering,
        age_range = newestChunk - oldestChunk
    }
end

-- Cleanup old chunks to prevent memory issues
function bufferManager.cleanupOldChunks(buffer, maxAge)
    if not buffer then
        return 0
    end
    
    local currentTime = os.epoch("utc")
    local maxAgeMs = (maxAge or 60) * 1000 -- Default 60 seconds
    local cleanedCount = 0
    
    for i = 1, buffer.max_chunks do
        local chunk = buffer.chunks[i]
        if chunk.id and (currentTime - chunk.timestamp) > maxAgeMs then
            -- Clear old chunk
            buffer.chunks[i] = {
                id = nil,
                audio_data = nil,
                buffer_position = 0,
                song_position = 0,
                timestamp = 0,
                size = 0
            }
            cleanedCount = cleanedCount + 1
        end
    end
    
    if cleanedCount > 0 and buffer.logger then
        buffer.logger.debug("BufferManager", string.format("Cleaned %d old chunks", cleanedCount))
    end
    
    return cleanedCount
end

-- Compress audio data if enabled
function bufferManager.compressChunk(audioData)
    if not config.radio_sync.enable_compression then
        return audioData
    end
    
    -- Simple compression: remove silence and reduce bit depth for network transfer
    -- This is a placeholder - in a real implementation you'd use proper audio compression
    return audioData
end

-- Decompress audio data
function bufferManager.decompressChunk(compressedData)
    if not config.radio_sync.enable_compression then
        return compressedData
    end
    
    -- Decompress the data
    -- This is a placeholder - in a real implementation you'd use proper audio decompression
    return compressedData
end

return bufferManager 