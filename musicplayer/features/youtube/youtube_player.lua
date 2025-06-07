-- YouTube Music Player Feature
-- Enhanced with proper theme system and components while maintaining working functionality

local youtubeUI = require("musicplayer.ui.layouts.youtube")
local components = require("musicplayer.ui.components")
local themes = require("musicplayer.ui.themes")

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

-- UI Loop (enhanced from working original with our error handling)
function youtubePlayer.uiLoop(state, speakers)
    youtubeUI.redrawScreen(state)
    
    -- Add event debugging for the first few seconds to help diagnose issues
    state.logger.info("YouTube", "Starting UI loop - try clicking on the monitor now!")
    youtubePlayer.debugEvents(state, 5) -- Debug events for 5 seconds

    while true do
        -- Update screen dimensions
        state.width, state.height = term.getSize()
        
        -- Handle input with proper theme integration and timeout
        local action = youtubePlayer.handleInputWithTimeout(state, speakers, 0.5) -- 0.5 second timeout
        
        if action == "back_to_menu" then
            return "menu"
        elseif action == "redraw" then
            youtubeUI.redrawScreen(state)
        elseif action == "timeout" then
            -- Periodic update to keep UI responsive
            youtubeUI.redrawScreen(state)
        end
    end
end

-- Handle input with timeout to keep UI responsive
function youtubePlayer.handleInputWithTimeout(state, speakers, timeout)
    if state.waiting_for_input then
        return youtubePlayer.handleInput(state, speakers)
    end
    
    -- Use pullEventRaw with timeout to allow periodic updates
    local event, param1, param2, param3 = os.pullEventRaw(timeout)
    
    if not event then
        return "timeout" -- Timeout occurred, allows periodic UI updates
    end
    
    -- Handle escape key to force exit
    if event == "key" and param1 == keys.escape then
        state.logger.info("YouTube", "Escape key pressed - returning to menu")
        return "back_to_menu"
    end
    
    -- Handle both mouse_click and monitor_touch
    if event == "mouse_click" or event == "monitor_touch" then
        local button, x, y, monitorSide
        if event == "mouse_click" then
            button, x, y = param1, param2, param3
            state.logger.debug("YouTube", "Mouse click at (" .. x .. "," .. y .. ") button=" .. button)
        else -- monitor_touch
            -- monitor_touch returns: event, side, x, y (no button parameter)
            -- param1 = side, param2 = x, param3 = y
            monitorSide = param1
            x, y = param2, param3
            button = 1  -- Treat monitor touch as left click
            
            state.logger.debug("YouTube", "Monitor touch during input on side '" .. tostring(monitorSide) .. "' at (" .. x .. "," .. y .. ")")
            
            -- Check if we're running on a monitor and if this touch is from the correct monitor
            if state.system and state.system.telemetry then
                local currentMonitorSide = state.system.telemetry.getCurrentMonitorSide()
                if currentMonitorSide and monitorSide ~= currentMonitorSide then
                    state.logger.debug("YouTube", "Ignoring touch from different monitor during input: " .. monitorSide)
                    break -- Continue waiting for input
                end
            end
        end
        
        local result = youtubePlayer.handleClick(state, speakers, button, x, y)
        if result then
            return result
        end
    elseif event == "redraw_screen" then
        return "redraw"
    end
    
    return nil
end

