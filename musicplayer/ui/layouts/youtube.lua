-- YouTube Music Player UI Layout
-- Enhanced with interactive search functionality from working original

local components = require("musicplayer.ui.components")
local themes = require("musicplayer.ui.themes")

local youtubeUI = {}

-- Tab definitions for YouTube player
local TABS = {" Now Playing ", " Search "}

function youtubeUI.redrawScreen(state)
    if state.waiting_for_input then
        return
    end

    term.setCursorBlink(false)  -- Make sure cursor is off when redrawing
    state.width, state.height = term.getSize()
    
    -- Clear the screen
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Draw header and footer using components
    components.drawHeader(state)
    components.drawFooter(state)

    -- Draw the tabs (adjusted for header)
    term.setCursorPos(1, 2)
    term.setBackgroundColor(colors.gray)
    term.clearLine()
    
    for i=1, #TABS, 1 do
        if state.tab == i then
            term.setTextColor(colors.black)
            term.setBackgroundColor(colors.white)
        else
            term.setTextColor(colors.white)
            term.setBackgroundColor(colors.gray)
        end
        
        term.setCursorPos((math.floor((state.width/#TABS)*(i-0.5)))-math.ceil(#TABS[i]/2)+1, 2)
        term.write(TABS[i])
    end

    if state.tab == 1 then
        youtubeUI.drawNowPlaying(state)
    elseif state.tab == 2 then
        youtubeUI.drawSearch(state)
    end
end

function youtubeUI.drawNowPlaying(state)
    -- Song info (adjusted for header)
    if state.now_playing ~= nil then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.setCursorPos(2, 4)
        term.write(state.now_playing.name)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(2, 5)
        term.write(state.now_playing.artist)
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(2, 4)
        term.write("Not playing")
    end

    -- Status indicators (adjusted for header)
    if state.is_loading == true then
        term.setTextColor(colors.gray)
        term.setBackgroundColor(colors.black)
        term.setCursorPos(2, 6)
        term.write("Loading...")
    elseif state.is_error == true then
        term.setTextColor(colors.red)
        term.setBackgroundColor(colors.black)
        term.setCursorPos(2, 6)
        term.write("Network error")
    end

    -- Control buttons (adjusted for header)
    youtubeUI.drawControlButtons(state)
    
    -- Volume slider (adjusted for header)
    youtubeUI.drawVolumeSlider(state)
    
    -- Queue (adjusted for header and footer)
    if #state.queue > 0 then
        term.setBackgroundColor(colors.black)
        for i=1, #state.queue do
            local queueY = 11 + (i-1)*2
            -- Make sure we don't draw over the footer
            if queueY < state.height - 1 then
                term.setTextColor(colors.white)
                term.setCursorPos(2, queueY)
                term.write(state.queue[i].name)
                term.setTextColor(colors.lightGray)
                term.setCursorPos(2, queueY + 1)
                term.write(state.queue[i].artist)
            end
        end
    end
    
    -- Back to menu button (adjusted for footer)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(2, state.height - 3)
    term.write(" Back to Menu ")
end

function youtubeUI.drawControlButtons(state)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.gray)

    -- Play/Stop button (adjusted for header)
    if state.playing then
        term.setCursorPos(2, 7)
        term.write(" Stop ")
    else
        if state.now_playing ~= nil or #state.queue > 0 then
            term.setTextColor(colors.white)
            term.setBackgroundColor(colors.gray)
        else
            term.setTextColor(colors.lightGray)
            term.setBackgroundColor(colors.gray)
        end
        term.setCursorPos(2, 7)
        term.write(" Play ")
    end

    -- Skip button (adjusted for header)
    if state.now_playing ~= nil or #state.queue > 0 then
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.gray)
    else
        term.setTextColor(colors.lightGray)
        term.setBackgroundColor(colors.gray)
    end
    term.setCursorPos(2 + 7, 7)
    term.write(" Skip ")

    -- Loop button (adjusted for header)
    if state.looping ~= 0 then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.white)
    else
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.gray)
    end
    term.setCursorPos(2 + 7 + 7, 7)
    if state.looping == 0 then
        term.write(" Loop Off ")
    elseif state.looping == 1 then
        term.write(" Loop Queue ")
    else
        term.write(" Loop Song ")
    end
end

function youtubeUI.drawVolumeSlider(state)
    -- Volume slider (adjusted for header)
    term.setCursorPos(2, 9)
    paintutils.drawBox(2, 9, 25, 9, colors.gray)
    local width = math.floor(24 * (state.volume / 3) + 0.5) - 1
    if not (width == -1) then
        paintutils.drawBox(2, 9, 2 + width, 9, colors.white)
    end
    if state.volume < 0.6 then
        term.setCursorPos(2 + width + 2, 9)
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)
    else
        term.setCursorPos(2 + width - 3 - (state.volume == 3 and 1 or 0), 9)
        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)
    end
    term.write(math.floor(100 * (state.volume / 3) + 0.5) .. "%")
end

function youtubeUI.drawSearch(state)
    -- Search bar (adjusted for header)
    paintutils.drawFilledBox(2, 4, state.width-1, 6, colors.lightGray)
    term.setBackgroundColor(colors.lightGray)
    term.setCursorPos(3, 5)
    term.setTextColor(colors.black)
    term.write(state.last_search or "Search...")

    -- Search results (adjusted for header)
    if state.search_results ~= nil then
        term.setBackgroundColor(colors.black)
        for i=1, #state.search_results do
            local resultY = 8 + (i-1)*2
            -- Make sure we don't draw over the footer
            if resultY < state.height - 1 then
                term.setTextColor(colors.white)
                term.setCursorPos(2, resultY)
                term.write(state.search_results[i].name)
                term.setTextColor(colors.lightGray)
                term.setCursorPos(2, resultY + 1)
                term.write(state.search_results[i].artist)
            end
        end
    else
        term.setCursorPos(2, 8)
        term.setBackgroundColor(colors.black)
        if state.search_error == true then
            term.setTextColor(colors.red)
            term.write("Network error")
        elseif state.last_search_url ~= nil then
            term.setTextColor(colors.lightGray)
            term.write("Searching...")
        else
            term.setCursorPos(1, 8)
            term.setTextColor(colors.lightGray)
            print("Tip: You can paste YouTube video or playlist links.")
        end
    end

    -- Song action menu (from working original)
    if state.in_search_result == true then
        term.setBackgroundColor(colors.black)
        term.clear()
        
        -- Redraw header and footer for action menu
        components.drawHeader(state)
        components.drawFooter(state)
        
        term.setCursorPos(2, 3)
        term.setTextColor(colors.white)
        term.write(state.search_results[state.clicked_result].name)
        term.setCursorPos(2, 4)
        term.setTextColor(colors.lightGray)
        term.write(state.search_results[state.clicked_result].artist)

        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)

        term.setCursorPos(2, 7)
        term.clearLine()
        term.write("Play now")

        term.setCursorPos(2, 9)
        term.clearLine()
        term.write("Play next")

        term.setCursorPos(2, 11)
        term.clearLine()
        term.write("Add to queue")

        term.setCursorPos(2, 14)
        term.clearLine()
        term.write("Cancel")
    end
end

-- Enhanced search input handling (keeping our modular approach but with working functionality)
function youtubeUI.handleSearchInput(state, youtubePlayer)
    -- This function is called when search input is needed
    -- The actual input handling is done in the YouTube player's UI loop
    state.waiting_for_input = true
end

return youtubeUI 