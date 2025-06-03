-- YouTube Music Player UI Layout
-- Consolidated YouTube player interface using reusable components

local components = require("musicplayer.ui.components")
local themes = require("musicplayer.ui.themes")

local youtubeUI = {}

-- Tab definitions for YouTube player
local TABS = {" Now Playing ", " Search "}

function youtubeUI.redrawScreen(state)
    if state.waiting_for_input then
        return
    end

    components.clearScreen()

    -- Draw header banner
    components.drawHeader(state)
    
    -- Draw the tabs
    components.drawTabs(state, TABS)

    if state.tab == 1 then
        youtubeUI.drawNowPlaying(state)
    elseif state.tab == 2 then
        youtubeUI.drawSearch(state)
    end
    
    -- Draw footer
    components.drawFooter(state)
end

function youtubeUI.drawNowPlaying(state)
    local theme = themes.getCurrent()
    
    -- Song info section
    components.drawSongInfo(state, 3, 4)

    -- Status messages with enhanced colors
    if state.is_loading then
        components.drawStatusIndicator(3, 6, "loading", "Loading...")
    elseif state.is_error then
        components.drawStatusIndicator(3, 6, "error", "Network error")
    elseif state.playing then
        components.drawStatusIndicator(3, 6, "playing", "Playing")
    end

    -- Control buttons
    youtubeUI.drawControlButtons(state)
    
    -- Volume slider
    components.drawVolumeSlider(state)
    
    -- Queue
    components.drawQueue(state, 3, 14)
end

function youtubeUI.drawControlButtons(state)
    local theme = themes.getCurrent()
    local buttonY = 8
    
    -- Play/Stop button
    if state.playing then
        term.setTextColor(theme.colors.text_primary)
        term.setBackgroundColor(theme.colors.error)
        term.setCursorPos(3, buttonY)
        term.write(" STOP ")
    else
        if state.now_playing ~= nil or #state.queue > 0 then
            term.setTextColor(theme.colors.text_primary)
            term.setBackgroundColor(theme.colors.playing)
        else
            term.setTextColor(theme.colors.text_disabled)
            term.setBackgroundColor(theme.colors.button)
        end
        term.setCursorPos(3, buttonY)
        term.write(" PLAY ")
    end

    -- Skip button
    if state.now_playing ~= nil or #state.queue > 0 then
        term.setTextColor(theme.colors.text_primary)
        term.setBackgroundColor(theme.colors.button)
    else
        term.setTextColor(theme.colors.text_disabled)
        term.setBackgroundColor(theme.colors.button)
    end
    term.setCursorPos(11, buttonY)
    term.write(" SKIP ")

    -- Loop button with status indication
    if state.looping ~= 0 then
        term.setTextColor(theme.colors.background)
        term.setBackgroundColor(theme.colors.button_active)
    else
        term.setTextColor(theme.colors.text_primary)
        term.setBackgroundColor(theme.colors.button)
    end
    term.setCursorPos(19, buttonY)
    if state.looping == 0 then
        term.write(" LOOP OFF ")
    elseif state.looping == 1 then
        term.write(" LOOP ALL ")
    else
        term.write(" LOOP ONE ")
    end
    
    -- Back to Menu button
    term.setTextColor(theme.colors.text_primary)
    term.setBackgroundColor(theme.colors.button)
    term.setCursorPos(31, buttonY)
    term.write(" BACK TO MENU ")
end

function youtubeUI.drawSearch(state)
    local theme = themes.getCurrent()
    
    -- Search box
    term.setBackgroundColor(theme.colors.background)
    term.setTextColor(theme.colors.text_primary)
    term.setCursorPos(3, 4)
    term.write("Search YouTube:")
    
    -- Search input box
    components.drawTextInput(3, 5, state.width - 4, "", "Type your search and press Enter...", false)
    
    -- Search button
    components.drawButton(3, 7, "Search", false, true)
    
    -- Search results
    if state.search_results or state.search_error or state.last_search then
        term.setTextColor(theme.colors.text_primary)
        term.setCursorPos(3, 9)
        term.write("Search Results:")
        
        components.drawSearchResults(state, 3, 11, 8)
    end
    
    -- Instructions
    term.setTextColor(theme.colors.text_disabled)
    term.setCursorPos(3, state.height - 3)
    term.write("Click search results to add to queue | ESC: Back to menu")
end

-- Handle search input with improved UI
function youtubeUI.handleSearchInput(state, networkModule)
    local theme = themes.getCurrent()
    
    -- Draw search input box as active
    term.setCursorPos(3, 5)
    term.setBackgroundColor(theme.colors.search_box)
    term.setTextColor(theme.colors.text_primary)
    term.clearLine()
    term.setCursorPos(4, 5)
    
    local input = read()
    
    if input and #input > 0 then
        networkModule.performSearch(state, input)
        state.waiting_for_input = false
        -- Add a small delay to ensure the search request is sent
        sleep(0.1)
        os.queueEvent("redraw_screen")
    else
        state.waiting_for_input = false
        os.queueEvent("redraw_screen")
    end
end

return youtubeUI 