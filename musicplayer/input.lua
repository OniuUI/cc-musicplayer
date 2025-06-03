-- Input handling module for the radio player
local config = require("musicplayer.config")

local input = {}

function input.handleMouseClick(state, button, x, y)
    if button ~= 1 then return end

    -- Tab switching (now on line 2 due to header)
    if not state.in_search_result and y == 2 then
        if x < state.width / 2 then
            state.tab = 1
        else
            state.tab = 2
        end
        return true -- redraw needed
    end

    if state.tab == 2 and not state.in_search_result then
        return input.handleSearchTab(state, x, y)
    elseif state.tab == 2 and state.in_search_result then
        return input.handleSearchResultMenu(state, x, y)
    elseif state.tab == 1 and not state.in_search_result then
        return input.handleNowPlayingTab(state, x, y)
    end

    return false
end

function input.handleSearchTab(state, x, y)
    -- Search box click (adjusted for new layout)
    if y >= 5 and y <= 6 and x >= 3 and x <= state.width - 2 then
        paintutils.drawFilledBox(3, 5, state.width - 2, 6, config.ui.colors.button_active)
        term.setBackgroundColor(config.ui.colors.button_active)
        state.waiting_for_input = true
        return false
    end
    
    -- Back to Menu button click
    if y == state.height - 3 and x >= 3 and x < 16 then
        return input.handleBackButton(state)
    end

    -- Search result click (adjusted for new layout)
    if state.search_results then
        for i = 1, #state.search_results do
            if y == 9 + (i - 1) * 2 or y == 10 + (i - 1) * 2 then
                input.highlightSearchResult(state, i)
                sleep(0.2)
                state.in_search_result = true
                state.clicked_result = i
                return true -- redraw needed
            end
        end
    end

    return false
end

function input.highlightSearchResult(state, index)
    term.setBackgroundColor(config.ui.colors.button_active)
    term.setTextColor(config.ui.colors.background)
    term.setCursorPos(3, 9 + (index - 1) * 2)
    term.clearLine()
    term.write(index .. ". " .. state.search_results[index].name)
    term.setTextColor(config.ui.colors.text_disabled)
    term.setCursorPos(6, 10 + (index - 1) * 2)
    term.clearLine()
    term.write(state.search_results[index].artist)
end

function input.handleSearchResultMenu(state, x, y)
    term.setBackgroundColor(config.ui.colors.button_active)
    term.setTextColor(config.ui.colors.background)

    if y == 8 then
        input.highlightMenuOption(3, 8, "Play now")
        sleep(0.2)
        state.in_search_result = false
        input.playNow(state)
        return true
    elseif y == 10 then
        input.highlightMenuOption(3, 10, "Play next")
        sleep(0.2)
        state.in_search_result = false
        input.playNext(state)
        return true
    elseif y == 12 then
        input.highlightMenuOption(3, 12, "Add to queue")
        sleep(0.2)
        state.in_search_result = false
        input.addToQueue(state)
        return true
    elseif y == 15 then
        input.highlightMenuOption(3, 15, "Cancel")
        sleep(0.2)
        state.in_search_result = false
        return true
    end

    return false
end

function input.highlightMenuOption(x, y, text)
    term.setCursorPos(x, y)
    term.clearLine()
    term.write(" " .. text .. " ")
end

function input.handleNowPlayingTab(state, x, y)
    if y == 8 then
        -- Play/stop button (PLAY/STOP at position 3-8)
        if x >= 3 and x < 9 then
            return input.handlePlayStopButton(state)
        end
        -- Skip button (SKIP at position 11-16)
        if x >= 11 and x < 17 then
            return input.handleSkipButton(state)
        end
        -- Loop button (LOOP buttons at position 19-28)
        if x >= 19 and x < 29 then
            return input.handleLoopButton(state)
        end
        -- Back to Menu button (BACK TO MENU at position 31-43)
        if x >= 31 and x < 44 then
            return input.handleBackButton(state)
        end
    elseif y == 11 then
        -- Volume slider (adjusted for new layout)
        if x >= 3 and x <= 25 then
            input.handleVolumeSlider(state, x)
            return true
        end
    end

    return false
