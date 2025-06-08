-- Audio Processor for Bognesferga Radio
-- Provides software-based bass and treble controls for enhanced audio experience

local audioProcessor = {}

-- Audio processing configuration
audioProcessor.SAMPLE_RATE = 48000 -- ComputerCraft speaker sample rate
audioProcessor.MAX_AMPLITUDE = 127
audioProcessor.MIN_AMPLITUDE = -128

-- Initialize audio processor
function audioProcessor.init(logger)
    audioProcessor.logger = logger
    
    -- Default audio settings
    audioProcessor.settings = {
        bass = 0,      -- Bass adjustment (-10 to +10)
        treble = 0,    -- Treble adjustment (-10 to +10)
        volume = 1.5,  -- Master volume (0 to 3.0)
        enabled = true -- Enable/disable audio processing
    }
    
    -- Simple low-pass and high-pass filter states
    audioProcessor.filterState = {
        bassFilter = {
            prev_input = 0,
            prev_output = 0
        },
        trebleFilter = {
            prev_input = 0,
            prev_output = 0
        }
    }
    
    if audioProcessor.logger then
        audioProcessor.logger.info("AudioProcessor", "Audio processor initialized with bass/treble controls")
    end
    
    return audioProcessor
end

-- Set bass level (-10 to +10)
function audioProcessor.setBass(level)
    level = math.max(-10, math.min(10, level))
    audioProcessor.settings.bass = level
    
    if audioProcessor.logger then
        audioProcessor.logger.debug("AudioProcessor", "Bass set to " .. level)
    end
end

-- Set treble level (-10 to +10)
function audioProcessor.setTreble(level)
    level = math.max(-10, math.min(10, level))
    audioProcessor.settings.treble = level
    
    if audioProcessor.logger then
        audioProcessor.logger.debug("AudioProcessor", "Treble set to " .. level)
    end
end

-- Set master volume (0 to 3.0)
function audioProcessor.setVolume(volume)
    volume = math.max(0, math.min(3.0, volume))
    audioProcessor.settings.volume = volume
    
    if audioProcessor.logger then
        audioProcessor.logger.debug("AudioProcessor", "Volume set to " .. volume)
    end
end

-- Get current bass level
function audioProcessor.getBass()
    return audioProcessor.settings.bass
end

-- Get current treble level
function audioProcessor.getTreble()
    return audioProcessor.settings.treble
end

-- Get current volume
function audioProcessor.getVolume()
    return audioProcessor.settings.volume
end

-- Enable/disable audio processing
function audioProcessor.setEnabled(enabled)
    audioProcessor.settings.enabled = enabled
    
    if audioProcessor.logger then
        audioProcessor.logger.info("AudioProcessor", "Audio processing " .. (enabled and "enabled" or "disabled"))
    end
end

-- Check if audio processing is enabled
function audioProcessor.isEnabled()
    return audioProcessor.settings.enabled
end

-- Simple low-pass filter for bass enhancement
function audioProcessor.applyBassFilter(sample, strength)
    if strength == 0 then
        return sample
    end
    
    -- Simple RC low-pass filter simulation
    local alpha = math.max(0.1, math.min(0.9, 0.5 + (strength * 0.04)))
    
    audioProcessor.filterState.bassFilter.prev_output = 
        alpha * sample + (1 - alpha) * audioProcessor.filterState.bassFilter.prev_output
    
    -- Apply bass boost/cut
    local bassGain = 1.0 + (strength * 0.15) -- Up to 150% gain for +10 bass
    local processed = sample + (audioProcessor.filterState.bassFilter.prev_output - sample) * bassGain
    
    return processed
end

-- Simple high-pass filter for treble enhancement
function audioProcessor.applyTrebleFilter(sample, strength)
    if strength == 0 then
        return sample
    end
    
    -- Simple RC high-pass filter simulation
    local alpha = math.max(0.1, math.min(0.9, 0.5 - (strength * 0.04)))
    
    local highFreq = sample - audioProcessor.filterState.trebleFilter.prev_input * alpha
    audioProcessor.filterState.trebleFilter.prev_input = sample
    
    -- Apply treble boost/cut
    local trebleGain = 1.0 + (strength * 0.12) -- Up to 120% gain for +10 treble
    local processed = sample + highFreq * trebleGain
    
    return processed
end

-- Clamp sample to valid range
function audioProcessor.clampSample(sample)
    return math.max(audioProcessor.MIN_AMPLITUDE, 
                   math.min(audioProcessor.MAX_AMPLITUDE, math.floor(sample + 0.5)))
end

-- Process audio buffer with bass, treble, and volume controls
function audioProcessor.processBuffer(buffer)
    if not audioProcessor.settings.enabled or not buffer then
        return buffer
    end
    
    local processedBuffer = {}
    local bassLevel = audioProcessor.settings.bass
    local trebleLevel = audioProcessor.settings.treble
    local volume = audioProcessor.settings.volume
    
    for i = 1, #buffer do
        local sample = buffer[i]
        
        -- Apply bass filter
        if bassLevel ~= 0 then
            sample = audioProcessor.applyBassFilter(sample, bassLevel)
        end
        
        -- Apply treble filter
        if trebleLevel ~= 0 then
            sample = audioProcessor.applyTrebleFilter(sample, trebleLevel)
        end
        
        -- Apply volume
        sample = sample * volume
        
        -- Clamp to valid range
        processedBuffer[i] = audioProcessor.clampSample(sample)
    end
    
    return processedBuffer
end

-- Reset filter states (useful when changing songs)
function audioProcessor.resetFilters()
    audioProcessor.filterState.bassFilter.prev_input = 0
    audioProcessor.filterState.bassFilter.prev_output = 0
    audioProcessor.filterState.trebleFilter.prev_input = 0
    audioProcessor.filterState.trebleFilter.prev_output = 0
    
    if audioProcessor.logger then
        audioProcessor.logger.debug("AudioProcessor", "Audio filters reset")
    end
end

-- Get current settings
function audioProcessor.getSettings()
    return {
        bass = audioProcessor.settings.bass,
        treble = audioProcessor.settings.treble,
        volume = audioProcessor.settings.volume,
        enabled = audioProcessor.settings.enabled
    }
end

-- Load settings from table
function audioProcessor.loadSettings(settings)
    if settings.bass ~= nil then
        audioProcessor.setBass(settings.bass)
    end
    if settings.treble ~= nil then
        audioProcessor.setTreble(settings.treble)
    end
    if settings.volume ~= nil then
        audioProcessor.setVolume(settings.volume)
    end
    if settings.enabled ~= nil then
        audioProcessor.setEnabled(settings.enabled)
    end
    
    if audioProcessor.logger then
        audioProcessor.logger.info("AudioProcessor", "Settings loaded: Bass=" .. audioProcessor.settings.bass .. 
                                  ", Treble=" .. audioProcessor.settings.treble .. 
                                  ", Volume=" .. audioProcessor.settings.volume)
    end
end

-- Get a formatted string of current settings for display
function audioProcessor.getDisplayString()
    local bass = audioProcessor.settings.bass
    local treble = audioProcessor.settings.treble
    local volume = math.floor((audioProcessor.settings.volume / 3.0) * 100)
    
    local bassStr = bass > 0 and ("+" .. bass) or tostring(bass)
    local trebleStr = treble > 0 and ("+" .. treble) or tostring(treble)
    
    return string.format("Vol: %d%% | Bass: %s | Treble: %s", volume, bassStr, trebleStr)
end

return audioProcessor 