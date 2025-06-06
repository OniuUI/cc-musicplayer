-- YouTube Music Player Feature
-- Enhanced with complete working functionality from original while maintaining modular architecture

local youtubeUI = require("musicplayer.ui.layouts.youtube")
local themes = require("musicplayer.ui.themes")

local youtubePlayer = {}

function youtubePlayer.init(systemState)
    return {
        -- UI state
        tab = 1,
        width = 0,
        height = 0,
        
        -- Playback state (from working original)
        playing = false,
        volume = 1.5, -- Default volume from working original
        looping = 0, -- 0 = off, 1 = queue, 2 = song
        
        -- Current content
        now_playing = nil,
        queue = {},
        
        -- Search state (from working original)
        search_results = nil,
        search_error = false,
        last_search = nil,
        last_search_url = nil,
        in_search_result = false,
        clicked_result = nil,
        
        -- Loading states
        is_loading = false,
        is_error = false,
        waiting_for_input = false,
        
        -- Audio processing state (from working original)
        playing_id = nil,
        last_download_url = nil,
        playing_status = 0,
        player_handle = nil,
        start = nil,
        pcm = nil,
        size = nil,
        decoder = require("cc.audio.dfpwm").make_decoder(),
        needs_next_chunk = 0,
        buffer = nil,
        
        -- System references
        system = systemState,
        httpClient = systemState.httpClient,
        speakerManager = systemState.speakerManager,
        errorHandler = systemState.errorHandler,
        logger = systemState.logger,
        
        -- API configuration (from working original)
        api_base_url = "https://ipod-2to6magyna-uc.a.run.app/",
        version = "2.1"
    }
end

function youtubePlayer.run(state)
    -- Initialize screen dimensions
    state.width, state.height = term.getSize()
    
    -- Get raw speakers for direct access (like working original)
    local speakers = state.speakerManager.getRawSpeakers()
    if #speakers == 0 then
        state.errorHandler.handleError("YouTube", "No speakers attached. You need to connect a speaker to this computer.", 3)
        return "menu"
    end
    
    -- Run the main loops in parallel (from working original)
    parallel.waitForAny(
        function() return youtubePlayer.uiLoop(state, speakers) end,
        function() return youtubePlayer.audioLoop(state, speakers) end,
        function() return youtubePlayer.httpLoop(state) end
    )
    
    -- Cleanup
    youtubePlayer.cleanup(state)
    return "menu"
end

-- UI Loop (enhanced from working original with our error handling)
function youtubePlayer.uiLoop(state, speakers)
    youtubeUI.redrawScreen(state)

    while true do
        if state.waiting_for_input then
            parallel.waitForAny(
                function()
                    local theme = themes.getCurrent()
                    term.setCursorPos(3, 5) -- Adjusted for header and component layout
                    term.setBackgroundColor(theme.colors.search_box)
                    term.setTextColor(theme.colors.text_primary)
                    local input = read()

                    if string.len(input) > 0 then
                        state.last_search = input
                        state.last_search_url = state.api_base_url .. "?v=" .. state.version .. "&search=" .. textutils.urlEncode(input)
                        http.request(state.last_search_url)
                        state.search_results = nil
                        state.search_error = false
                        state.logger.info("YouTube", "Search requested: " .. input)
                    else
                        state.last_search = nil
                        state.last_search_url = nil
                        state.search_results = nil
                        state.search_error = false
                    end

                    state.waiting_for_input = false
                    os.queueEvent("redraw_screen")
                end,
                function()
                    while state.waiting_for_input do
                        local event, button, x, y = os.pullEvent()
                        -- Handle both mouse_click and monitor_touch
                        if event == "mouse_click" or event == "monitor_touch" then
                            if event == "monitor_touch" then
                                button = 1 -- Treat monitor touch as left click
                            end
                            -- Adjusted coordinates for header and component layout
                            if y ~= 5 or x < 2 or x > state.width-1 then
                                state.waiting_for_input = false
                                os.queueEvent("redraw_screen")
                                break
                            end
                        end
                    end
                end
            )
        else
            parallel.waitForAny(
                function()
                    local event, param1, param2, param3 = os.pullEvent()
                    -- Handle both mouse_click and monitor_touch
                    if event == "mouse_click" or event == "monitor_touch" then
                        local button, x, y
                        if event == "mouse_click" then
                            button, x, y = param1, param2, param3
                        else -- monitor_touch
                            button, x, y = 1, param2, param3  -- Treat monitor touch as left click
                        end
                        return youtubePlayer.handleClick(state, speakers, button, x, y)
                    end
                end,
                function()
                    local event, param1, param2, param3 = os.pullEvent()
                    -- Handle both mouse_drag and monitor_drag
                    if event == "mouse_drag" or event == "monitor_drag" then
                        local button, x, y
                        if event == "mouse_drag" then
                            button, x, y = param1, param2, param3
                        else -- monitor_drag
                            button, x, y = 1, param2, param3  -- Treat monitor drag as left drag
                        end
                        return youtubePlayer.handleDrag(state, button, x, y)
                    end
                end,
                function()
                    local event = os.pullEvent("redraw_screen")
                    youtubeUI.redrawScreen(state)
                end
            )
        end
    end