function youtubePlayer.handleInput(state, speakers)
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
                        -- Validate input length (prevent extremely long URLs that could cause issues)
                        if string.len(input) > 500 then
                            state.search_error = true
                            state.search_results = nil
                            state.logger.warn("YouTube", "Search input too long (max 500 characters)")
                        else
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
                    local event, param1, param2, param3 = os.pullEvent()
                    if event == "mouse_click" or event == "monitor_touch" then
                        local button, x, y, monitorSide
                        if event == "mouse_click" then
                            button, x, y = param1, param2, param3
                            state.logger.debug("YouTube", "Regular mouse click at (" .. x .. "," .. y .. ") button=" .. button)
                        else -- monitor_touch
                            -- monitor_touch returns: event, side, x, y (no button parameter)
                            -- param1 = side, param2 = x, param3 = y
                            monitorSide = param1
                            x, y = param2, param3
                            button = 1  -- Treat monitor touch as left click
                            
                            state.logger.debug("YouTube", "Regular monitor touch on side '" .. tostring(monitorSide) .. "' at (" .. x .. "," .. y .. ")")
                            
                            -- Check if we're running on a monitor and if this touch is from the correct monitor
                            if state.system and state.system.telemetry then
                                local currentMonitorSide = state.system.telemetry.getCurrentMonitorSide()
                                if currentMonitorSide then
                                    state.logger.debug("YouTube", "Currently running on monitor: " .. currentMonitorSide)
                                    if monitorSide ~= currentMonitorSide then
                                        state.logger.debug("YouTube", "Ignoring touch from different monitor: " .. monitorSide .. " (expected: " .. currentMonitorSide .. ")")
                                        -- Continue to next event instead of processing this touch
                                        goto continue
                                    end
                                else
                                    state.logger.debug("YouTube", "Not running on a monitor, processing touch from: " .. monitorSide)
                                end
                            else
                                state.logger.debug("YouTube", "No telemetry system available, processing touch from: " .. monitorSide)
                            end
                        end
                        
                        -- Use original working coordinates for click-outside detection
                        if y < 3 or y > 5 or x < 2 or x > state.width-1 then
                            state.waiting_for_input = false
                            os.queueEvent("redraw_screen")
                            break
                        end
                    end
                end
            end
        )
        return "redraw"
    end
    
    -- Regular input handling
    while true do
        local event, param1, param2, param3 = os.pullEvent()
        -- Handle both mouse_click and monitor_touch
        if event == "mouse_click" or event == "monitor_touch" then
            local button, x, y, monitorSide
            if event == "mouse_click" then
                button, x, y = param1, param2, param3
                state.logger.debug("YouTube", "Regular mouse click at (" .. x .. "," .. y .. ") button=" .. button)
            else -- monitor_touch
                -- monitor_touch returns: event, side, x, y (no button parameter)
                -- param1 = side, param2 = x, param3 = y
                monitorSide = param1
                x, y = param2, param3
                button = 1  -- Treat monitor touch as left click
                
                state.logger.debug("YouTube", "Regular monitor touch on side '" .. tostring(monitorSide) .. "' at (" .. x .. "," .. y .. ")")
                
                -- Check if we're running on a monitor and if this touch is from the correct monitor
                if state.system and state.system.telemetry then
                    local currentMonitorSide = state.system.telemetry.getCurrentMonitorSide()
                    if currentMonitorSide then
                        state.logger.debug("YouTube", "Currently running on monitor: " .. currentMonitorSide)
                        if monitorSide ~= currentMonitorSide then
                            state.logger.debug("YouTube", "Ignoring touch from different monitor: " .. monitorSide .. " (expected: " .. currentMonitorSide .. ")")
                            -- Continue to next event instead of processing this touch
                            goto continue
                        end
                    else
                        state.logger.debug("YouTube", "Not running on a monitor, processing touch from: " .. monitorSide)
                    end
                else
                    state.logger.debug("YouTube", "No telemetry system available, processing touch from: " .. monitorSide)
                end
            end
            
            local result = youtubePlayer.handleClick(state, speakers, button, x, y)
            if result then
                return result
            end
        elseif event == "redraw_screen" then
            return "redraw"
        end
        
        ::continue::
    end
end

