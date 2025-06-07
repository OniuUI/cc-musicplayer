-- YouTube Music Player Feature
-- Based on the old working version with minimal changes for modular structure

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
        
        -- Simple state variables (like old version)
        width = 0,
        height = 0,
        tab = 1,
        waiting_for_input = false,
        last_search = nil,
        last_search_url = nil,
        search_results = nil,
        search_error = false,
        in_search_result = false,
        clicked_result = nil,
        
        playing = false,
        queue = {},
        now_playing = nil,
        looping = 0,
        volume = 1.5,
        
        playing_id = nil,
        last_download_url = nil,
        playing_status = 0,
        is_loading = false,
        is_error = false,
        
        player_handle = nil,
        start = nil,
        pcm = nil,
        size = nil,
        decoder = require("cc.audio.dfpwm").make_decoder(),
        needs_next_chunk = 0,
        buffer = nil,
        
        api_base_url = "https://ipod-2to6magyna-uc.a.run.app/",
        version = "2.1"
    }
    
    return state
end

function youtubePlayer.run(state)
    state.logger.info("YouTube", "Starting YouTube music player")
    
    -- Get screen size
    state.width, state.height = term.getSize()
    
    -- Get raw speakers (like old version)
    local speakers = state.speakerManager.getRawSpeakers()
    if #speakers == 0 then
        state.errorHandler.handleError("YouTube", "No speakers attached. You need to connect a speaker to this computer.", 3)
        return "menu"
    end
    
    -- Run the main loops in parallel (EXACTLY like old version)
    parallel.waitForAny(
        function() return youtubePlayer.uiLoop(state, speakers) end,
        function() return youtubePlayer.audioLoop(state, speakers) end,
        function() return youtubePlayer.httpLoop(state) end
    )
    
    -- Cleanup
    youtubePlayer.cleanup(state)
    return "menu"
end