end

-- Handle mouse clicks (from working original with our error handling and coordinate adjustments)
function youtubePlayer.handleClick(state, speakers, button, x, y)
    if button == 1 then
        -- Tab clicks (adjusted for header)
        if state.in_search_result == false then
            if y == 2 then -- Tab row is now at y=2
                if x < state.width/2 then
                    state.tab = 1
                else
                    state.tab = 2
                end
                youtubeUI.redrawScreen(state)
                return
            end
        end
        
        -- Search tab handling
        if state.tab == 2 and state.in_search_result == false then
            -- Search box click (adjusted for header and component layout)
            if y == 5 and x >= 2 and x <= state.width - 1 then
                local theme = themes.getCurrent()
                -- Clear and prepare search input area
                term.setBackgroundColor(theme.colors.search_box)
                term.setTextColor(theme.colors.text_primary)
                term.setCursorPos(2, 5)
                term.clearLine()
                state.waiting_for_input = true
                return
            end

            -- Search result clicks (adjusted for header and component layout)
            if state.search_results then
                for i=1, #state.search_results do
                    local resultY = 8 + (i-1)
                    if y == resultY and resultY < state.height - 2 then
                        -- Highlight selected result
                        local theme = themes.getCurrent()
                        term.setBackgroundColor(theme.colors.button_hover)
                        term.setTextColor(theme.colors.text_primary)
                        term.setCursorPos(2, resultY)
                        term.clearLine()
                        term.write(state.search_results[i].name)
                        sleep(0.2)
                        state.in_search_result = true
                        state.clicked_result = i
                        youtubeUI.redrawScreen(state)
                        return
                    end
                end
            end
        elseif state.tab == 2 and state.in_search_result == true then
            -- Song action menu clicks (adjusted for header)
            youtubePlayer.handleSongActionClick(state, speakers, y)
            return
        elseif state.tab == 1 and state.in_search_result == false then
            -- Now playing tab clicks (adjusted for header)
            youtubePlayer.handleNowPlayingClick(state, speakers, x, y)
            return
        end
        
        -- Back to menu button (adjusted for footer)
        if y == state.height - 3 and x >= 2 and x <= 15 then
            return "back_to_menu"
        end
    end
end

