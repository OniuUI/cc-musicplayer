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

-- Simple redraw function (based on old version)
function youtubePlayer.redrawScreen(state)
    if state.waiting_for_input then
        return
    end

    term.setCursorBlink(false)
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Draw the tabs (EXACTLY like old version)
    term.setCursorPos(1,1)
    term.setBackgroundColor(colors.gray)
    term.clearLine()
    
    local tabs = {" Now Playing ", " Search "}
    
    for i=1,#tabs,1 do
        if state.tab == i then
            term.setTextColor(colors.black)
            term.setBackgroundColor(colors.white)
        else
            term.setTextColor(colors.white)
            term.setBackgroundColor(colors.gray)
        end
        
        term.setCursorPos((math.floor((state.width/#tabs)*(i-0.5)))-math.ceil(#tabs[i]/2)+1, 1)
        term.write(tabs[i])
    end

    if state.tab == 1 then
        youtubePlayer.drawNowPlaying(state)
    elseif state.tab == 2 then
        youtubePlayer.drawSearch(state)
    end
    
    -- Draw back to menu button
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(2, state.height - 1)
    term.write(" Back to Menu ")
end

-- Draw Now Playing tab (EXACTLY like old version)
function youtubePlayer.drawNowPlaying(state)
    if state.now_playing ~= nil then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.setCursorPos(2,3)
        term.write(state.now_playing.name)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(2,4)
        term.write(state.now_playing.artist)
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(2,3)
        term.write("Not playing")
    end

    if state.is_loading == true then
        term.setTextColor(colors.gray)
        term.setBackgroundColor(colors.black)
        term.setCursorPos(2,5)
        term.write("Loading...")
    elseif state.is_error == true then
        term.setTextColor(colors.red)
        term.setBackgroundColor(colors.black)
        term.setCursorPos(2,5)
        term.write("Network error")
    end

    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.gray)

    if state.playing then
        term.setCursorPos(2, 6)
        term.write(" Stop ")
    else
        if state.now_playing ~= nil or #state.queue > 0 then
            term.setTextColor(colors.white)
            term.setBackgroundColor(colors.gray)
        else
            term.setTextColor(colors.lightGray)
            term.setBackgroundColor(colors.gray)
        end
        term.setCursorPos(2, 6)
        term.write(" Play ")
    end

    if state.now_playing ~= nil or #state.queue > 0 then
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.gray)
    else
        term.setTextColor(colors.lightGray)
        term.setBackgroundColor(colors.gray)
    end
    term.setCursorPos(2 + 7, 6)
    term.write(" Skip ")

    if state.looping ~= 0 then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.white)
    else
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.gray)
    end
    term.setCursorPos(2 + 7 + 7, 6)
    if state.looping == 0 then
        term.write(" Loop Off ")
    elseif state.looping == 1 then
        term.write(" Loop Queue ")
    else
        term.write(" Loop Song ")
    end

    term.setCursorPos(2,8)
    paintutils.drawBox(2,8,25,8,colors.gray)
    local width = math.floor(24 * (state.volume / 3) + 0.5)-1
    if not (width == -1) then
        paintutils.drawBox(2,8,2+width,8,colors.white)
    end
    if state.volume < 0.6 then
        term.setCursorPos(2+width+2,8)
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)
    else
        term.setCursorPos(2+width-3-(state.volume == 3 and 1 or 0),8)
        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)
    end
    term.write(math.floor(100 * (state.volume / 3) + 0.5) .. "%")

    if #state.queue > 0 then
        term.setBackgroundColor(colors.black)
        for i=1,#state.queue do
            term.setTextColor(colors.white)
            term.setCursorPos(2,10 + (i-1)*2)
            term.write(state.queue[i].name)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(2,11 + (i-1)*2)
            term.write(state.queue[i].artist)
        end
    end
end

-- Draw Search tab (EXACTLY like old version)
function youtubePlayer.drawSearch(state)
    -- Search bar
    paintutils.drawFilledBox(2,3,state.width-1,5,colors.lightGray)
    term.setBackgroundColor(colors.lightGray)
    term.setCursorPos(3,4)
    term.setTextColor(colors.black)
    term.write(state.last_search or "Search...")

    --Search results
    if state.search_results ~= nil then
        term.setBackgroundColor(colors.black)
        for i=1,#state.search_results do
            term.setTextColor(colors.white)
            term.setCursorPos(2,7 + (i-1)*2)
            term.write(state.search_results[i].name)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(2,8 + (i-1)*2)
            term.write(state.search_results[i].artist)
        end
    else
        term.setCursorPos(2,7)
        term.setBackgroundColor(colors.black)
        if state.search_error == true then
            term.setTextColor(colors.red)
            term.write("Network error")
        elseif state.last_search_url ~= nil then
            term.setTextColor(colors.lightGray)
            term.write("Searching...")
        else
            term.setCursorPos(1,7)
            term.setTextColor(colors.lightGray)
            print("Tip: You can paste YouTube video or playlist links.")
        end
    end

    --fullscreen song options
    if state.in_search_result == true then
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(2,2)
        term.setTextColor(colors.white)
        term.write(state.search_results[state.clicked_result].name)
        term.setCursorPos(2,3)
        term.setTextColor(colors.lightGray)
        term.write(state.search_results[state.clicked_result].artist)

        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)

        term.setCursorPos(2,6)
        term.clearLine()
        term.write("Play now")

        term.setCursorPos(2,8)
        term.clearLine()
        term.write("Play next")

        term.setCursorPos(2,10)
        term.clearLine()
        term.write("Add to queue")

        term.setCursorPos(2,13)
        term.clearLine()
        term.write("Cancel")
    end