end

function input.handlePlayStopButton(state)
    if state.playing or state.now_playing ~= nil or #state.queue > 0 then
        input.highlightButton(3, 8, state.playing and " Stop " or " Play ")
        sleep(0.2)
    end

    if state.playing then
        state.playing = false
        for _, speaker in ipairs(state.speakers) do
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

    return true
end

function input.handleSkipButton(state)
    if state.now_playing ~= nil or #state.queue > 0 then
        input.highlightButton(11, 8, " Skip ")
        sleep(0.2)

        state.is_error = false
        if state.playing then
            for _, speaker in ipairs(state.speakers) do
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

    return true
end

function input.handleLoopButton(state)
    if state.looping == 0 then
        state.looping = 1
    elseif state.looping == 1 then
        state.looping = 2
    else
        state.looping = 0
    end
    return true
end

function input.handleBackButton(state)
    input.highlightButton(31, 8, " BACK TO MENU ")
    sleep(0.2)
    
    -- Stop any playing audio
    if state.playing then
        for _, speaker in ipairs(state.speakers) do
            speaker.stop()
            os.queueEvent("playback_stopped")
        end
        state.playing = false
        state.playing_id = nil
        state.is_loading = false
        state.is_error = false
    end
    
    -- Signal to return to menu
    state.return_to_menu = true
    os.queueEvent("return_to_menu")
    return true
end

function input.handleVolumeSlider(state, x)
    -- Adjust volume calculation for new slider position (starts at x=3, width=22)
    local sliderStart = 3
    local sliderWidth = 22
    local relativeX = x - sliderStart
    state.volume = (relativeX / sliderWidth) * config.max_volume
    if state.volume < 0 then state.volume = 0 end
    if state.volume > config.max_volume then state.volume = config.max_volume end
end

function input.highlightButton(x, y, text)
    term.setBackgroundColor(config.ui.colors.button_active)
    term.setTextColor(config.ui.colors.background)
    term.setCursorPos(x, y)
    term.write(text)
end

function input.playNow(state)
    for _, speaker in ipairs(state.speakers) do
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
            for i = 2, #state.search_results[state.clicked_result].playlist_items do
                table.insert(state.queue, state.search_results[state.clicked_result].playlist_items[i])
            end
        end
    else
        state.now_playing = state.search_results[state.clicked_result]
    end
    os.queueEvent("audio_update")
end

function input.playNext(state)
    if state.search_results[state.clicked_result].type == "playlist" then
        for i = #state.search_results[state.clicked_result].playlist_items, 1, -1 do
            table.insert(state.queue, 1, state.search_results[state.clicked_result].playlist_items[i])
        end
    else
        table.insert(state.queue, 1, state.search_results[state.clicked_result])
    end
    os.queueEvent("audio_update")
end

function input.addToQueue(state)
    if state.search_results[state.clicked_result].type == "playlist" then
        for i = 1, #state.search_results[state.clicked_result].playlist_items do
            table.insert(state.queue, state.search_results[state.clicked_result].playlist_items[i])
        end
    else
        table.insert(state.queue, state.search_results[state.clicked_result])
    end
    os.queueEvent("audio_update")
end

function input.handleMouseDrag(state, button, x, y)
    if button == 1 and state.tab == 1 and not state.in_search_result then
        -- Volume slider drag (adjusted coordinates)
        if y == 11 and x >= 3 and x <= 25 then
            input.handleVolumeSlider(state, x)
            return true
        end
    end
    return false
end

-- Wrapper function for compatibility with radio playlist functionality
function input.handleClick(state, x, y)
    return input.handleMouseClick(state, 1, x, y)
end

-- Function to handle search input for radio playlist functionality
function input.handleSearchInput(state)
    term.setCursorPos(4, 5)
    term.setBackgroundColor(config.ui.colors.button_active)
    term.setTextColor(config.ui.colors.background)
    local searchInput = read()
    
    local network = require("musicplayer.network")
    network.performSearch(state, searchInput)
    state.waiting_for_input = false
    return "search_complete"
end

return input 