-- Handle song action menu clicks (adjusted for header)
function youtubePlayer.handleSongActionClick(state, speakers, y)
    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)

    if y == 7 then -- Play now (adjusted for header)
        term.setCursorPos(2, 7)
        term.clearLine()
        term.write("Play now")
        sleep(0.2)
        state.in_search_result = false
        
        -- Stop current playback
        for _, speaker in ipairs(speakers) do
            speaker.stop()
            os.queueEvent("playback_stopped")
        end
        
        state.playing = true
        state.is_error = false
        state.playing_id = nil
        
        local selectedSong = state.search_results[state.clicked_result]
        if selectedSong.type == "playlist" then
            state.now_playing = selectedSong.playlist_items[1]
            state.queue = {}
            if #selectedSong.playlist_items > 1 then
                for i=2, #selectedSong.playlist_items do
                    table.insert(state.queue, selectedSong.playlist_items[i])
                end
            end
        else
            state.now_playing = selectedSong
        end
        
        state.logger.info("YouTube", "Playing now: " .. state.now_playing.name)
        os.queueEvent("audio_update")
        
    elseif y == 9 then -- Play next (adjusted for header)
        term.setCursorPos(2, 9)
        term.clearLine()
        term.write("Play next")
        sleep(0.2)
        state.in_search_result = false
        
        local selectedSong = state.search_results[state.clicked_result]
        if selectedSong.type == "playlist" then
            for i = #selectedSong.playlist_items, 1, -1 do
                table.insert(state.queue, 1, selectedSong.playlist_items[i])
            end
        else
            table.insert(state.queue, 1, selectedSong)
        end
        
        state.logger.info("YouTube", "Added to play next: " .. selectedSong.name)
        os.queueEvent("audio_update")
        
    elseif y == 11 then -- Add to queue (adjusted for header)
        term.setCursorPos(2, 11)
        term.clearLine()
        term.write("Add to queue")
        sleep(0.2)
        state.in_search_result = false
        
        local selectedSong = state.search_results[state.clicked_result]
        if selectedSong.type == "playlist" then
            for i = 1, #selectedSong.playlist_items do
                table.insert(state.queue, selectedSong.playlist_items[i])
            end
        else
            table.insert(state.queue, selectedSong)
        end
        
        state.logger.info("YouTube", "Added to queue: " .. selectedSong.name)
        os.queueEvent("audio_update")
        
    elseif y == 14 then -- Cancel (adjusted for header)
        term.setCursorPos(2, 14)
        term.clearLine()
        term.write("Cancel")
        sleep(0.2)
        state.in_search_result = false
    end

    youtubeUI.redrawScreen(state)
end

-- Handle now playing clicks (adjusted for header and new component layout)
function youtubePlayer.handleNowPlayingClick(state, speakers, x, y)
    if y == 7 then -- Control buttons row (adjusted for header)
        -- Play/stop button (new position from components)
        if x >= 2 and x <= 7 then -- "Play" or "Stop" button
            if state.playing or state.now_playing ~= nil or #state.queue > 0 then
                local theme = themes.getCurrent()
                term.setBackgroundColor(theme.colors.button_active)
                term.setTextColor(theme.colors.background)
                term.setCursorPos(2, 7)
                if state.playing then
                    term.write(" Stop ")
                else 
                    term.write(" Play ")
                end
                sleep(0.2)
            end
            
            if state.playing then
                state.playing = false
                for _, speaker in ipairs(speakers) do
                    speaker.stop()
                    os.queueEvent("playback_stopped")
                end
                state.playing_id = nil
                state.is_loading = false
                state.is_error = false
                state.logger.info("YouTube", "Playback stopped")
                os.queueEvent("audio_update")
            elseif state.now_playing ~= nil then
                state.playing_id = nil
                state.playing = true
                state.is_error = false
                state.logger.info("YouTube", "Playback resumed")
                os.queueEvent("audio_update")
            elseif #state.queue > 0 then
                state.now_playing = state.queue[1]
                table.remove(state.queue, 1)
                state.playing_id = nil
                state.playing = true
                state.is_error = false
                state.logger.info("YouTube", "Playing from queue: " .. state.now_playing.name)
                os.queueEvent("audio_update")
            end
        end

        -- Skip button (new position from components)
        if x >= 9 and x <= 14 then -- "Skip" button
            if state.now_playing ~= nil or #state.queue > 0 then
                local theme = themes.getCurrent()
                term.setBackgroundColor(theme.colors.button_active)
                term.setTextColor(theme.colors.background)
                term.setCursorPos(9, 7)
                term.write(" Skip ")
                sleep(0.2)

                state.is_error = false
                if state.playing then
                    for _, speaker in ipairs(speakers) do
                        speaker.stop()
                        os.queueEvent("playback_stopped")
                    end
                end
                
                if #state.queue > 0 then
                    if state.looping == 1 then
                        table.insert(state.queue, state.now_playing)
                    end
                    state.now_playing = state.queue[1]
                    table.remove(state.queue, 1)
                    state.playing_id = nil
                    state.logger.info("YouTube", "Skipped to: " .. state.now_playing.name)
                else
                    state.now_playing = nil
                    state.playing = false
                    state.is_loading = false
                    state.is_error = false
                    state.playing_id = nil
                    state.logger.info("YouTube", "Queue finished")
                end
                os.queueEvent("audio_update")
            end
        end

        -- Loop button (new position from components)
        if x >= 16 and x <= 27 then -- "Loop Off/Queue/Song" button
            if state.looping == 0 then
                state.looping = 1
            elseif state.looping == 1 then
                state.looping = 2
            else
                state.looping = 0
            end
            local loopModes = {"OFF", "QUEUE", "SONG"}
            state.logger.info("YouTube", "Loop mode: " .. loopModes[state.looping + 1])
        end
    end

    -- Volume slider handling (using component position)
    if y >= 10 and y <= 11 then -- Volume slider area (adjusted for header and component position)
        if x >= 3 and x <= 23 then -- Volume slider range
            local sliderWidth = 20
            local newVolume = ((x - 3) / sliderWidth) * 3.0
            state.volume = math.max(0, math.min(3.0, newVolume))
            state.speakerManager.setVolume(state.volume)
            state.logger.debug("YouTube", "Volume set to " .. math.floor((state.volume / 3.0) * 100) .. "%")
        end
    end

    -- Back to menu button (using component position)
    if y == state.height - 3 and x >= 2 and x <= 15 then
        return "back_to_menu"
    end

    youtubeUI.redrawScreen(state)
