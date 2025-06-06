-- YouTube Music Player UI Layout
-- Enhanced with proper theme system and component usage

local components = require("musicplayer.ui.components")
local themes = require("musicplayer.ui.themes")

local youtubeUI = {}

-- Tab definitions for YouTube player
local TABS = {" Now Playing ", " Search "}

function youtubeUI.redrawScreen(state)
    if state.waiting_for_input then
        return
    end

    term.setCursorBlink(false)
    state.width, state.height = term.getSize()
    
    -- Clear screen with theme background
    components.clearScreen()

    -- Draw header and footer using components
    components.drawHeader(state)
    components.drawFooter(state)

    -- Draw the tabs using components
    components.drawTabs(state, TABS)

    if state.tab == 1 then
        youtubeUI.drawNowPlaying(state)
    elseif state.tab == 2 then
        youtubeUI.drawSearch(state)
    end
end

function youtubeUI.drawNowPlaying(state)
    local theme = themes.getCurrent()
    
    -- Song info using components (adjusted for header)
    components.drawSongInfo(state, 2, 4)

    -- Status indicators using components
    if state.is_loading then
        components.drawStatusIndicator(2, 6, "loading", "Loading...")
    elseif state.is_error then
        components.drawStatusIndicator(2, 6, "error", "Network error")
    elseif state.playing then
        components.drawStatusIndicator(2, 6, "playing", "Playing")
    elseif state.now_playing then
        components.drawStatusIndicator(2, 6, "stopped", "Ready to play")
    end

    -- Control buttons using components (adjusted for header)
    youtubeUI.drawControlButtons(state)
    
    -- Volume slider using components (adjusted for header)
    components.drawVolumeSlider(state)
    
    -- Queue using components (adjusted for header and footer)
    components.drawQueue(state, 2, 11)
    
    -- Back to menu button using components (adjusted for footer)
    components.drawButton(2, state.height - 3, "Back to Menu", false, true)
end

function youtubeUI.drawControlButtons(state)
    local theme = themes.getCurrent()
    local buttonY = 7 -- Adjusted for header
    
    -- Play/Stop button
    local playText = state.playing and "Stop" or "Play"
    local playEnabled = state.playing or state.now_playing ~= nil or #state.queue > 0
    local playActive = state.playing
    components.drawButton(2, buttonY, playText, playActive, playEnabled)

    -- Skip button
    local skipEnabled = state.now_playing ~= nil or #state.queue > 0
    components.drawButton(9, buttonY, "Skip", false, skipEnabled)

    -- Loop button
    local loopText = "Loop Off"
    if state.looping == 1 then
        loopText = "Loop Queue"
    elseif state.looping == 2 then
        loopText = "Loop Song"
    end
    local loopActive = state.looping ~= 0
    components.drawButton(16, buttonY, loopText, loopActive, true)
end

function youtubeUI.drawSearch(state)
    local theme = themes.getCurrent()
    
    -- Search input using components (adjusted for header)
    local searchText = state.last_search or ""
    local placeholder = "Search YouTube or paste URL..."
    components.drawTextInput(2, 5, state.width - 3, searchText, placeholder, state.waiting_for_input)

    -- Search results using components (adjusted for header)
    if state.search_results then
        components.drawSearchResults(state, 2, 8, 8)
    else
        -- Search status
        term.setBackgroundColor(theme.colors.background)
        term.setCursorPos(2, 8)
        if state.search_error then
            components.drawStatusIndicator(2, 8, "error", "Search failed - please try again")
        elseif state.last_search_url then
            components.drawStatusIndicator(2, 8, "loading", "Searching...")
        else
            term.setTextColor(theme.colors.text_disabled)
            term.write("Tip: You can paste YouTube video or playlist links.")
        end
    end

    -- Song action menu (from working original)
    if state.in_search_result then
        components.clearScreen()
        
        -- Redraw header and footer for action menu
        components.drawHeader(state)
        components.drawFooter(state)
        
        -- Selected song info
        if state.search_results and state.clicked_result then
            local selectedSong = state.search_results[state.clicked_result]
            term.setBackgroundColor(theme.colors.background)
            term.setTextColor(theme.colors.text_accent)
            term.setCursorPos(2, 3)
            term.write("♪ " .. selectedSong.name)
            term.setTextColor(theme.colors.text_secondary)
            term.setCursorPos(2, 4)
            term.write("by " .. selectedSong.artist)
        end

        -- Action buttons using components
        components.drawButton(2, 7, "Play now", false, true)
        components.drawButton(2, 9, "Play next", false, true)
        components.drawButton(2, 11, "Add to queue", false, true)
        components.drawButton(2, 14, "Cancel", false, true)
    end
end

return youtubeUI 