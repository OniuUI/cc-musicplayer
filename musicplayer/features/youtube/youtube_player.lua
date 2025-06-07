-- YouTube Music Player Feature
-- Enhanced with proper theme system and components while maintaining working functionality

local youtubeUI = require("musicplayer/ui/layouts/youtube")
local components = require("musicplayer/ui/components")
local themes = require("musicplayer/ui/themes")

local youtubePlayer = {}

function youtubePlayer.init(systemModules)
    local state = {
        -- System modules
        system = systemModules.system,
        httpClient = systemModules.httpClient,
        speakerManager = systemModules.speakerManager,
        errorHandler = systemModules.errorHandler,
        logger = systemModules.logger,
        
        -- UI state
        tab = 1,
        width = 0,
        height = 0,
        
        -- Search state (using original working approach)
        waiting_for_input = false,
        last_search = nil,
        last_search_url = nil,
        search_results = nil,
        search_error = false,
        in_search_result = false,
        clicked_result = nil,
        
        -- Playback state
        playing = false,
        queue = {},
        now_playing = nil,
        looping = 0,
        volume = 1.5,
        
        -- Audio state
        playing_id = nil,
        last_download_url = nil,
        playing_status = 0,
        is_loading = false,
        is_error = false,
        
        -- Audio system
        player_handle = nil,
        start = nil,
        pcm = nil,
        size = nil,
        decoder = require("cc.audio.dfpwm").make_decoder(),
        needs_next_chunk = 0,
        buffer = nil,
        
        -- API configuration (from working original)
        api_base_url = "https://ipod-2to6magyna-uc.a.run.app/",
        version = "2.1"
    }
    
    return state
end

function youtubePlayer.run(state)
    state.logger.info("YouTube", "Starting YouTube music player")
    
    -- Debug monitor setup
    if state.system and state.system.telemetry then
        local monitors = state.system.telemetry.getMonitors()
        state.logger.debug("YouTube", "Available monitors:")
        if monitors.appMonitor then
            state.logger.debug("YouTube", "  App monitor: " .. monitors.appMonitor.side .. " (" .. monitors.appMonitor.width .. "x" .. monitors.appMonitor.height .. ")")
            state.logger.debug("YouTube", "  App monitor supports color: " .. tostring(monitors.appMonitor.isColor))
            
            -- Check if it's an advanced monitor (supports touch)
            local monitor = monitors.appMonitor.peripheral
            if monitor and monitor.isColor then
                local supportsColor = monitor.isColor()
                state.logger.info("YouTube", "Monitor supports color (Advanced Monitor): " .. tostring(supportsColor))
                if supportsColor then
                    state.logger.info("YouTube", "This monitor should support touch events (monitor_touch)")
                else
                    state.logger.warn("YouTube", "This is a regular monitor - touch events (monitor_touch) are NOT supported!")
                    state.logger.warn("YouTube", "You need an Advanced Monitor (gold-based) for touch functionality")
                end
            else
                state.logger.warn("YouTube", "Cannot determine monitor type - touch support unknown")
            end
        else
            state.logger.debug("YouTube", "  No app monitor")
        end
        if monitors.logMonitor then
            state.logger.debug("YouTube", "  Log monitor: " .. monitors.logMonitor.side .. " (" .. monitors.logMonitor.width .. "x" .. monitors.logMonitor.height .. ")")
        else
            state.logger.debug("YouTube", "  No log monitor")
        end
        
        local isOnMonitor = state.system.telemetry.isRunningOnMonitor()
        local currentSide = state.system.telemetry.getCurrentMonitorSide()
        state.logger.debug("YouTube", "Running on monitor: " .. tostring(isOnMonitor))
        state.logger.debug("YouTube", "Current monitor side: " .. tostring(currentSide))
        
        -- Log current terminal info
        local currentTerm = term.current()
        state.logger.debug("YouTube", "Current terminal type: " .. tostring(type(currentTerm)))
        if currentTerm and currentTerm.getSize then
            local w, h = currentTerm.getSize()
            state.logger.debug("YouTube", "Current terminal size: " .. w .. "x" .. h)
        end
    else
        state.logger.warn("YouTube", "No telemetry system available for monitor debugging")
    end
    
    -- Initialize screen dimensions
    state.width, state.height = term.getSize()
    state.logger.debug("YouTube", "Screen dimensions: " .. state.width .. "x" .. state.height)
    
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

