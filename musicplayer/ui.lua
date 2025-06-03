-- UI rendering module for the music player
local config = require("musicplayer.config")

local ui = {}

function ui.redrawScreen(state)
    if state.waiting_for_input then
        return
    end

    term.setCursorBlink(false)
    term.setBackgroundColor(config.ui.colors.background)
    term.clear()

    -- Draw the top tabs
    term.setCursorPos(1, 1)
    term.setBackgroundColor(config.ui.colors.tab_inactive)
    term.clearLine()
    
    for i = 1, #config.ui.tabs do
        if state.tab == i then
            term.setTextColor(config.ui.colors.background)
            term.setBackgroundColor(config.ui.colors.tab_active)
        else
            term.setTextColor(config.ui.colors.text_primary)
            term.setBackgroundColor(config.ui.colors.tab_inactive)
        end
        
        local x = (math.floor((state.width / #config.ui.tabs) * (i - 0.5))) - math.ceil(#config.ui.tabs[i] / 2) + 1
        term.setCursorPos(x, 1)
        term.write(config.ui.tabs[i])
    end

    if state.tab == 1 then
        ui.drawNowPlaying(state)
    elseif state.tab == 2 then
        ui.drawSearch(state)
    end
end

function ui.drawNowPlaying(state)
    -- Song info
    if state.now_playing ~= nil then
        term.setBackgroundColor(config.ui.colors.background)
        term.setTextColor(config.ui.colors.text_primary)
        term.setCursorPos(2, 3)
        term.write(state.now_playing.name)
        term.setTextColor(config.ui.colors.text_secondary)
        term.setCursorPos(2, 4)
        term.write(state.now_playing.artist)
    else
        term.setBackgroundColor(config.ui.colors.background)
        term.setTextColor(config.ui.colors.text_secondary)
        term.setCursorPos(2, 3)
        term.write("Not playing")
    end

    -- Status messages
    if state.is_loading then
        term.setTextColor(config.ui.colors.loading)
        term.setBackgroundColor(config.ui.colors.background)
        term.setCursorPos(2, 5)
        term.write("Loading...")
    elseif state.is_error then
        term.setTextColor(config.ui.colors.error)
        term.setBackgroundColor(config.ui.colors.background)
        term.setCursorPos(2, 5)
        term.write("Network error")
    end

    -- Control buttons
    ui.drawControlButtons(state)
    
    -- Volume slider
    ui.drawVolumeSlider(state)
    
    -- Queue
    ui.drawQueue(state)
end

function ui.drawControlButtons(state)
    term.setTextColor(config.ui.colors.text_primary)
    term.setBackgroundColor(config.ui.colors.button)

    -- Play/Stop button
    if state.playing then
        term.setCursorPos(2, 6)
        term.write(" Stop ")
    else
        if state.now_playing ~= nil or #state.queue > 0 then
            term.setTextColor(config.ui.colors.text_primary)
            term.setBackgroundColor(config.ui.colors.button)
        else
            term.setTextColor(config.ui.colors.text_disabled)
            term.setBackgroundColor(config.ui.colors.button)
        end
        term.setCursorPos(2, 6)
        term.write(" Play ")
    end

    -- Skip button
    if state.now_playing ~= nil or #state.queue > 0 then
        term.setTextColor(config.ui.colors.text_primary)
        term.setBackgroundColor(config.ui.colors.button)
    else
        term.setTextColor(config.ui.colors.text_disabled)
        term.setBackgroundColor(config.ui.colors.button)
    end
    term.setCursorPos(2 + 7, 6)
    term.write(" Skip ")

    -- Loop button
    if state.looping ~= 0 then
        term.setTextColor(config.ui.colors.background)
        term.setBackgroundColor(config.ui.colors.button_active)
    else
        term.setTextColor(config.ui.colors.text_primary)
        term.setBackgroundColor(config.ui.colors.button)
    end
    term.setCursorPos(2 + 7 + 7, 6)
    if state.looping == 0 then
        term.write(" Loop Off ")
    elseif state.looping == 1 then
        term.write(" Loop Queue ")
    else
        term.write(" Loop Song ")
    end
end

function ui.drawVolumeSlider(state)
    term.setCursorPos(2, 8)
    paintutils.drawBox(2, 8, 25, 8, config.ui.colors.button)
    local width = math.floor(24 * (state.volume / config.max_volume) + 0.5) - 1
    if width >= 0 then
        paintutils.drawBox(2, 8, 2 + width, 8, config.ui.colors.button_active)
    end
    
    local percentage = math.floor(100 * (state.volume / config.max_volume) + 0.5)
    if state.volume < 0.6 then
        term.setCursorPos(2 + width + 2, 8)
        term.setBackgroundColor(config.ui.colors.button)
        term.setTextColor(config.ui.colors.text_primary)
    else
        term.setCursorPos(2 + width - 3 - (state.volume == config.max_volume and 1 or 0), 8)
        term.setBackgroundColor(config.ui.colors.button_active)
        term.setTextColor(config.ui.colors.background)
    end
    term.write(percentage .. "%")
end

function ui.drawQueue(state)
    if #state.queue > 0 then
        term.setBackgroundColor(config.ui.colors.background)
        for i = 1, #state.queue do
            term.setTextColor(config.ui.colors.text_primary)
            term.setCursorPos(2, 10 + (i - 1) * 2)
            term.write(state.queue[i].name)
            term.setTextColor(config.ui.colors.text_secondary)
            term.setCursorPos(2, 11 + (i - 1) * 2)
            term.write(state.queue[i].artist)
        end
    end
end

function ui.drawSearch(state)
    -- Search bar
    paintutils.drawFilledBox(2, 3, state.width - 1, 5, config.ui.colors.search_box)
    term.setBackgroundColor(config.ui.colors.search_box)
    term.setCursorPos(3, 4)
    term.setTextColor(config.ui.colors.background)
    term.write(state.last_search or "Search...")

    -- Search results
    if state.search_results ~= nil then
        term.setBackgroundColor(config.ui.colors.background)
        for i = 1, #state.search_results do
            term.setTextColor(config.ui.colors.text_primary)
            term.setCursorPos(2, 7 + (i - 1) * 2)
            term.write(state.search_results[i].name)
            term.setTextColor(config.ui.colors.text_secondary)
            term.setCursorPos(2, 8 + (i - 1) * 2)
            term.write(state.search_results[i].artist)
        end
    else
        term.setCursorPos(2, 7)
        term.setBackgroundColor(config.ui.colors.background)
        if state.search_error then
            term.setTextColor(config.ui.colors.error)
            term.write("Network error")
        elseif state.last_search_url ~= nil then
            term.setTextColor(config.ui.colors.text_secondary)
            term.write("Searching...")
        else
            term.setCursorPos(1, 7)
            term.setTextColor(config.ui.colors.text_secondary)
            print("Tip: You can paste YouTube video or playlist links.")
        end
    end

    -- Fullscreen song options
    if state.in_search_result then
        ui.drawSearchResultMenu(state)
    end
end

function ui.drawSearchResultMenu(state)
    term.setBackgroundColor(config.ui.colors.background)
    term.clear()
    term.setCursorPos(2, 2)
    term.setTextColor(config.ui.colors.text_primary)
    term.write(state.search_results[state.clicked_result].name)
    term.setCursorPos(2, 3)
    term.setTextColor(config.ui.colors.text_secondary)
    term.write(state.search_results[state.clicked_result].artist)

    term.setBackgroundColor(config.ui.colors.button)
    term.setTextColor(config.ui.colors.text_primary)

    local options = {"Play now", "Play next", "Add to queue", "Cancel"}
    local positions = {6, 8, 10, 13}
    
    for i, option in ipairs(options) do
        term.setCursorPos(2, positions[i])
        term.clearLine()
        term.write(option)
    end
end

return ui 