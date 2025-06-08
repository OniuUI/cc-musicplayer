-- Speaker Manager for Bognesferga Radio
-- Manages audio output across multiple speakers with error handling and synchronization

local config = require("musicplayer/config")
local common = require("musicplayer/utils/common")
local audioProcessor = require("musicplayer/audio/audio_processor")

local speakerManager = {}

-- Initialize speaker manager
function speakerManager.init(errorHandler, telemetry)
    speakerManager.errorHandler = errorHandler
    speakerManager.telemetry = telemetry
    speakerManager.logger = telemetry and telemetry.getLogger()
    speakerManager.speakers = {}
    speakerManager.isPlaying = false
    speakerManager.currentVolume = config.default_volume
    
    -- Initialize audio processor with config defaults
    speakerManager.audioProcessor = audioProcessor.init(speakerManager.logger)
    speakerManager.audioProcessor.setVolume(speakerManager.currentVolume)
    speakerManager.audioProcessor.setBass(config.audio.default_bass)
    speakerManager.audioProcessor.setTreble(config.audio.default_treble)
    speakerManager.audioProcessor.setEnabled(config.audio.processing_enabled)
    
    -- Audio processing state (from working original)
    speakerManager.decoder = require("cc.audio.dfpwm").make_decoder()
    speakerManager.buffer = nil
    
    -- Detect and initialize speakers
    speakerManager.detectSpeakers()
    
    if speakerManager.logger then
        speakerManager.logger.info("SpeakerManager", "Speaker manager initialized with " .. #speakerManager.speakers .. " speakers and audio processing")
        speakerManager.logger.info("SpeakerManager", "Audio defaults: Bass=" .. config.audio.default_bass .. 
                                  ", Treble=" .. config.audio.default_treble .. 
                                  ", Processing=" .. (config.audio.processing_enabled and "enabled" or "disabled"))
    end
    
    return speakerManager
end

-- Detect available speakers
function speakerManager.detectSpeakers()
    speakerManager.speakers = {}
    
    local detectedSpeakers = {peripheral.find("speaker")}
    
    for i, speaker in ipairs(detectedSpeakers) do
        local side = peripheral.getName(speaker)
        
        table.insert(speakerManager.speakers, {
            peripheral = speaker,
            side = side,
            index = i,
            isActive = true,
            lastError = nil
        })
        
        if speakerManager.logger then
            speakerManager.logger.debug("SpeakerManager", "Detected speaker on side: " .. side)
        end
    end
    
    return #speakerManager.speakers
end

-- Get speaker count
function speakerManager.getSpeakerCount()
    return #speakerManager.speakers
end

-- Get active speaker count
function speakerManager.getActiveSpeakerCount()
    local count = 0
    for _, speaker in ipairs(speakerManager.speakers) do
        if speaker.isActive then
            count = count + 1
        end
    end
    return count
end

-- Check if speakers are available
function speakerManager.hasActiveSpeakers()
    return speakerManager.getActiveSpeakerCount() > 0
end

-- Play audio buffer on all active speakers with audio processing
function speakerManager.playAudio(buffer, volume)
    if not speakerManager.hasActiveSpeakers() then
        if speakerManager.errorHandler then
            speakerManager.errorHandler.handleAudioError("No active speakers available", "SpeakerManager")
        end
        return false
    end
    
    volume = volume or speakerManager.currentVolume
    volume = common.clamp(volume, 0, config.max_volume)
    
    -- Apply audio processing if enabled
    local processedBuffer = buffer
    if speakerManager.audioProcessor and speakerManager.audioProcessor.isEnabled() then
        speakerManager.audioProcessor.setVolume(volume)
        processedBuffer = speakerManager.audioProcessor.processBuffer(buffer)
        volume = 1.0 -- Use volume 1.0 since we pre-processed
    end
    
    -- Create speaker functions for parallel execution
    local speakerFunctions = {}
    
    for i, speaker in ipairs(speakerManager.speakers) do
        if speaker.isActive then
            speakerFunctions[i] = function()
                return speakerManager.playSpeakerAudio(speaker, processedBuffer, volume)
            end
        end
    end
    
    -- Execute all speaker functions in parallel
    local success, err = pcall(parallel.waitForAll, table.unpack(speakerFunctions))
    
    if not success then
        if speakerManager.errorHandler then
            speakerManager.errorHandler.handleAudioError("Parallel speaker playback failed: " .. tostring(err), "SpeakerManager")
        end
        return false
    end
    
    return true
end

-- Enhanced audio processing from working original
-- Process and play DFPWM audio chunk with proper synchronization and audio processing
function speakerManager.playDFPWMChunk(chunk, volume, playingId, isPlaying)
    if not speakerManager.hasActiveSpeakers() then
        return false
    end
    
    volume = volume or speakerManager.currentVolume
    volume = common.clamp(volume, 0, config.max_volume)
    
    -- Decode the chunk
    speakerManager.buffer = speakerManager.decoder(chunk)
    
    -- Apply audio processing (bass, treble, volume)
    if speakerManager.audioProcessor and speakerManager.audioProcessor.isEnabled() then
        speakerManager.audioProcessor.setVolume(volume)
        speakerManager.buffer = speakerManager.audioProcessor.processBuffer(speakerManager.buffer)
    else
        -- Apply volume manually if audio processing is disabled
        for i = 1, #speakerManager.buffer do
            speakerManager.buffer[i] = common.clamp(speakerManager.buffer[i] * volume, -128, 127)
        end
    end
    
    -- Create speaker functions for parallel execution (from working original)
    local speakerFunctions = {}
    
    for i, speakerInfo in ipairs(speakerManager.speakers) do
        if speakerInfo.isActive then
            speakerFunctions[i] = function()
                local speaker = speakerInfo.peripheral
                local name = speakerInfo.side
                
                if #speakerManager.speakers > 1 then
                    -- Multiple speakers: wait for audio buffer to be consumed
                    if speaker.playAudio(speakerManager.buffer, 1.0) then -- Use volume 1.0 since we pre-processed
                        parallel.waitForAny(
                            function()
                                repeat until select(2, os.pullEvent("speaker_audio_empty")) == name
                            end,
                            function()
                                os.pullEvent("playback_stopped")
                                return
                            end
                        )
                        -- Check if playback was stopped or changed
                        if not isPlaying() or (playingId and playingId() ~= playingId()) then
                            return
                        end
                    end
                
                    -- Single speaker: retry until buffer is accepted
                    while not speaker.playAudio(speakerManager.buffer, 1.0) do -- Use volume 1.0 since we pre-processed
                        parallel.waitForAny(
                            function()
                                repeat until select(2, os.pullEvent("speaker_audio_empty")) == name
                            end,
                            function()
                                os.pullEvent("playback_stopped")
                                return
                            end
                        )
                        
                        -- Check if playback was stopped or changed
                        if not isPlaying() or (playingId and playingId() ~= playingId()) then
                            return
                        end
                    end
                end
                
                -- Final check before returning
                if not isPlaying() or (playingId and playingId() ~= playingId()) then
                    return
                end
            end
        end
    end
    
    -- Execute all speaker functions in parallel (from working original)
    local success, err = pcall(parallel.waitForAll, table.unpack(speakerFunctions))
    
    if not success then
        if speakerManager.errorHandler then
            speakerManager.errorHandler.handleAudioError("DFPWM chunk playback failed: " .. tostring(err), "SpeakerManager")
        end
        return false
    end
    
    return true
end

-- Play audio on a single speaker
function speakerManager.playSpeakerAudio(speakerInfo, buffer, volume)
    local speaker = speakerInfo.peripheral
    local side = speakerInfo.side
    
    -- Check if speaker is still connected
    if not peripheral.isPresent(side) then
        speakerInfo.isActive = false
        speakerInfo.lastError = "Speaker disconnected"
        
        if speakerManager.logger then
            speakerManager.logger.warn("SpeakerManager", "Speaker disconnected: " .. side)
        end
        return false
    end
    
    -- Try to play audio
    local success, result = pcall(function()
        if #speakerManager.speakers > 1 then
            -- Multiple speakers: wait for audio buffer to be consumed
            if speaker.playAudio(buffer, volume) then
                parallel.waitForAny(
                    function()
                        repeat until select(2, os.pullEvent("speaker_audio_empty")) == side
                    end,
                    function()
                        os.pullEvent("playback_stopped")
                        return
                    end
                )
            end
        else
            -- Single speaker: retry until buffer is accepted
            while not speaker.playAudio(buffer, volume) do
                parallel.waitForAny(
                    function()
                        repeat until select(2, os.pullEvent("speaker_audio_empty")) == side
                    end,
                    function()
                        os.pullEvent("playback_stopped")
                        return
                    end
                )
                
                -- Check if playback was stopped
                if not speakerManager.isPlaying then
                    return
                end
            end
        end
    end)
    
    if not success then
        speakerInfo.lastError = tostring(result)
        
        if speakerManager.errorHandler then
            speakerManager.errorHandler.handleAudioError("Speaker playback error on " .. side .. ": " .. tostring(result), "SpeakerManager")
        end
        
        -- Temporarily disable this speaker
        speakerInfo.isActive = false
        return false
    end
    
    -- Clear any previous errors
    speakerInfo.lastError = nil
    return true
end

-- Stop all audio playback
function speakerManager.stopAll()
    speakerManager.isPlaying = false
    
    for _, speakerInfo in ipairs(speakerManager.speakers) do
        local success, err = pcall(function()
            speakerInfo.peripheral.stop()
        end)
        
        if not success and speakerManager.logger then
            speakerManager.logger.warn("SpeakerManager", "Error stopping speaker " .. speakerInfo.side .. ": " .. tostring(err))
        end
    end
    
    -- Send stop event to interrupt audio processing
    common.safeQueueEvent("playback_stopped")
    
    if speakerManager.logger then
        speakerManager.logger.debug("SpeakerManager", "All speakers stopped")
    end
end

-- Get raw speakers list (for direct access like in working original)
function speakerManager.getRawSpeakers()
    local rawSpeakers = {}
    for _, speakerInfo in ipairs(speakerManager.speakers) do
        if speakerInfo.isActive then
            table.insert(rawSpeakers, speakerInfo.peripheral)
        end
    end
    return rawSpeakers
end

-- Set volume for all speakers and audio processor
function speakerManager.setVolume(volume)
    volume = common.clamp(volume, 0, config.max_volume)
    speakerManager.currentVolume = volume
    
    -- Update audio processor volume
    if speakerManager.audioProcessor then
        speakerManager.audioProcessor.setVolume(volume)
    end
    
    if speakerManager.logger then
        speakerManager.logger.debug("SpeakerManager", "Volume set to " .. volume)
    end
end

-- Get current volume
function speakerManager.getVolume()
    return speakerManager.currentVolume
end

-- Increase volume
function speakerManager.increaseVolume(step)
    step = step or 0.1
    local newVolume = speakerManager.currentVolume + step
    speakerManager.setVolume(newVolume)
    return speakerManager.currentVolume
end

-- Decrease volume
function speakerManager.decreaseVolume(step)
    step = step or 0.1
    local newVolume = speakerManager.currentVolume - step
    speakerManager.setVolume(newVolume)
    return speakerManager.currentVolume
end

-- Check speaker health
function speakerManager.checkSpeakerHealth()
    local healthReport = {
        totalSpeakers = #speakerManager.speakers,
        activeSpeakers = 0,
        disconnectedSpeakers = 0,
        errorSpeakers = 0,
        speakers = {}
    }
    
    for _, speakerInfo in ipairs(speakerManager.speakers) do
        local isConnected = peripheral.isPresent(speakerInfo.side)
        local hasError = speakerInfo.lastError ~= nil
        
        if isConnected and speakerInfo.isActive and not hasError then
            healthReport.activeSpeakers = healthReport.activeSpeakers + 1
        elseif not isConnected then
            healthReport.disconnectedSpeakers = healthReport.disconnectedSpeakers + 1
            speakerInfo.isActive = false
        elseif hasError then
            healthReport.errorSpeakers = healthReport.errorSpeakers + 1
        end
        
        table.insert(healthReport.speakers, {
            side = speakerInfo.side,
            isConnected = isConnected,
            isActive = speakerInfo.isActive,
            lastError = speakerInfo.lastError
        })
    end
    
    return healthReport
end

-- Attempt to reactivate failed speakers
function speakerManager.reactivateSpeakers()
    local reactivated = 0
    
    for _, speakerInfo in ipairs(speakerManager.speakers) do
        if not speakerInfo.isActive and peripheral.isPresent(speakerInfo.side) then
            speakerInfo.isActive = true
            speakerInfo.lastError = nil
            reactivated = reactivated + 1
            
            if speakerManager.logger then
                speakerManager.logger.info("SpeakerManager", "Reactivated speaker: " .. speakerInfo.side)
            end
        end
    end
    
    return reactivated
end

-- Get speaker status with audio processing info
function speakerManager.getStatus()
    local healthReport = speakerManager.checkSpeakerHealth()
    
    return {
        isPlaying = speakerManager.isPlaying,
        volume = speakerManager.currentVolume,
        maxVolume = config.max_volume,
        health = healthReport,
        audioProcessing = speakerManager.getAudioSettings()
    }
end

-- Set playing state
function speakerManager.setPlaying(playing)
    speakerManager.isPlaying = playing
end

-- Get playing state
function speakerManager.isCurrentlyPlaying()
    return speakerManager.isPlaying
end

-- Set bass level (-10 to +10)
function speakerManager.setBass(level)
    if speakerManager.audioProcessor then
        speakerManager.audioProcessor.setBass(level)
        if speakerManager.logger then
            speakerManager.logger.info("SpeakerManager", "Bass set to " .. level)
        end
    end
end

-- Set treble level (-10 to +10)
function speakerManager.setTreble(level)
    if speakerManager.audioProcessor then
        speakerManager.audioProcessor.setTreble(level)
        if speakerManager.logger then
            speakerManager.logger.info("SpeakerManager", "Treble set to " .. level)
        end
    end
end

-- Get bass level
function speakerManager.getBass()
    if speakerManager.audioProcessor then
        return speakerManager.audioProcessor.getBass()
    end
    return 0
end

-- Get treble level
function speakerManager.getTreble()
    if speakerManager.audioProcessor then
        return speakerManager.audioProcessor.getTreble()
    end
    return 0
end

-- Enable/disable audio processing
function speakerManager.setAudioProcessingEnabled(enabled)
    if speakerManager.audioProcessor then
        speakerManager.audioProcessor.setEnabled(enabled)
        if speakerManager.logger then
            speakerManager.logger.info("SpeakerManager", "Audio processing " .. (enabled and "enabled" or "disabled"))
        end
    end
end

-- Check if audio processing is enabled
function speakerManager.isAudioProcessingEnabled()
    if speakerManager.audioProcessor then
        return speakerManager.audioProcessor.isEnabled()
    end
    return false
end

-- Reset audio filters (useful when changing songs)
function speakerManager.resetAudioFilters()
    if speakerManager.audioProcessor then
        speakerManager.audioProcessor.resetFilters()
    end
end

-- Get audio processor settings
function speakerManager.getAudioSettings()
    if speakerManager.audioProcessor then
        return speakerManager.audioProcessor.getSettings()
    end
    return {
        bass = 0,
        treble = 0,
        volume = speakerManager.currentVolume,
        enabled = false
    }
end

-- Load audio processor settings
function speakerManager.loadAudioSettings(settings)
    if speakerManager.audioProcessor then
        speakerManager.audioProcessor.loadSettings(settings)
    end
end

-- Get formatted audio settings string for display
function speakerManager.getAudioDisplayString()
    if speakerManager.audioProcessor then
        return speakerManager.audioProcessor.getDisplayString()
    end
    local volume = math.floor((speakerManager.currentVolume / 3.0) * 100)
    return string.format("Vol: %d%% | Bass: 0 | Treble: 0", volume)
end

return speakerManager 