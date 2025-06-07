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
        
        -- Pagination support
        current_page = 1,
        results_per_page = 5,
        
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

-- SIMPLIFIED REDRAW (direct drawing with main menu design)
function youtubePlayer.redrawScreen(state)
    if state.waiting_for_input then
        return
    end

    term.setCursorBlink(false)
    state.width, state.height = term.getSize()
    
    -- CRITICAL: Check for action menu FIRST
    if state.in_search_result == true then
        -- Draw action menu with beautiful main menu design
        term.setBackgroundColor(colors.black)
        term.clear()
        
        -- Beautiful header for action menu
        term.setBackgroundColor(colors.blue)
        term.setCursorPos(1, 1)
        term.clearLine()
        local title = "Bognesferga Radio"
        local fullHeader = "♪ " .. title .. " ♪"
        local headerX = math.floor((state.width - #fullHeader) / 2) + 1
        term.setCursorPos(headerX, 1)
        term.setTextColor(colors.yellow)
        term.write("♪ ")
        term.setTextColor(colors.white)
        term.write(title)
        term.setTextColor(colors.yellow)
        term.write(" ♪")
        
        -- Song info with yellow accent
        if state.search_results and state.clicked_result then
            local selectedSong = state.search_results[state.clicked_result]
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.yellow)
            term.setCursorPos(2, 3)
            term.write("Selected Song:")
            term.setTextColor(colors.white)
            term.setCursorPos(2, 4)
            term.write("♪ " .. selectedSong.name)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(2, 5)
            term.write("  " .. selectedSong.artist)
        end

        -- Beautiful action buttons with contrasting colors
        term.setCursorPos(2, 7)
        term.setBackgroundColor(colors.lime)
        term.setTextColor(colors.black)
        term.write(" ▶ Play now ")

        term.setCursorPos(2, 9)
        term.setBackgroundColor(colors.cyan)
        term.setTextColor(colors.black)
        term.write(" ⏭ Play next ")

        term.setCursorPos(2, 11)
        term.setBackgroundColor(colors.lightBlue)
        term.setTextColor(colors.white)
        term.write(" + Add to queue ")

        term.setCursorPos(2, 13)
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write(" ✗ Cancel ")
        
        -- Beautiful rainbow footer for action menu
        term.setBackgroundColor(colors.gray)
        term.setCursorPos(1, state.height)
        term.clearLine()
        local devText = "Developed by Forty"
        local footerX = math.floor((state.width - #devText) / 2) + 1
        term.setCursorPos(footerX, state.height)
        local rainbow_colors = {colors.red, colors.orange, colors.yellow, colors.lime, colors.cyan, colors.lightBlue, colors.purple, colors.magenta}
        for i = 1, #devText do
            local colorIndex = ((i - 1) % #rainbow_colors) + 1
            term.setTextColor(rainbow_colors[colorIndex])
            term.write(devText:sub(i, i))
        end
        
        return -- Don't draw anything else
    end
    
    -- Clear screen
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Beautiful main menu style header
    term.setBackgroundColor(colors.blue)
    term.setCursorPos(1, 1)
    term.clearLine()
    local title = "Bognesferga Radio"
    local fullHeader = "♪ " .. title .. " ♪"
    local headerX = math.floor((state.width - #fullHeader) / 2) + 1
    term.setCursorPos(headerX, 1)
    term.setTextColor(colors.yellow)
    term.write("♪ ")
    term.setTextColor(colors.white)
    term.write(title)
    term.setTextColor(colors.yellow)
    term.write(" ♪")

    -- Beautiful modern tabs with main menu styling
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
            term.setBackgroundColor(colors.lightGray)
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
    
    -- Beautiful rainbow footer (main menu style)
    term.setBackgroundColor(colors.gray)
    term.setCursorPos(1, state.height - 1)
    term.clearLine()
    term.setCursorPos(1, state.height)
    term.clearLine()
    
    -- Back to menu button with yellow accent
    term.setBackgroundColor(colors.yellow)
    term.setTextColor(colors.black)
    term.setCursorPos(2, state.height - 1)
    term.write(" ← Back to Menu ")
    
    -- Rainbow "Developed by Forty" footer with gray background
    term.setBackgroundColor(colors.gray)
    local devText = "Developed by Forty"
    local footerX = math.floor((state.width - #devText) / 2) + 1
    term.setCursorPos(footerX, state.height)
    local rainbow_colors = {colors.red, colors.orange, colors.yellow, colors.lime, colors.cyan, colors.lightBlue, colors.purple, colors.magenta}
    for i = 1, #devText do
        local colorIndex = ((i - 1) % #rainbow_colors) + 1
        term.setTextColor(rainbow_colors[colorIndex])
        term.write(devText:sub(i, i))
    end
end

function youtubePlayer.drawNowPlaying(state)
    -- Welcome message with yellow accent (like main menu)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 4)
    term.write("Now Playing:")
    
    -- Song info with beautiful styling
    if state.now_playing ~= nil then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.setCursorPos(3, 5)
        term.write("♪ " .. state.now_playing.name)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, 6)
        term.write("  " .. state.now_playing.artist)
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, 5)
        term.write("♪ No song selected")
        term.setCursorPos(3, 6)
        term.write("  Choose a song from the Search tab")
    end

    -- Status with beautiful colors and yellow accents
    if state.is_loading then
        term.setTextColor(colors.yellow)
        term.setBackgroundColor(colors.black)
        term.setCursorPos(3, 8)
        term.write("⟳ Loading...")
    elseif state.is_error then
        term.setTextColor(colors.red)
        term.setBackgroundColor(colors.black)
        term.setCursorPos(3, 8)
        term.write("✗ Network error")
    elseif state.playing then
        term.setTextColor(colors.lime)
        term.setBackgroundColor(colors.black)
        term.setCursorPos(3, 8)
        term.write("▶ Playing")
    end

    -- Beautiful control buttons with main menu style
    local buttonY = 10
    
    -- Play/Stop button
    if state.playing then
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.setCursorPos(3, buttonY)
        term.write(" ⏹ Stop ")
    else
        if state.now_playing ~= nil or #state.queue > 0 then
            term.setBackgroundColor(colors.lime)
            term.setTextColor(colors.black)
        else
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.lightGray)
        end
        term.setCursorPos(3, buttonY)
        term.write(" ▶ Play ")
    end

    -- Skip button
    if state.now_playing ~= nil or #state.queue > 0 then
        term.setBackgroundColor(colors.cyan)
        term.setTextColor(colors.black)
    else
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.lightGray)
    end
    term.setCursorPos(13, buttonY)
    term.write(" ⏭ Skip ")

    -- Loop button with beautiful styling
    if state.looping ~= 0 then
        term.setBackgroundColor(colors.yellow)
        term.setTextColor(colors.black)
    else
        term.setBackgroundColor(colors.lightGray)
        term.setTextColor(colors.gray)
    end
    term.setCursorPos(23, buttonY)
    if state.looping == 0 then
        term.write(" ⟲ Off ")
    elseif state.looping == 1 then
        term.write(" ⟲ Queue ")
    else
        term.write(" ⟲ Song ")
    end

    -- Beautiful volume slider with yellow accent
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 12)
    term.write("Volume:")
    
    term.setCursorPos(3, 13)
    paintutils.drawBox(3, 13, 26, 13, colors.gray)
    local width = math.floor(24 * (state.volume / 3) + 0.5) - 1
    if width >= 0 then
        paintutils.drawBox(3, 13, 3 + width, 13, colors.yellow)
    end
    term.setCursorPos(28, 13)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.write(math.floor(100 * (state.volume / 3) + 0.5) .. "%")

    -- Queue with beautiful styling and yellow accent
    if #state.queue > 0 then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.yellow)
        term.setCursorPos(3, 15)
        term.write("Queue (" .. #state.queue .. " songs):")
        
        for i = 1, #state.queue do
            if 16 + (i-1)*2 >= state.height - 3 then break end
            term.setTextColor(colors.white)
            term.setCursorPos(3, 16 + (i-1)*2)
            term.write(i .. ". " .. state.queue[i].name)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(3, 17 + (i-1)*2)
            term.write("   " .. state.queue[i].artist)
        end
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, 15)
        term.write("Queue is empty")
        term.setCursorPos(3, 16)
        term.write("Add songs from the Search tab")
    end
end

function youtubePlayer.drawSearch(state)
    -- Welcome message with yellow accent (like main menu)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(3, 4)
    term.write("Search YouTube Music:")
    
    term.setTextColor(colors.lightGray)
    term.setCursorPos(3, 5)
    term.write("Enter a song name, artist, or paste a YouTube URL")

    -- Beautiful search box with main menu styling
    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)
    
    -- Draw search box border
    paintutils.drawBox(3, 7, state.width - 2, 9, colors.white)
    
    term.setCursorPos(4, 8)
    local displayText = state.last_search or "🔍 Search YouTube or paste URL..."
    if not state.last_search then
        term.setTextColor(colors.gray)
    else
        term.setTextColor(colors.black)
    end
    term.write(displayText)

    -- Search results with pagination
    if state.search_results and #state.search_results > 0 then
        -- Calculate pagination
        local totalResults = #state.search_results
        local totalPages = math.ceil(totalResults / state.results_per_page)
        local startIndex = (state.current_page - 1) * state.results_per_page + 1
        local endIndex = math.min(startIndex + state.results_per_page - 1, totalResults)
        
        -- Results header with pagination info
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.yellow)
        term.setCursorPos(3, 11)
        term.write("Results (" .. totalResults .. " found) - Page " .. state.current_page .. "/" .. totalPages)
        
        -- Display current page results
        for i = startIndex, endIndex do
            local result = state.search_results[i]
            local displayIndex = i - startIndex + 1
            local y1 = 12 + (displayIndex-1)*3  -- Title line
            local y2 = 13 + (displayIndex-1)*3  -- Artist line
            
            if y2 >= state.height - 5 then break end
            
            -- Beautiful result styling with contrasting colors
            term.setBackgroundColor(colors.lightBlue)
            term.setTextColor(colors.black)
            term.setCursorPos(3, y1)
            term.clearLine()
            term.write(" ♪ " .. result.name .. " ")
            
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(3, y2)
            term.clearLine()
            term.write("   " .. result.artist)
            
            -- Add type indicator with yellow accent
            if result.type == "playlist" then
                term.setTextColor(colors.yellow)
                term.setCursorPos(state.width - 12, y1)
                term.setBackgroundColor(colors.black)
                term.write("[Playlist]")
            end
        end
        
        -- Pagination controls
        if totalPages > 1 then
            local controlsY = state.height - 3
            term.setBackgroundColor(colors.black)
            
            -- Previous button
            if state.current_page > 1 then
                term.setBackgroundColor(colors.cyan)
                term.setTextColor(colors.black)
                term.setCursorPos(3, controlsY)
                term.write(" ← Prev ")
            else
                term.setBackgroundColor(colors.gray)
                term.setTextColor(colors.lightGray)
                term.setCursorPos(3, controlsY)
                term.write(" ← Prev ")
            end
            
            -- Page info
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.setCursorPos(13, controlsY)
            term.write("Page " .. state.current_page .. "/" .. totalPages)
            
            -- Next button
            if state.current_page < totalPages then
                term.setBackgroundColor(colors.cyan)
                term.setTextColor(colors.black)
                term.setCursorPos(state.width - 10, controlsY)
                term.write(" Next → ")
            else
                term.setBackgroundColor(colors.gray)
                term.setTextColor(colors.lightGray)
                term.setCursorPos(state.width - 10, controlsY)
                term.write(" Next → ")
            end
        end
        
    else
        -- Search status with beautiful colors and yellow accents
        term.setBackgroundColor(colors.black)
        if state.search_error then
            term.setTextColor(colors.red)
            term.setCursorPos(3, 11)
            term.write("✗ Search failed - please try again")
        elseif state.last_search_url then
            term.setTextColor(colors.yellow)
            term.setCursorPos(3, 11)
            term.write("⟳ Searching...")
        else
            term.setTextColor(colors.lightGray)
            term.setCursorPos(3, 11)
            term.write("💡 Tip: You can paste YouTube video or playlist links.")
            term.setCursorPos(3, 12)
            term.write("    Click the search box above to get started!")
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
                    term.setCursorPos(4, 8)
                    term.setBackgroundColor(colors.white)
                    term.setTextColor(colors.black)
                    local input = read()
                    
                    if string.len(input) > 0 then
                        state.last_search = input
                        state.last_search_url = state.api_base_url .. "?v=" .. state.version .. "&search=" .. textutils.urlEncode(input)
                        http.request(state.last_search_url)
                        state.search_results = nil
                        state.search_error = false
                        state.current_page = 1  -- Reset pagination for new search
                    else
                        state.last_search = nil
                        state.last_search_url = nil
                        state.search_results = nil
                        state.search_error = false
                        state.current_page = 1  -- Reset pagination
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
                            
                            if y < 7 or y > 9 or x < 3 or x > state.width-2 then
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
                            if y == state.height - 1 and x >= 2 and x <= 18 then
                                state.logger.info("YouTube", "Back to menu button clicked! Exiting...")
                                
                                -- Visual feedback
                                term.setBackgroundColor(colors.white)
                                term.setTextColor(colors.black)
                                term.setCursorPos(2, state.height - 1)
                                term.write(" ← Back to Menu ")
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
                                -- Search box click (updated coordinates)
                                if y >= 7 and y <= 9 and x >= 3 and x <= state.width-2 then
                                    -- Simple search box styling
                                    for searchY = 7, 9 do
                                        term.setCursorPos(3, searchY)
                                        term.setBackgroundColor(colors.white)
                                        term.clearLine()
                                    end
                                    state.waiting_for_input = true
                                end
            
                                -- Pagination controls
                                if state.search_results and #state.search_results > 0 then
                                    local totalPages = math.ceil(#state.search_results / state.results_per_page)
                                    local controlsY = state.height - 3
                                    
                                    -- Previous button click
                                    if y == controlsY and x >= 3 and x <= 11 and state.current_page > 1 then
                                        state.current_page = state.current_page - 1
                                        youtubePlayer.redrawScreen(state)
                                        return
                                    end
                                    
                                    -- Next button click
                                    if y == controlsY and x >= state.width - 10 and x <= state.width - 2 and state.current_page < totalPages then
                                        state.current_page = state.current_page + 1
                                        youtubePlayer.redrawScreen(state)
                                        return
                                    end
                                end
            
                                -- Search result click (updated coordinates with pagination)
                                if state.search_results and #state.search_results > 0 then
                                    local startIndex = (state.current_page - 1) * state.results_per_page + 1
                                    local endIndex = math.min(startIndex + state.results_per_page - 1, #state.search_results)
                                    
                                    for i = startIndex, endIndex do
                                        local displayIndex = i - startIndex + 1
                                        local resultY1 = 12 + (displayIndex-1)*3  -- Title line
                                        local resultY2 = 13 + (displayIndex-1)*3  -- Artist line
                                        
                                        if y == resultY1 or y == resultY2 then
                                            -- Visual feedback
                                            term.setBackgroundColor(colors.white)
                                            term.setTextColor(colors.black)
                                            term.setCursorPos(3, resultY1)
                                            term.clearLine()
                                            term.write(state.search_results[i].name)
                                            term.setTextColor(colors.gray)
                                            term.setCursorPos(3, resultY2)
                                            term.clearLine()
                                            term.write(state.search_results[i].artist)
                                            sleep(0.2)
                                            
                                            -- Set state (use actual index i, not display index)
                                            state.in_search_result = true
                                            state.clicked_result = i
                                            
                                            -- Redraw
                                            youtubePlayer.redrawScreen(state)
                                            return
                                        end
                                    end
                                end
                            elseif state.tab == 2 and state.in_search_result == true then
                                -- Action menu clicks (updated coordinates: y=7,9,11,13)
                                term.setBackgroundColor(colors.white)
                                term.setTextColor(colors.black)
            
                                if y == 7 then
                                    term.setCursorPos(2,7)
                                    term.clearLine()
                                    term.write(" ▶ Play now ")
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
            
                                if y == 9 then
                                    term.setCursorPos(2,9)
                                    term.clearLine()
                                    term.write(" ⏭ Play next ")
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
            
                                if y == 11 then
                                    term.setCursorPos(2,11)
                                    term.clearLine()
                                    term.write(" + Add to queue ")
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
                                    term.write(" ✗ Cancel ")
                                    sleep(0.2)
                                    state.in_search_result = false
                                end
            
                                youtubePlayer.redrawScreen(state)
                            elseif state.tab == 1 and state.in_search_result == false then
                                -- Now playing tab clicks (updated coordinates)
                                if y == 10 then -- Control buttons row
                                    -- Play/stop button (updated coordinates)
                                    if x >= 3 and x < 12 then
                                        if state.playing or state.now_playing ~= nil or #state.queue > 0 then
                                            term.setBackgroundColor(colors.white)
                                            term.setTextColor(colors.black)
                                            term.setCursorPos(3, 10)
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
                                    if x >= 13 and x < 22 then
                                        if state.now_playing ~= nil or #state.queue > 0 then
                                            term.setBackgroundColor(colors.white)
                                            term.setTextColor(colors.black)
                                            term.setCursorPos(13, 10)
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
                                    if x >= 23 and x < 31 then
                                        if state.looping == 0 then
                                            state.looping = 1
                                        elseif state.looping == 1 then
                                            state.looping = 2
                                        else
                                            state.looping = 0
                                        end
                                    end
                                end
 
                                -- Volume slider (updated coordinates)
                                if y == 13 then
                                    if x >= 3 and x < 27 then
                                        state.volume = (x - 3) / 24 * 3.0
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
                        state.current_page = 1  -- Reset to first page for new results
                        state.logger.info("YouTube", "Search completed: " .. #results .. " results found")
                    else
                        state.search_results = nil
                        state.search_error = true
                        state.current_page = 1
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