end

-- Handle mouse drag (adjusted for header and component layout)
function youtubePlayer.handleDrag(state, button, x, y)
    if button == 1 and state.tab == 1 and state.in_search_result == false then
        -- Volume slider area (adjusted for header and component position)
        if y >= 10 and y <= 11 then -- Volume slider area from components
            if x >= 3 and x <= 23 then -- Volume slider range
                local sliderWidth = 20
                local newVolume = ((x - 3) / sliderWidth) * 3.0
                state.volume = math.max(0, math.min(3.0, newVolume))
                state.speakerManager.setVolume(state.volume)
                state.logger.debug("YouTube", "Volume dragged to " .. math.floor((state.volume / 3.0) * 100) .. "%")
            end
            youtubeUI.redrawScreen(state)
        end
    end
end

-- Audio Loop (from working original with our error handling)
function youtubePlayer.audioLoop(state, speakers)
    while true do
        -- Audio processing (from working original)
        if state.playing and state.now_playing then
            local thisnowplayingid = state.now_playing.id
            if state.playing_id ~= thisnowplayingid then
                state.playing_id = thisnowplayingid
                state.last_download_url = state.api_base_url .. "?v=" .. state.version .. "&id=" .. textutils.urlEncode(state.playing_id)
                state.playing_status = 0
                state.needs_next_chunk = 1

                http.request({url = state.last_download_url, binary = true})
                state.is_loading = true
                state.logger.info("YouTube", "Requesting audio stream for: " .. state.now_playing.name)

                os.queueEvent("redraw_screen")
                os.queueEvent("audio_update")
            elseif state.playing_status == 1 and state.needs_next_chunk == 1 then
                -- Process audio chunks (from working original)
                youtubePlayer.processAudioChunks(state, speakers, thisnowplayingid)
                os.queueEvent("audio_update")
            end
        end

        os.pullEvent("audio_update")
    end
end

