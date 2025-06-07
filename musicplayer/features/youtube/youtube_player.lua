-- YouTube Music Player Feature
-- Simplified version with direct drawing but modern UI look

local youtubePlayer = {}

function youtubePlayer.init(systemModules)
    local state = {
        -- System modules (simplified)
        logger = systemModules.logger,
        speakerManager = systemModules.speakerManager,
        errorHandler = systemModules.errorHandler,
        
        -- Simple state variables (like reference)
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
    state.logger.info("YouTube", "Starting simplified YouTube player")
    
    -- Get screen size
    state.width, state.height = term.getSize()
    
    -- Get raw speakers
    local speakers = state.speakerManager.getRawSpeakers()
    if #speakers == 0 then
        state.errorHandler.handleError("YouTube", "No speakers attached. You need to connect a speaker to this computer.", 3)
        return "menu"
    end
    
    -- Run main loops (like reference) with proper return handling
    local result = parallel.waitForAny(
        function() return youtubePlayer.uiLoop(state, speakers) end,
        function() return youtubePlayer.audioLoop(state, speakers) end,
        function() return youtubePlayer.httpLoop(state) end
    )
    
    -- Clean up
    youtubePlayer.cleanup(state)
    
    -- Return the result from uiLoop (should be "menu")
    return "menu"
end

-- SIMPLIFIED REDRAW (direct drawing with modern look)
function youtubePlayer.redrawScreen(state)
    if state.waiting_for_input then
        return
    end

    term.setCursorBlink(false)
    state.width, state.height = term.getSize()
    
    -- CRITICAL: Check for action menu FIRST
    if state.in_search_result == true then
        -- Draw ONLY action menu (like reference)
        term.setBackgroundColor(colors.black)
        term.clear()
        
        if state.search_results and state.clicked_result then
            local selectedSong = state.search_results[state.clicked_result]
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.setCursorPos(2, 2)
            term.write(selectedSong.name)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(2, 3)
            term.write(selectedSong.artist)
        end

        -- Action buttons (original coordinates)
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)

        term.setCursorPos(2, 6)
        term.clearLine()
        term.write("Play now")

        term.setCursorPos(2, 8)
        term.clearLine()
        term.write("Play next")

        term.setCursorPos(2, 10)
        term.clearLine()
        term.write("Add to queue")

        term.setCursorPos(2, 13)
        term.clearLine()
        term.write("Cancel")
        
        return -- Don't draw anything else
    end
    
    -- Clear screen with modern colors
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Draw beautiful modern header (like before)
    term.setBackgroundColor(colors.blue)
    term.setCursorPos(1, 1)
    term.clearLine()
    term.setTextColor(colors.white)
    term.setCursorPos(2, 1)
    term.write("Bognesferga Radio")
    
    -- Add rainbow title effect (like before)
    local rainbow_colors = {colors.red, colors.orange, colors.yellow, colors.lime, colors.cyan, colors.lightBlue, colors.purple, colors.magenta}
    local title = "YouTube Player"
    local startX = state.width - #title - 1
    for i = 1, #title do
        local char = title:sub(i, i)
        local colorIndex = ((i - 1) % #rainbow_colors) + 1
        term.setTextColor(rainbow_colors[colorIndex])
        term.setCursorPos(startX + i - 1, 1)
        term.write(char)
    end

    -- Draw beautiful modern tabs (like before)
    local tabs = {" Now Playing ", " Search "}
    term.setCursorPos(1, 2)
    term.setBackgroundColor(colors.blue)
    term.clearLine()
    
    for i = 1, #tabs do
        if state.tab == i then
            term.setTextColor(colors.black)
            term.setBackgroundColor(colors.white)
        else
            term.setTextColor(colors.white)
            term.setBackgroundColor(colors.blue)
        end
        
        local tabX = math.floor((state.width / #tabs) * (i - 0.5)) - math.ceil(#tabs[i] / 2) + 1
        term.setCursorPos(tabX, 2)
        term.write(tabs[i])
    end

    -- Draw content based on tab
    if state.tab == 1 then
        youtubePlayer.drawNowPlaying(state)
    elseif state.tab == 2 then
        youtubePlayer.drawSearch(state)
    end
    
    -- Draw beautiful modern footer (like before)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(1, state.height - 2)
    term.clearLine()
    term.setCursorPos(1, state.height - 1)
    term.clearLine()
    term.setCursorPos(1, state.height)
    term.clearLine()
    
    -- Back to menu button (styled like before)
    term.setBackgroundColor(colors.lightBlue)
    term.setTextColor(colors.white)
    term.setCursorPos(2, state.height - 1)
    term.write(" Back to Menu ")
    
    -- Footer info (like before)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.lightGray)
    term.setCursorPos(state.width - 15, state.height - 1)
    term.write("Developed by Forty")
end

function youtubePlayer.drawNowPlaying(state)
    -- Song info with beautiful modern styling
    if state.now_playing ~= nil then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.setCursorPos(2, 4)
        term.write("♪ " .. state.now_playing.name)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(2, 5)
        term.write("  " .. state.now_playing.artist)
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(2, 4)
        term.write("♪ Not playing")
    end

    -- Status with beautiful modern colors
    if state.is_loading then
        term.setTextColor(colors.yellow)
        term.setBackgroundColor(colors.black)
        term.setCursorPos(2, 7)
        term.write("⟳ Loading...")
    elseif state.is_error then
        term.setTextColor(colors.red)
        term.setBackgroundColor(colors.black)
        term.setCursorPos(2, 7)
        term.write("✗ Network error")
    elseif state.playing then
        term.setTextColor(colors.lime)
        term.setBackgroundColor(colors.black)
        term.setCursorPos(2, 7)
        term.write("▶ Playing")
    end

    -- Beautiful modern control buttons
    local buttonY = 9
    
    -- Play/Stop button
    if state.playing then
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.setCursorPos(2, buttonY)
        term.write(" ⏹ Stop ")
    else
        if state.now_playing ~= nil or #state.queue > 0 then
            term.setBackgroundColor(colors.lime)
            term.setTextColor(colors.black)
        else
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.lightGray)
        end
        term.setCursorPos(2, buttonY)
        term.write(" ▶ Play ")
    end

    -- Skip button
    if state.now_playing ~= nil or #state.queue > 0 then
        term.setBackgroundColor(colors.lightBlue)
        term.setTextColor(colors.white)
    else
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.lightGray)
    end
    term.setCursorPos(12, buttonY)
    term.write(" ⏭ Skip ")

    -- Loop button with beautiful styling
    if state.looping ~= 0 then
        term.setBackgroundColor(colors.cyan)
        term.setTextColor(colors.black)
    else
        term.setBackgroundColor(colors.lightGray)
        term.setTextColor(colors.gray)
    end
    term.setCursorPos(22, buttonY)
    if state.looping == 0 then
        term.write(" ⟲ Off ")
    elseif state.looping == 1 then
        term.write(" ⟲ Queue ")
    else
        term.write(" ⟲ Song ")
    end

    -- Beautiful modern volume slider
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(2, 11)
    term.write("Volume:")
    
    term.setCursorPos(2, 12)
    paintutils.drawBox(2, 12, 25, 12, colors.gray)
    local width = math.floor(24 * (state.volume / 3) + 0.5) - 1
    if width >= 0 then
        paintutils.drawBox(2, 12, 2 + width, 12, colors.cyan)
    end
    term.setCursorPos(27, 12)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.cyan)
    term.write(math.floor(100 * (state.volume / 3) + 0.5) .. "%")

    -- Queue with beautiful modern styling
    if #state.queue > 0 then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.setCursorPos(2, 14)
        term.write("Queue (" .. #state.queue .. " songs):")
        
        for i = 1, #state.queue do
            if 15 + (i-1)*2 >= state.height - 3 then break end
            term.setTextColor(colors.white)
            term.setCursorPos(2, 15 + (i-1)*2)
            term.write(i .. ". " .. state.queue[i].name)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(2, 16 + (i-1)*2)
            term.write("   " .. state.queue[i].artist)
        end
    end
end

function youtubePlayer.drawSearch(state)
    -- Beautiful modern search box
    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)
    
    -- Draw search box border
    paintutils.drawBox(2, 3, state.width - 1, 5, colors.white)
    
    term.setCursorPos(3, 4)
    local displayText = state.last_search or "🔍 Search YouTube or paste URL..."
    if not state.last_search then
        term.setTextColor(colors.gray)
    else
        term.setTextColor(colors.black)
    end
    term.write(displayText)

    -- Search results with beautiful modern styling
    if state.search_results then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.setCursorPos(2, 6)
        term.write("Results (" .. #state.search_results .. " found):")
        
        for i = 1, #state.search_results do
            local result = state.search_results[i]
            local y1 = 7 + (i-1)*3  -- More spacing for better look
            local y2 = 8 + (i-1)*3
            
            if y2 >= state.height - 3 then break end
            
            -- Beautiful result styling with hover effect
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.setCursorPos(2, y1)
            term.clearLine()
            term.write("♪ " .. result.name)
            
            term.setTextColor(colors.lightGray)
            term.setCursorPos(2, y2)
            term.clearLine()
            term.write("  " .. result.artist)
            
            -- Add type indicator
            if result.type == "playlist" then
                term.setTextColor(colors.cyan)
                term.setCursorPos(state.width - 10, y1)
                term.write("[Playlist]")
            end
        end
    else
        -- Search status with beautiful modern colors
        term.setBackgroundColor(colors.black)
        if state.search_error then
            term.setTextColor(colors.red)
            term.setCursorPos(2, 7)
            term.write("✗ Search failed - please try again")
        elseif state.last_search_url then
            term.setTextColor(colors.yellow)
            term.setCursorPos(2, 7)
            term.write("⟳ Searching...")
        else
            term.setTextColor(colors.lightGray)
            term.setCursorPos(2, 7)
            term.write("💡 Tip: You can paste YouTube video or playlist links.")
        end
    end
end

-- UI Loop (simplified like reference implementation)
function youtubePlayer.uiLoop(state, speakers)
    youtubePlayer.redrawScreen(state)
    
    local shouldExit = false
    local exitReason = "menu"

    while not shouldExit do
        if state.waiting_for_input then
            parallel.waitForAny(
                function()
                    -- Simple search input
                    term.setCursorPos(3, 4)
                    term.setBackgroundColor(colors.lightGray)
                    term.setTextColor(colors.black)
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
                            state.logger.info("YouTube", "Mouse click at x=" .. x .. ", y=" .. y .. ", button=" .. button)
                        else -- monitor_touch
                            button, x, y = 1, param2, param3  -- Treat as left click
                            state.logger.info("YouTube", "Monitor touch at x=" .. x .. ", y=" .. y)
                        end

                        if button == 1 then
                            -- Back to menu button (footer at height-1)
                            if y == state.height - 1 and x >= 2 and x <= 16 then
                                state.logger.info("YouTube", "Back to menu button clicked! Exiting...")
                                
                                -- Visual feedback
                                term.setBackgroundColor(colors.white)
                                term.setTextColor(colors.black)
                                term.setCursorPos(2, state.height - 1)
                                term.write(" Back to Menu ")
                                sleep(0.3)
                                
                                shouldExit = true
                                exitReason = "menu"
                                return
                            end
                            
                            -- Tabs (header line 2)
                            if state.in_search_result == false and y == 2 then
                                if x < state.width/2 then
                                    state.tab = 1
                                else
                                    state.tab = 2
                                end
                                youtubePlayer.redrawScreen(state)
                            end
                            
                            if state.tab == 2 and state.in_search_result == false then
                                -- Search box click
                                if y >= 3 and y <= 5 and x >= 2 and x <= state.width-1 then
                                    -- Simple search box styling
                                    for searchY = 3, 5 do
                                        term.setCursorPos(2, searchY)
                                        term.setBackgroundColor(colors.white)
                                        term.clearLine()
                                    end
                                    state.waiting_for_input = true
                                end
            
                                -- Search result click (like reference)
                                if state.search_results then
                                    for i=1,#state.search_results do
                                        local resultY1 = 7 + (i-1)*3  -- Title line
                                        local resultY2 = 8 + (i-1)*3  -- Artist line
                                        
                                        if y == resultY1 or y == resultY2 then
                                            -- Visual feedback
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
                                            
                                            -- Set state
                                            state.in_search_result = true
                                            state.clicked_result = i
                                            
                                            -- Redraw
                                            youtubePlayer.redrawScreen(state)
                                            return
                                        end
                                    end
                                end
                            elseif state.tab == 2 and state.in_search_result == true then
                                -- Action menu clicks (original coordinates: y=6,8,10,13)
                                term.setBackgroundColor(colors.white)
                                term.setTextColor(colors.black)
            
                                if y == 6 then
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
                                    os.queueEvent("audio_update")
                                end
            
                                if y == 8 then
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
                                    os.queueEvent("audio_update")
                                end
            
                                if y == 10 then
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
                                    os.queueEvent("audio_update")
                                end
            
                                if y == 13 then
                                    term.setCursorPos(2,13)
                                    term.clearLine()
                                    term.write("Cancel")
                                    sleep(0.2)
                                    state.in_search_result = false
                                end
            
                                youtubePlayer.redrawScreen(state)
                            elseif state.tab == 1 and state.in_search_result == false then
                                -- Now playing tab clicks
                                if y == 9 then -- Control buttons row (updated from y=8)
                                    -- Play/stop button
                                    if x >= 2 and x < 11 then
                                        if state.playing or state.now_playing ~= nil or #state.queue > 0 then
                                            term.setBackgroundColor(colors.white)
                                            term.setTextColor(colors.black)
                                            term.setCursorPos(2, 9)
                                            if state.playing then
                                                term.write(" ⏹ Stop ")
                                            else 
                                                term.write(" ▶ Play ")
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
                                            os.queueEvent("audio_update")
                                        elseif state.now_playing ~= nil then
                                            state.playing_id = nil
                                            state.playing = true
                                            state.is_error = false
                                            os.queueEvent("audio_update")
                                        elseif #state.queue > 0 then
                                            state.now_playing = state.queue[1]
                                            table.remove(state.queue, 1)
                                            state.playing_id = nil
                                            state.playing = true
                                            state.is_error = false
                                            os.queueEvent("audio_update")
                                        end
                                    end
            
                                    -- Skip button (updated coordinates)
                                    if x >= 12 and x < 21 then
                                        if state.now_playing ~= nil or #state.queue > 0 then
                                            term.setBackgroundColor(colors.white)
                                            term.setTextColor(colors.black)
                                            term.setCursorPos(12, 9)
                                            term.write(" ⏭ Skip ")
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
                                            else
                                                state.now_playing = nil
                                                state.playing = false
                                                state.is_loading = false
                                                state.is_error = false
                                                state.playing_id = nil
                                            end
                                            os.queueEvent("audio_update")
                                        end
                                    end
            
                                    -- Loop button (updated coordinates)
                                    if x >= 22 and x < 30 then
                                        if state.looping == 0 then
                                            state.looping = 1
                                        elseif state.looping == 1 then
                                            state.looping = 2
                                        else
                                            state.looping = 0
                                        end
                                    end
                                end
 
                                -- Volume slider (updated from y=10 to y=12)
                                if y == 12 then
                                    if x >= 2 and x < 26 then
                                        state.volume = (x - 2) / 24 * 3.0
                                        state.speakerManager.setVolume(state.volume)
                                    end
                                end
                            end
                            
                            youtubePlayer.redrawScreen(state)
                        end
                    end
                end,
                function()
                    local event = os.pullEvent("redraw_screen")
                    youtubePlayer.redrawScreen(state)
                end
            )
        end
    end
    
    return exitReason
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