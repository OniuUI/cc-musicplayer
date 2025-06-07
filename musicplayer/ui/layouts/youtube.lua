-- YouTube Music Player UI Layout
-- Using our proper theme system and components architecture with working functionality

local components = require("musicplayer/ui/components")
local themes = require("musicplayer/ui/themes")

local youtubeUI = {}

-- Tab definitions for YouTube player
local TABS = {" Now Playing ", " Search "}

function youtubeUI.redrawScreen(state)
    if state.waiting_for_input then
        return
    end

    term.setCursorBlink(false)
    state.width, state.height = term.getSize()
    
    -- Debug logging
    if state.logger then
        state.logger.debug("YouTube", "Redrawing screen: tab=" .. state.tab .. " in_search_result=" .. tostring(state.in_search_result))
    end
    
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
    components.drawQueue(state, 2, 12)
    
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
    
    -- Song action menu using our theme system (check this FIRST like original)
    if state.in_search_result then
        youtubeUI.drawSongActionMenu(state)
        return -- Don't draw anything else when in action menu
    end
    
    -- Search input using our themed approach but with original working coordinates
    youtubeUI.drawSearchInput(state)

    -- Search results using our components but with original working layout
    if state.search_results then
        youtubeUI.drawSearchResults(state)
    else
        -- Search status using components
        if state.search_error then
            components.drawStatusIndicator(2, 7, "error", "Search failed - please try again")
        elseif state.last_search_url then
            components.drawStatusIndicator(2, 7, "loading", "Searching...")
        else
            term.setBackgroundColor(theme.colors.background)
            term.setTextColor(theme.colors.text_disabled)
            term.setCursorPos(2, 7)
            term.write("Tip: You can paste YouTube video or playlist links.")
        end
    end
end

function youtubeUI.drawSearchInput(state)
    local theme = themes.getCurrent()
    
    -- Draw search box with theme colors but original working coordinates (y=3-5)
    term.setBackgroundColor(theme.colors.search_box)
    term.setTextColor(theme.colors.text_primary)
    
    -- Draw the search box background (original coordinates)
    for y = 3, 5 do
        term.setCursorPos(2, y)
        term.clearLine()
        if y == 4 then
            -- Center line with text
            term.setCursorPos(3, 4)
            local displayText = state.last_search or "Search YouTube or paste URL..."
            if not state.last_search then
                term.setTextColor(theme.colors.text_disabled)
            end
            term.write(displayText)
        end
    end
end

function youtubeUI.drawSearchResults(state)
    local theme = themes.getCurrent()
    
    -- Debug logging
    if state.logger then
        state.logger.info("YouTube", "Drawing " .. #state.search_results .. " search results")
    end
    
    -- Draw search results with theme colors but original working layout (2 lines per result)
    term.setBackgroundColor(theme.colors.background)
    
    for i = 1, #state.search_results do
        local result = state.search_results[i]
        local y1 = 7 + (i-1)*2  -- First line (title)
        local y2 = 8 + (i-1)*2  -- Second line (artist)
        
        -- Debug logging for each result
        if state.logger then
            state.logger.debug("YouTube", "Drawing result " .. i .. " '" .. result.name .. "' at y=" .. y1 .. "-" .. y2)
        end
        
        -- Don't draw if it would go off screen
        if y2 >= state.height - 2 then
            if state.logger then
                state.logger.debug("YouTube", "Result " .. i .. " would go off screen (y=" .. y2 .. " >= " .. (state.height - 2) .. ")")
            end
            break
        end
        
        -- Song title with theme accent color
        term.setTextColor(theme.colors.text_primary)
        term.setCursorPos(2, y1)
        term.clearLine()
        term.write(result.name)
        
        -- Artist with theme secondary color
        term.setTextColor(theme.colors.text_secondary)
        term.setCursorPos(2, y2)
        term.clearLine()
        term.write(result.artist)
    end
end

function youtubeUI.drawSongActionMenu(state)
    local theme = themes.getCurrent()
    
    -- Debug logging
    if state.logger then
        state.logger.info("YouTube", "Drawing song action menu for result " .. (state.clicked_result or "nil"))
    end
    
    -- Clear screen and redraw with theme background
    components.clearScreen()
    
    -- Redraw header and footer for action menu
    components.drawHeader(state)
    components.drawFooter(state)
    
    -- Selected song info with theme colors
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

    -- Action buttons using our components with original coordinates
    components.drawButton(2, 6, "Play now", false, true)
    components.drawButton(2, 8, "Play next", false, true)
    components.drawButton(2, 10, "Add to queue", false, true)
    components.drawButton(2, 13, "Cancel", false, true)
    
    -- Back to menu button (should still be available in action menu)
    components.drawButton(2, state.height - 3, "Back to Menu", false, true)
end

return youtubeUI 