-- Process audio chunks (from working original with our error handling)
function youtubePlayer.processAudioChunks(state, speakers, thisnowplayingid)
    local success, err = state.errorHandler.safeExecute(function()
        while true do
            local chunk = state.player_handle.read(state.size)
            if not chunk then
                -- Handle end of stream
                youtubePlayer.handleEndOfStream(state)
                state.player_handle.close()
                state.needs_next_chunk = 0
                break
            else
                -- Process chunk
                if state.start then
                    chunk, state.start = state.start .. chunk, nil
                    state.size = state.size + 4
                end
        
                state.buffer = state.decoder(chunk)
                
                -- Play on all speakers (from working original)
                local success = youtubePlayer.playOnAllSpeakers(state, speakers, thisnowplayingid)
                if not success then
                    state.needs_next_chunk = 2
                    state.is_error = true
                    break
                end
                
                -- Check if playback was stopped
                if not state.playing or state.playing_id ~= thisnowplayingid then
                    break
                end
            end
        end
    end, "YouTube audio processing")
    
    if not success then
        state.is_error = true
        state.logger.error("YouTube", "Audio processing failed: " .. tostring(err))
    end
end

-- Play audio on all speakers (from working original)
function youtubePlayer.playOnAllSpeakers(state, speakers, thisnowplayingid)
    local fn = {}
    for i, speaker in ipairs(speakers) do 
        fn[i] = function()
            local name = peripheral.getName(speaker)
            if #speakers > 1 then
                if speaker.playAudio(state.buffer, state.volume) then
                    parallel.waitForAny(
                        function()
                            repeat until select(2, os.pullEvent("speaker_audio_empty")) == name
                        end,
                        function()
                            os.pullEvent("playback_stopped")
                            return
                        end
                    )
                    if not state.playing or state.playing_id ~= thisnowplayingid then
                        return
                    end
                end
            else
                while not speaker.playAudio(state.buffer, state.volume) do
                    parallel.waitForAny(
                        function()
                            repeat until select(2, os.pullEvent("speaker_audio_empty")) == name
                        end,
                        function()
                            os.pullEvent("playback_stopped")
                            return
                        end
                    )
                    if not state.playing or state.playing_id ~= thisnowplayingid then
                        return
                    end
                end
            end
            if not state.playing or state.playing_id ~= thisnowplayingid then
                return
            end
        end
    end
    
    local ok, err = pcall(parallel.waitForAll, table.unpack(fn))
    return ok
end

-- Handle end of stream (from working original)
function youtubePlayer.handleEndOfStream(state)
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
end

-- HTTP Loop (from working original with our error handling)
function youtubePlayer.httpLoop(state)
    while true do
        parallel.waitForAny(
            function()
                local event, url, handle = os.pullEvent("http_success")

                if url == state.last_search_url then
                    local success, results = state.errorHandler.safeExecute(function()
                        return textutils.unserialiseJSON(handle.readAll())
                    end, "YouTube search response parsing")
                    
                    if success then
                        state.search_results = results
                        state.logger.info("YouTube", "Search completed: " .. #results .. " results")
                    else
                        state.search_error = true
                        state.logger.error("YouTube", "Failed to parse search results")
                    end
                    os.queueEvent("redraw_screen")
                end
                
                if url == state.last_download_url then
                    state.is_loading = false
                    state.player_handle = handle
                    state.start = handle.read(4)
                    state.size = 16 * 1024 - 4
                    state.playing_status = 1
                    state.logger.info("YouTube", "Audio stream ready")
                    os.queueEvent("redraw_screen")
                    os.queueEvent("audio_update")
                end
            end,
            function()
                local event, url = os.pullEvent("http_failure") 

                if url == state.last_search_url then
                    state.search_error = true
                    state.logger.error("YouTube", "Search request failed")
                    os.queueEvent("redraw_screen")
                end
                
                if url == state.last_download_url then
                    state.is_loading = false
                    state.is_error = true
                    state.playing = false
                    state.playing_id = nil
                    state.logger.error("YouTube", "Audio stream request failed")
                    os.queueEvent("redraw_screen")
                    os.queueEvent("audio_update")
                end
            end
        )
    end
end

function youtubePlayer.cleanup(state)
    local success, error = state.errorHandler.safeExecute(function()
        state.speakerManager.stopAll()
        state.playing = false
        if state.player_handle then
            state.player_handle.close()
        end
        state.logger.info("YouTube", "YouTube player cleaned up")
    end, "YouTube cleanup")
    
    if not success then
        state.logger.error("YouTube", "Cleanup failed: " .. tostring(error))
    end
end

return youtubePlayer 