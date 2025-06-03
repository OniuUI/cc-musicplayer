-- Audio handling module for the radio player
local config = require("musicplayer.config")

local audio = {}

function audio.loop(state)
    while true do
        if state.playing and state.now_playing then
            local thisnowplayingid = state.now_playing.id
            if state.playing_id ~= thisnowplayingid then
                audio.startNewTrack(state, thisnowplayingid)
            elseif state.playing_status == 1 and state.needs_next_chunk == 1 then
                audio.processAudioChunks(state, thisnowplayingid)
            end
        end

        os.pullEvent("audio_update")
    end
end

function audio.startNewTrack(state, trackId)
    state.playing_id = trackId
    state.last_download_url = config.api_base_url .. "?v=" .. config.version .. "&id=" .. textutils.urlEncode(trackId)
    state.playing_status = 0
    state.needs_next_chunk = 1

    http.request({url = state.last_download_url, binary = true})
    state.is_loading = true

    os.queueEvent("redraw_screen")
    os.queueEvent("audio_update")
end

function audio.processAudioChunks(state, trackId)
    while true do
        local chunk = state.player_handle.read(state.size)
        if not chunk then
            audio.handleTrackEnd(state)
            break
        else
            if not audio.processChunk(state, chunk, trackId) then
                break
            end
        end
    end
    os.queueEvent("audio_update")
end

function audio.handleTrackEnd(state)
    if state.looping == 2 or (state.looping == 1 and #state.queue == 0) then
        state.playing_id = nil
    elseif state.looping == 1 and #state.queue > 0 then
        table.insert(state.queue, state.now_playing)
        state.now_playing = state.queue[1]
        table.remove(state.queue, 1)
        state.playing_id = nil
    else
        if #state.queue > 0 then
            state.now_playing = state.queue[1]
            table.remove(state.queue, 1)
            state.playing_id = nil
        else
            state.now_playing = nil
            state.playing = false
            state.playing_id = nil
            state.is_loading = false
            state.is_error = false
        end
    end

    os.queueEvent("redraw_screen")
    state.player_handle.close()
    state.needs_next_chunk = 0
end

function audio.processChunk(state, chunk, trackId)
    if state.start then
        chunk, state.start = state.start .. chunk, nil
        state.size = state.size + config.initial_read_size
    end

    state.buffer = state.decoder(chunk)
    
    local speakerFunctions = {}
    for i, speaker in ipairs(state.speakers) do 
        speakerFunctions[i] = function()
            return audio.playSpeaker(speaker, state.buffer, state.volume, state.playing, state.playing_id, trackId)
        end
    end
    
    local ok, err = pcall(parallel.waitForAll, table.unpack(speakerFunctions))
    if not ok then
        state.needs_next_chunk = 2
        state.is_error = true
        return false
    end
    
    -- If we're not playing anymore, exit the chunk processing loop
    if not state.playing or state.playing_id ~= trackId then
        return false
    end
    
    return true
end

function audio.playSpeaker(speaker, buffer, volume, playing, playingId, trackId)
    local name = peripheral.getName(speaker)
    
    if #{ peripheral.find("speaker") } > 1 then
        if speaker.playAudio(buffer, volume) then
            parallel.waitForAny(
                function()
                    repeat until select(2, os.pullEvent("speaker_audio_empty")) == name
                end,
                function()
                    local event = os.pullEvent("playback_stopped")
                    return
                end
            )
            if not playing or playingId ~= trackId then
                return
            end
        end
    else
        while not speaker.playAudio(buffer, volume) do
            parallel.waitForAny(
                function()
                    repeat until select(2, os.pullEvent("speaker_audio_empty")) == name
                end,
                function()
                    local event = os.pullEvent("playback_stopped")
                    return
                end
            )
            if not playing or playingId ~= trackId then
                return
            end
        end
    end
    
    if not playing or playingId ~= trackId then
        return
    end
end

-- New functions for radio support
function audio.stopAudio()
    -- Stop all speakers
    local speakers = { peripheral.find("speaker") }
    for _, speaker in ipairs(speakers) do
        speaker.stop()
    end
    
    -- Send stop event to interrupt audio processing
    os.queueEvent("playback_stopped")
end

function audio.playFromUrl(streamUrl, startPosition)
    startPosition = startPosition or 0
    
    -- Stop any current playback
    audio.stopAudio()
    
    -- Request the stream with optional start position
    local requestUrl = streamUrl
    if startPosition > 0 then
        -- Add start position parameter if the API supports it
        requestUrl = streamUrl .. "&t=" .. math.floor(startPosition)
    end
    
    http.request({url = requestUrl, binary = true})
    
    -- Handle the response in a separate coroutine
    parallel.waitForAny(
        function()
            while true do
                local event, url, handle = os.pullEvent("http_success")
                if url == requestUrl then
                    audio.streamFromHandle(handle)
                    break
                end
            end
        end,
        function()
            while true do
                local event, url = os.pullEvent("http_failure")
                if url == requestUrl then
                    -- Handle error
                    break
                end
            end
        end
    )
end

function audio.streamFromHandle(handle)
    local speakers = { peripheral.find("speaker") }
    if #speakers == 0 then
        handle.close()
        return
    end
    
    local decoder = require("cc.audio.dfpwm").make_decoder()
    local chunkSize = 16 * 1024
    
    while true do
        local chunk = handle.read(chunkSize)
        if not chunk then
            break
        end
        
        local buffer = decoder(chunk)
        
        -- Play on all speakers
        local speakerFunctions = {}
        for i, speaker in ipairs(speakers) do
            speakerFunctions[i] = function()
                local name = peripheral.getName(speaker)
                while not speaker.playAudio(buffer, 1.0) do
                    parallel.waitForAny(
                        function()
                            repeat until select(2, os.pullEvent("speaker_audio_empty")) == name
                        end,
                        function()
                            os.pullEvent("playback_stopped")
                            return
                        end
                    )
                end
            end
        end
        
        local ok = pcall(parallel.waitForAll, table.unpack(speakerFunctions))
        if not ok then
            break
        end
        
        -- Check for stop event
        local event = os.pullEvent()
        if event == "playback_stopped" then
            break
        end
        os.queueEvent(event) -- Re-queue the event if it wasn't a stop
    end
    
    handle.close()
end

return audio 