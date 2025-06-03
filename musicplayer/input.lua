-- Input handling module for the music player
local config = require("musicplayer.config")

local input = {}

function input.handleMouseClick(state, button, x, y)
    if button ~= 1 then return end

    -- Tab switching
    if not state.in_search_result and y == 1 then
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
    -- Search box click
    if y >= 3 and y <= 5 and x >= 1 and x <= state.width - 1 then
        paintutils.drawFilledBox(2, 3, state.width - 1, 5, config.ui.colors.button_active)
        term.setBackgroundColor(config.ui.colors.button_active)
        state.waiting_for_input = true
        return false
    end

    -- Search result click
    if state.search_results then
        for i = 1, #state.search_results do
            if y == 7 + (i - 1) * 2 or y == 8 + (i - 1) * 2 then
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
    term.setCursorPos(2, 7 + (index - 1) * 2)
    term.clearLine()
    term.write(state.search_results[index].name)
    term.setTextColor(config.ui.colors.text_disabled)
    term.setCursorPos(2, 8 + (index - 1) * 2)
    term.clearLine()
    term.write(state.search_results[index].artist)
end

function input.handleSearchResultMenu(state, x, y)
    term.setBackgroundColor(config.ui.colors.button_active)
    term.setTextColor(config.ui.colors.background)

    if y == 6 then
        input.highlightMenuOption(2, 6, "Play now")
        sleep(0.2)
        state.in_search_result = false
        input.playNow(state)
        return true
    elseif y == 8 then
        input.highlightMenuOption(2, 8, "Play next")
        sleep(0.2)
        state.in_search_result = false
        input.playNext(state)
        return true
    elseif y == 10 then
        input.highlightMenuOption(2, 10, "Add to queue")
        sleep(0.2)
        state.in_search_result = false
        input.addToQueue(state)
        return true
    elseif y == 13 then
        input.highlightMenuOption(2, 13, "Cancel")
        sleep(0.2)
        state.in_search_result = false
        return true
    end

    return false
end

function input.highlightMenuOption(x, y, text)
    term.setCursorPos(x, y)
    term.clearLine()
    term.write(text)
end

function input.handleNowPlayingTab(state, x, y)
    if y == 6 then
        -- Play/stop button
        if x >= 2 and x < 8 then
            return input.handlePlayStopButton(state)
        end
        -- Skip button
        if x >= 9 and x < 15 then
            return input.handleSkipButton(state)
        end
        -- Loop button
        if x >= 16 and x < 28 then
            return input.handleLoopButton(state)
        end
    elseif y == 8 then
        -- Volume slider
        if x >= 1 and x < 27 then
            input.handleVolumeSlider(state, x)
            return true
        end
    end

    return false
end

function input.handlePlayStopButton(state)
    if state.playing or state.now_playing ~= nil or #state.queue > 0 then
        input.highlightButton(2, 6, state.playing and " Stop " or " Play ")
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
        input.highlightButton(9, 6, " Skip ")
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

function input.handleVolumeSlider(state, x)
    state.volume = (x - 1) / 24 * config.max_volume
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
        if y >= 7 and y <= 9 and x >= 1 and x < 27 then
            input.handleVolumeSlider(state, x)
            return true
        end
    end
    return false
end

return input 