-- UI Loop (EXACTLY like old version with monitor support but using modern UI)
function youtubePlayer.uiLoop(state, speakers)
    youtubeUI.redrawScreen(state)

    while true do
        if state.waiting_for_input then
            parallel.waitForAny(
                function()
                    -- Use modern themed search input
                    local theme = themes.getCurrent()
                    term.setCursorPos(3,4)
                    term.setBackgroundColor(theme.colors.search_box)
                    term.setTextColor(theme.colors.text_primary)
                    local input = read()

                    if string.len(input) > 0 then
                        state.last_search = input
                        state.last_search_url = state.api_base_url .. "?v=" .. state.version .. "&search=" .. textutils.urlEncode(input)
                        http.request(state.last_search_url)
                        state.search_results = nil
                        state.search_error = false
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
                        local event, param1, param2, param3 = os.pullEvent()
                        if event == "mouse_click" or event == "monitor_touch" then
                            local x, y
                            if event == "mouse_click" then
                                x, y = param2, param3
                            else
                                x, y = param2, param3  -- monitor_touch: side, x, y
                            end
                            
                            if y < 3 or y > 5 or x < 2 or x > state.width-1 then
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

                    if event == "mouse_click" or event == "monitor_touch" then
                        local button, x, y
                        if event == "mouse_click" then
                            button, x, y = param1, param2, param3
                            state.logger.debug("YouTube", "MOUSE_CLICK: button=" .. button .. " x=" .. x .. " y=" .. y)
                        else -- monitor_touch
                            button, x, y = 1, param2, param3  -- Treat as left click
                            state.logger.debug("YouTube", "MONITOR_TOUCH: side=" .. param1 .. " x=" .. x .. " y=" .. y)
                        end

                        if button == 1 then
                            state.logger.debug("YouTube", "Click at (" .. x .. "," .. y .. ") - screen size: " .. state.width .. "x" .. state.height)
                            state.logger.debug("YouTube", "Current state: tab=" .. state.tab .. " in_search_result=" .. tostring(state.in_search_result) .. " search_results=" .. (state.search_results and #state.search_results or "nil"))
                            
                            -- Back to menu button (FIRST CHECK) - adjusted for modern UI
                            -- The button is drawn at (2, state.height - 3) with text " Back to Menu "
                            if y == state.height - 3 and x >= 2 and x <= 16 then
                                state.logger.info("YouTube", "Back to menu clicked")
                                return "menu"
                            end
                            
                            -- Tabs - adjusted for modern UI (header at y=2)
                            if state.in_search_result == false then
                                if y == 2 then
                                    if x < state.width/2 then
                                        state.tab = 1
                                    else
                                        state.tab = 2
                                    end
                                    youtubeUI.redrawScreen(state)
                                end
                            end
                            
                            if state.tab == 2 and state.in_search_result == false then
                                -- Search box click (original coordinates still work)
                                if y >= 3 and y <= 5 and x >= 1 and x <= state.width-1 then
                                    -- Use modern themed search input
                                    local theme = themes.getCurrent()
                                    for searchY = 3, 5 do
                                        term.setCursorPos(2, searchY)
                                        term.setBackgroundColor(theme.colors.search_box)
                                        term.clearLine()
                                    end
                                    term.setBackgroundColor(theme.colors.search_box)
                                    state.waiting_for_input = true
                                end
            
                                -- Search result click (EXACTLY like original working code)
                                if state.search_results then
                                    state.logger.info("YouTube", "Checking search result clicks - have " .. #state.search_results .. " results")
                                    for i=1,#state.search_results do
                                        local resultY1 = 7 + (i-1)*2  -- Title line
                                        local resultY2 = 8 + (i-1)*2  -- Artist line
                                        state.logger.debug("YouTube", "Result " .. i .. " at y=" .. resultY1 .. "-" .. resultY2 .. ", click at y=" .. y)
                                        
                                        -- EXACT match with original: if y == 7 + (i-1)*2 or y == 8 + (i-1)*2
                                        if y == resultY1 or y == resultY2 then
                                            state.logger.info("YouTube", "CLICKED on search result " .. i .. ": " .. state.search_results[i].name)
                                            
                                            -- Visual feedback (like original)
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
                                            
                                            -- Set state (like original)
                                            state.in_search_result = true
                                            state.clicked_result = i
                                            state.logger.info("YouTube", "Set in_search_result=true, clicked_result=" .. i)
                                            
                                            -- Redraw (like original)
                                            youtubeUI.redrawScreen(state)
                                            state.logger.info("YouTube", "Redraw completed, should now show action menu")
                                            return -- Exit this event handler to prevent further processing
                                        end
                                    end
                                end
                            elseif state.tab == 2 and state.in_search_result == true then
                                -- Search result menu clicks (original coordinates still work)
                                state.logger.info("YouTube", "In song action menu, clicked at (" .. x .. "," .. y .. ")")
                                local theme = themes.getCurrent()
                                term.setBackgroundColor(theme.colors.button_active)
                                term.setTextColor(theme.colors.background)
            
                                if y == 6 then
                                    state.logger.info("YouTube", "Play now button clicked")
                                    term.setCursorPos(2,6)
                                    term.clearLine()
                                    term.write("Play now")
                                    sleep(0.2)
                                    state.in_search_result = false
                                    for _, speaker in ipairs(speakers) do
                                        speaker.stop()
                                        os.queueEvent("playback_stopped")
                                    end
                                    state.playing = true
                                    state.is_error = false
                                    state.playing_id = nil
                                    if state.search_results[state.clicked_result].type == "playlist" then
                                        state.now_playing = state.search_results[state.clicked_result].playlist_items[1]
                                        state.queue = {}
                                        if #state.search_results[state.clicked_result].playlist_items > 1 then
                                            for i=2, #state.search_results[state.clicked_result].playlist_items do
                                                table.insert(state.queue, state.search_results[state.clicked_result].playlist_items[i])
                                            end
                                        end
                                    else
                                        state.now_playing = state.search_results[state.clicked_result]
                                    end
                                    state.logger.info("YouTube", "Playing now: " .. state.now_playing.name)
                                    os.queueEvent("audio_update")
                                end
            
                                if y == 8 then
                                    state.logger.info("YouTube", "Play next button clicked")
                                    term.setCursorPos(2,8)
                                    term.clearLine()
                                    term.write("Play next")
                                    sleep(0.2)
                                    state.in_search_result = false
                                    if state.search_results[state.clicked_result].type == "playlist" then
                                        for i = #state.search_results[state.clicked_result].playlist_items, 1, -1 do
                                            table.insert(state.queue, 1, state.search_results[state.clicked_result].playlist_items[i])
                                        end
                                    else
                                        table.insert(state.queue, 1, state.search_results[state.clicked_result])
                                    end
                                    state.logger.info("YouTube", "Added to play next: " .. state.search_results[state.clicked_result].name)
                                    os.queueEvent("audio_update")
                                end
            
                                if y == 10 then
                                    state.logger.info("YouTube", "Add to queue button clicked")
                                    term.setCursorPos(2,10)
                                    term.clearLine()
                                    term.write("Add to queue")
                                    sleep(0.2)
                                    state.in_search_result = false
                                    if state.search_results[state.clicked_result].type == "playlist" then
                                        for i = 1, #state.search_results[state.clicked_result].playlist_items do
                                            table.insert(state.queue, state.search_results[state.clicked_result].playlist_items[i])
                                        end
                                    else
                                        table.insert(state.queue, state.search_results[state.clicked_result])
                                    end
                                    state.logger.info("YouTube", "Added to queue: " .. state.search_results[state.clicked_result].name)
                                    os.queueEvent("audio_update")
                                end
            
                                if y == 13 then
                                    state.logger.info("YouTube", "Cancel button clicked")
                                    term.setCursorPos(2,13)
                                    term.clearLine()
                                    term.write("Cancel")
                                    sleep(0.2)
                                    state.in_search_result = false
                                end
            
                                youtubeUI.redrawScreen(state)
                            elseif state.tab == 1 and state.in_search_result == false then
                                -- Now playing tab clicks - adjusted for modern UI coordinates
            
                                if y == 7 then -- Control buttons row (adjusted for header)
                                    -- Play/stop button
                                    if x >= 2 and x < 8 then
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
                                    if x >= 9 and x < 15 then
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
            
                                    -- Loop button
                                    if x >= 16 and x < 28 then
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
 
                                -- Volume slider - adjusted for modern UI coordinates (y=9)
                                if y == 9 then
                                    if x >= 2 and x < 26 then
                                        state.volume = (x - 2) / 24 * 3.0
                                        state.speakerManager.setVolume(state.volume)
                                        state.logger.debug("YouTube", "Volume set to " .. math.floor((state.volume / 3.0) * 100) .. "%")
                                    end
                                end
 
                                youtubeUI.redrawScreen(state)
                            end
                        end
                    end
                end,
                function()
                    local event, param1, param2, param3 = os.pullEvent()

                    if event == "mouse_drag" or event == "monitor_touch" then
                        local button, x, y
                        if event == "mouse_drag" then
                            button, x, y = param1, param2, param3
                        else
                            button, x, y = 1, param2, param3
                        end

                        if button == 1 then
                            if state.tab == 1 and state.in_search_result == false then
                                -- Volume slider drag - adjusted for modern UI coordinates (y=9)
                                if y == 9 then
                                    if x >= 2 and x < 26 then
                                        state.volume = (x - 2) / 24 * 3.0
                                        state.speakerManager.setVolume(state.volume)
                                        state.logger.debug("YouTube", "Volume dragged to " .. math.floor((state.volume / 3.0) * 100) .. "%")
                                    end
                                end
                                youtubeUI.redrawScreen(state)
                            end
                        end
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

-- Audio Loop (from working original)
function youtubePlayer.audioLoop(state, speakers)
    while true do
        -- AUDIO (EXACTLY like old version)
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

                while true do
                    local chunk = state.player_handle.read(state.size)
                    if not chunk then
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
                        break
                    else
                        if state.start then
                            chunk, state.start = state.start .. chunk, nil
                            state.size = state.size + 4
                        end
                
                        state.buffer = state.decoder(chunk)
                        
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
                                                local event = os.pullEvent("playback_stopped")
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
                                                local event = os.pullEvent("playback_stopped")
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
                        if not ok then
                            state.needs_next_chunk = 2
                            state.is_error = true
                            break
                        end
                        
                        -- If we're not playing anymore, exit the chunk processing loop
                        if not state.playing or state.playing_id ~= thisnowplayingid then
                            break
                        end
                    end
                end
                os.queueEvent("audio_update")
            end
        end

        os.pullEvent("audio_update")
    end
end

-- HTTP Loop (EXACTLY like old version)
function youtubePlayer.httpLoop(state)
    while true do
        parallel.waitForAny(
            function()
                local event, url, handle = os.pullEvent("http_success")

                if url == state.last_search_url then
                    local success, results = pcall(function()
                        local responseText = handle.readAll()
                        handle.close()
                        if not responseText or responseText == "" then
                            error("Empty response from search API")
                        end
                        return textutils.unserialiseJSON(responseText)
                    end)
                    
                    if success and results then
                        state.search_results = results
                        state.search_error = false
                        state.logger.info("YouTube", "Search completed: " .. #results .. " results")
                    else
                        state.search_results = nil
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
                    state.search_results = nil
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
    if state.speakerManager then
        state.speakerManager.stopAll()
    end
    state.playing = false
    if state.player_handle then
        state.player_handle.close()
    end
    state.logger.info("YouTube", "YouTube player cleaned up")
end

return youtubePlayer 