end

-- UI Loop (EXACTLY like old version with monitor support)
function youtubePlayer.uiLoop(state, speakers)
    youtubePlayer.redrawScreen(state)

    while true do
        if state.waiting_for_input then
            parallel.waitForAny(
                function()
                    term.setCursorPos(3,4)
                    term.setBackgroundColor(colors.white)
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
                        else -- monitor_touch
                            button, x, y = 1, param2, param3  -- Treat as left click
                        end

                        if button == 1 then
                            -- Back to menu button (FIRST CHECK)
                            if y == state.height - 1 and x >= 2 and x <= 15 then
                                state.logger.info("YouTube", "Back to menu clicked")
                                return "menu"
                            end
                            
                            -- Tabs
                            if state.in_search_result == false then
                                if y == 1 then
                                    if x < state.width/2 then
                                        state.tab = 1
                                    else
                                        state.tab = 2
                                    end
                                    youtubePlayer.redrawScreen(state)
                                end
                            end
                            
                            if state.tab == 2 and state.in_search_result == false then
                                -- Search box click
                                if y >= 3 and y <= 5 and x >= 1 and x <= state.width-1 then
                                    paintutils.drawFilledBox(2,3,state.width-1,5,colors.white)
                                    term.setBackgroundColor(colors.white)
                                    state.waiting_for_input = true
                                end
            
                                -- Search result click
                                if state.search_results then
                                    for i=1,#state.search_results do
                                        if y == 7 + (i-1)*2 or y == 8 + (i-1)*2 then
                                            term.setBackgroundColor(colors.white)
                                            term.setTextColor(colors.black)
                                            term.setCursorPos(2,7 + (i-1)*2)
                                            term.clearLine()
                                            term.write(state.search_results[i].name)
                                            term.setTextColor(colors.gray)
                                            term.setCursorPos(2,8 + (i-1)*2)
                                            term.clearLine()
                                            term.write(state.search_results[i].artist)
                                            sleep(0.2)
                                            state.in_search_result = true
                                            state.clicked_result = i
                                            youtubePlayer.redrawScreen(state)
                                        end
                                    end
                                end
                            elseif state.tab == 2 and state.in_search_result == true then
                                -- Search result menu clicks
            
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
            
                                if y == 6 then
                                    -- Play/stop button
                                    if x >= 2 and x < 2 + 6 then
                                        if state.playing or state.now_playing ~= nil or #state.queue > 0 then
                                            term.setBackgroundColor(colors.white)
                                            term.setTextColor(colors.black)
                                            term.setCursorPos(2, 6)
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
            
                                    -- Skip button
                                    if x >= 2 + 7 and x < 2 + 7 + 6 then
                                        if state.now_playing ~= nil or #state.queue > 0 then
                                            term.setBackgroundColor(colors.white)
                                            term.setTextColor(colors.black)
                                            term.setCursorPos(2 + 7, 6)
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
            
                                    -- Loop button
                                    if x >= 2 + 7 + 7 and x < 2 + 7 + 7 + 12 then
                                        if state.looping == 0 then
                                            state.looping = 1
                                        elseif state.looping == 1 then
                                            state.looping = 2
                                        else
                                            state.looping = 0
                                        end
                                    end
                                end
 
                                if y == 8 then
                                    -- Volume slider
                                    if x >= 1 and x < 2 + 24 then
                                        state.volume = (x - 1) / 24 * 3
                                        state.speakerManager.setVolume(state.volume)
                                    end
                                end
 
                                youtubePlayer.redrawScreen(state)
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
                                if y >= 7 and y <= 9 then
                                    -- Volume slider
                                    if x >= 1 and x < 2 + 24 then
                                        state.volume = (x - 1) / 24 * 3
                                        state.speakerManager.setVolume(state.volume)
                                    end
                                end
                                youtubePlayer.redrawScreen(state)
                            end
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
                    state.search_results = textutils.unserialiseJSON(handle.readAll())
                    handle.close()
                    os.queueEvent("redraw_screen")
                end
                if url == state.last_download_url then
                    state.is_loading = false
                    state.player_handle = handle
                    state.start = handle.read(4)
                    state.size = 16 * 1024 - 4
                    state.playing_status = 1
                    os.queueEvent("redraw_screen")
                    os.queueEvent("audio_update")
                end
            end,
            function()
                local event, url = os.pullEvent("http_failure") 

                if url == state.last_search_url then
                    state.search_error = true
                    os.queueEvent("redraw_screen")
                end
                if url == state.last_download_url then
                    state.is_loading = false
                    state.is_error = true
                    state.playing = false
                    state.playing_id = nil
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