function youtubePlayer.handleClick(state, speakers, button, x, y)
    state.logger.debug("YouTube", "Processing click at (" .. x .. "," .. y .. ") button=" .. button .. " tab=" .. state.tab .. " in_search_result=" .. tostring(state.in_search_result))
    
    if button == 1 or button == 2 then -- Handle both left and right clicks
        -- Tab clicks (adjusted for header)
        if state.in_search_result == false then
            if y == 2 then -- Tab row is now at y=2
                state.logger.debug("YouTube", "Tab click detected at x=" .. x .. " (width=" .. state.width .. ")")
                if x < state.width/2 then
                    state.tab = 1
                    state.logger.debug("YouTube", "Switched to tab 1 (Now Playing)")
                else
                    state.tab = 2
                    state.logger.debug("YouTube", "Switched to tab 2 (Search)")
                end
                youtubeUI.redrawScreen(state)
                return
            end
        end
        
        -- Search tab handling
        if state.tab == 2 and state.in_search_result == false then
            state.logger.debug("YouTube", "Processing click in Search tab")
            -- Search box click (using original working coordinates)
            if y >= 3 and y <= 5 and x >= 2 and x <= state.width - 1 then
                state.logger.debug("YouTube", "Search box click detected")
                -- Use original working search box drawing
                paintutils.drawFilledBox(2, 3, state.width-1, 5, colors.white)
                term.setBackgroundColor(colors.white)
                term.setTextColor(colors.black)
                state.waiting_for_input = true
                return
            end

            -- Search result clicks (using original working coordinates - 2 lines per result)
            if state.search_results then
                state.logger.debug("YouTube", "Checking click at (" .. x .. "," .. y .. ") against " .. #state.search_results .. " results")
                for i=1, #state.search_results do
                    local resultY1 = 7 + (i-1)*2  -- First line of result
                    local resultY2 = 8 + (i-1)*2  -- Second line of result
                    state.logger.debug("YouTube", "Result " .. i .. " at y=" .. resultY1 .. "-" .. resultY2)
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
                        return
                    end
                end
                state.logger.debug("YouTube", "No search result matched click coordinates")
            else
                state.logger.debug("YouTube", "No search results available")
            end
        elseif state.tab == 2 and state.in_search_result == true then
            state.logger.debug("YouTube", "Processing click in song action menu")
            -- Song action menu clicks (adjusted for header)
            youtubePlayer.handleSongActionClick(state, speakers, y)
            return
        elseif state.tab == 1 and state.in_search_result == false then
            state.logger.debug("YouTube", "Processing click in Now Playing tab")
            -- Now playing tab clicks (adjusted for header)
            local result = youtubePlayer.handleNowPlayingClick(state, speakers, x, y)
            if result then
                return result
            end
        end
        
        -- Back to menu button (adjusted for footer)
        if y == state.height - 3 and x >= 2 and x <= 15 then
            state.logger.debug("YouTube", "Back to menu button clicked")
            return "back_to_menu"
        end
    end
    
    state.logger.debug("YouTube", "Click not handled by any UI element")
end

-- Handle song action menu clicks (adjusted for header)
function youtubePlayer.handleSongActionClick(state, speakers, y)
    local theme = themes.getCurrent()
    term.setBackgroundColor(theme.colors.button_active)
    term.setTextColor(theme.colors.background)

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

    -- Force a complete redraw to return to search results
    os.queueEvent("redraw_screen")
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

-- Debug function to monitor all events for a short period
function youtubePlayer.debugEvents(state, duration)
    state.logger.info("YouTube", "Starting event debugging for " .. duration .. " seconds...")
    local startTime = os.clock()
    
    while os.clock() - startTime < duration do
        local event, param1, param2, param3, param4 = os.pullEventRaw(0.1)
        
        if event then
            if event == "monitor_touch" then
                state.logger.info("YouTube", "DEBUG: monitor_touch event - side=" .. tostring(param1) .. " x=" .. tostring(param2) .. " y=" .. tostring(param3))
            elseif event == "mouse_click" then
                state.logger.info("YouTube", "DEBUG: mouse_click event - button=" .. tostring(param1) .. " x=" .. tostring(param2) .. " y=" .. tostring(param3))
            elseif event == "key" then
                state.logger.debug("YouTube", "DEBUG: key event - key=" .. tostring(param1))
            elseif event ~= "timer" then -- Don't spam with timer events
                state.logger.debug("YouTube", "DEBUG: " .. event .. " event")
            end
        end
    end
    
    state.logger.info("YouTube", "Event debugging completed")
end

return youtubePlayer 