-- UI Loop (simplified to match old working version)
function youtubePlayer.uiLoop(state, speakers)
    youtubeUI.redrawScreen(state)
    
    state.logger.info("YouTube", "YouTube player ready - UI is now interactive!")

    while true do
        -- Update screen dimensions
        state.width, state.height = term.getSize()
        
        if state.waiting_for_input then
            parallel.waitForAny(
                function()
                    -- Use original working input handling with theme colors
                    local theme = themes.getCurrent()
                    
                    -- Draw search box with theme colors (original coordinates y=3-5)
                    for y = 3, 5 do
                        term.setCursorPos(2, y)
                        term.setBackgroundColor(theme.colors.search_box)
                        term.clearLine()
                    end
                    
                    term.setCursorPos(3, 4)  -- Original working position
                    term.setBackgroundColor(theme.colors.search_box)
                    term.setTextColor(theme.colors.text_primary)
                    local input = read()

                    -- Validate and process input
                    if input and string.len(input) > 0 then
                        -- Trim whitespace
                        input = input:match("^%s*(.-)%s*$")
                        
                        if string.len(input) > 0 then
                            -- URL encode the input safely
                            local success, encodedInput = pcall(textutils.urlEncode, input)
                            if success and encodedInput then
                                state.last_search = input
                                state.last_search_url = state.api_base_url .. "?v=" .. state.version .. "&search=" .. encodedInput
                                
                                -- Make HTTP request with error handling
                                local requestSuccess, requestError = pcall(http.request, state.last_search_url)
                                if requestSuccess then
                                    state.search_results = nil
                                    state.search_error = false
                                    state.logger.info("YouTube", "Searching for: " .. input)
                                else
                                    state.search_error = true
                                    state.search_results = nil
                                    state.logger.error("YouTube", "Failed to make search request: " .. tostring(requestError))
                                end
                            else
                                state.search_error = true
                                state.search_results = nil
                                state.logger.error("YouTube", "Failed to encode search input")
                            end
                        else
                            state.logger.debug("YouTube", "Empty search input after trimming")
                        end
                    else
                        state.logger.debug("YouTube", "No search input provided")
                    end

                    state.waiting_for_input = false
                    os.queueEvent("redraw_screen")
                end,
                function()
                    while state.waiting_for_input do
                        local event, button, x, y = os.pullEvent("mouse_click")
                        if y < 3 or y > 5 or x < 2 or x > state.width-1 then
                            state.waiting_for_input = false
                            os.queueEvent("redraw_screen")
                            break
                        end
                    end
                end
            )
        else
            -- SIMPLIFIED EVENT HANDLING - Based on old working version
            parallel.waitForAny(
                function()
                    local event, button, x, y = os.pullEvent("mouse_click")
                    
                    if button == 1 then
                        state.logger.debug("YouTube", "Mouse click at (" .. x .. "," .. y .. ")")
                        
                        -- Back to menu button (FIRST CHECK - highest priority)
                        if y == state.height - 3 and x >= 2 and x <= 17 then
                            state.logger.info("YouTube", "Back to menu button clicked")
                            return "back_to_menu"
                        end
                        
                        -- Tabs (using original working logic)
                        if state.in_search_result == false then
                            if y == 2 then -- Tab row
                                if x < state.width/2 then
                                    state.tab = 1
                                    state.logger.debug("YouTube", "Switched to tab 1 (Now Playing)")
                                else
                                    state.tab = 2
                                    state.logger.debug("YouTube", "Switched to tab 2 (Search)")
                                end
                                youtubeUI.redrawScreen(state)
                            end
                        end
                        
                        -- Search tab handling (using original working coordinates)
                        if state.tab == 2 and state.in_search_result == false then
                            -- Search box click
                            if y >= 3 and y <= 5 and x >= 2 and x <= state.width - 1 then
                                state.logger.debug("YouTube", "Search box clicked")
                                paintutils.drawFilledBox(2, 3, state.width-1, 5, colors.white)
                                term.setBackgroundColor(colors.white)
                                term.setTextColor(colors.black)
                                state.waiting_for_input = true
                            end

                            -- Search result clicks (using original working coordinates)
                            if state.search_results then
                                for i=1, #state.search_results do
                                    local resultY1 = 7 + (i-1)*2  -- First line of result
                                    local resultY2 = 8 + (i-1)*2  -- Second line of result
                                    if (y == resultY1 or y == resultY2) and resultY2 < state.height - 2 then
                                        state.logger.info("YouTube", "Clicked on search result " .. i .. ": " .. state.search_results[i].name)
                                        -- Highlight selected result (original style)
                                        term.setBackgroundColor(colors.white)
                                        term.setTextColor(colors.black)
                                        term.setCursorPos(2, resultY1)
                                        term.clearLine()
                                        term.write(state.search_results[i].name)
                                        term.setTextColor(colors.gray)
                                        term.setCursorPos(2, resultY2)
                                        term.clearLine()
                                        term.write(state.search_results[i].artist)
                                        sleep(0.2)
                                        state.in_search_result = true
                                        state.clicked_result = i
                                        youtubeUI.redrawScreen(state)
                                    end
                                end
                            end
                        elseif state.tab == 2 and state.in_search_result == true then
                            -- Song action menu clicks (using original working logic)
                            local theme = themes.getCurrent()
                            term.setBackgroundColor(theme.colors.button_active)
                            term.setTextColor(theme.colors.background)

                            if y == 6 then -- Play now
                                term.setCursorPos(2, 6)
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
                                
                            elseif y == 8 then -- Play next
                                term.setCursorPos(2, 8)
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
                                
                            elseif y == 10 then -- Add to queue
                                term.setCursorPos(2, 10)
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
                                
                            elseif y == 13 then -- Cancel
                                term.setCursorPos(2, 13)
                                term.clearLine()
                                term.write("Cancel")
                                sleep(0.2)
                                state.in_search_result = false
                            end

                            youtubeUI.redrawScreen(state)
                        elseif state.tab == 1 and state.in_search_result == false then
                            -- Now playing tab clicks (using original working logic)
                            if y == 7 then -- Control buttons row
                                -- Play/stop button
                                if x >= 2 and x < 2 + 6 then
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

                                -- Skip button
                                if x >= 2 + 7 and x < 2 + 7 + 6 then
                                    if state.now_playing ~= nil or #state.queue > 0 then
                                        local theme = themes.getCurrent()
                                        term.setBackgroundColor(theme.colors.button_active)
                                        term.setTextColor(theme.colors.background)
                                        term.setCursorPos(2 + 7, 7)
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

                                -- Loop button
                                if x >= 2 + 7 + 7 and x < 2 + 7 + 7 + 12 then
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

                            -- Volume slider handling (using original working coordinates)
                            if y == 11 then -- Volume slider row
                                if x >= 2 and x < 2 + 24 then
                                    state.volume = (x - 2) / 24 * 3.0
                                    state.speakerManager.setVolume(state.volume)
                                    state.logger.debug("YouTube", "Volume set to " .. math.floor((state.volume / 3.0) * 100) .. "%")
                                end
                            end

                            youtubeUI.redrawScreen(state)
                        end
                    end
                end,
                function()
                    local event, button, x, y = os.pullEvent("mouse_drag")
                    
                    if button == 1 and state.tab == 1 and state.in_search_result == false then
                        -- Volume slider drag (using original working coordinates)
                        if y == 11 then -- Volume slider row
                            if x >= 2 and x < 2 + 24 then
                                state.volume = (x - 2) / 24 * 3.0
                                state.speakerManager.setVolume(state.volume)
                                state.logger.debug("YouTube", "Volume dragged to " .. math.floor((state.volume / 3.0) * 100) .. "%")
                            end
                            youtubeUI.redrawScreen(state)
                        end
                    end
                end,
                function()
                    local event = os.pullEvent("redraw_screen")
                    youtubeUI.redrawScreen(state)
                end
            )
        end
        
        -- Check if we need to return to menu
        if event == "back_to_menu" then
            return "menu"
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
                        local responseText = handle.readAll()
                        if not responseText or responseText == "" then
                            error("Empty response from search API")
                        end
                        
                        local parseSuccess, data = pcall(textutils.unserialiseJSON, responseText)
                        if not parseSuccess then
                            error("Failed to parse JSON response: " .. tostring(data))
                        end
                        
                        if not data or type(data) ~= "table" then
                            error("Invalid response format from search API")
                        end
                        
                        return data
                    end, "YouTube search response parsing")
                    
                    handle.close()
                    
                    if success and results then
                        state.search_results = results
                        state.search_error = false -- Clear any previous search errors
                        state.logger.info("YouTube", "Search completed: " .. #results .. " results")
                    else
                        state.search_results = nil
                        state.search_error = true
                        state.logger.error("YouTube", "Failed to parse search results: " .. tostring(results))
                    end
                    os.queueEvent("redraw_screen")
                end
                
                if url == state.last_download_url then
                    local success, error = state.errorHandler.safeExecute(function()
                        state.is_loading = false
                        state.player_handle = handle
                        state.start = handle.read(4)
                        state.size = 16 * 1024 - 4
                        state.playing_status = 1
                        state.logger.info("YouTube", "Audio stream ready")
                    end, "YouTube audio stream setup")
                    
                    if not success then
                        state.is_loading = false
                        state.is_error = true
                        state.playing = false
                        state.playing_id = nil
                        handle.close()
                        state.logger.error("YouTube", "Audio stream setup failed: " .. tostring(error))
                    end
                    
                    os.queueEvent("redraw_screen")
                    os.queueEvent("audio_update")
                end
            end,
            function()
                local event, url, errorMsg = os.pullEvent("http_failure") 

                if url == state.last_search_url then
                    state.search_error = true
                    state.search_results = nil
                    state.logger.error("YouTube", "Search request failed for URL: " .. tostring(url) .. " - " .. tostring(errorMsg))
                    os.queueEvent("redraw_screen")
                end
                
                if url == state.last_download_url then
                    state.is_loading = false
                    state.is_error = true
                    state.playing = false
                    state.playing_id = nil
                    state.logger.error("YouTube", "Audio stream request failed for URL: " .. tostring(url) .. " - " .. tostring(errorMsg))
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