-- Input handling module for Bognesferga Radio
-- Handles specialized input functions like station name input and playlist management

local input_handlers = {}

-- Get station name input with logging
function input_handlers.getStationName(appState, logger, telemetry)
    logger.debug("Input", "Requesting station name input")
    
    if appState.modules and appState.modules.radio_ui then
        appState.modules.radio_ui.drawStationNameInput(appState)
    end
    
    local stationName = ""
    term.setCursorPos(4, 8)
    term.setCursorBlink(true)
    
    while true do
        local event, key = os.pullEvent()
        telemetry.logPerformanceEvent("input_event")
        
        if event == "key" then
            if key == keys.enter and #stationName > 0 then
                term.setCursorBlink(false)
                logger.info("Input", "Station name entered: " .. stationName)
                return stationName
            elseif key == keys.escape then
                term.setCursorBlink(false)
                logger.debug("Input", "Station name input cancelled")
                return nil
            elseif key == keys.backspace and #stationName > 0 then
                stationName = stationName:sub(1, -2)
                -- Clear and redraw input
                term.setBackgroundColor(colors.lightBlue)
                term.setCursorPos(4, 8)
                term.write(string.rep(" ", appState.width - 6))
                term.setCursorPos(4, 8)
                term.setTextColor(colors.black)
                term.write(stationName)
            end
        elseif event == "char" and #stationName < 30 then
            stationName = stationName .. key
            term.setBackgroundColor(colors.lightBlue)
            term.setTextColor(colors.black)
            term.write(key)
        end
    end
end

-- Add songs to radio playlist using YouTube search
function input_handlers.addSongsToPlaylist(appState, logger, telemetry)
    logger.info("Radio", "Opening YouTube search for playlist addition")
    
    -- Create a temporary music state for searching
    local searchState = appState.modules.state.init()
    searchState.tab = 2 -- Search tab
    searchState.width = appState.width
    searchState.height = appState.height
    
    while true do
        telemetry.logPerformanceEvent("playlist_search_loop")
        appState.modules.ui.redrawScreen(searchState)
        
        local event, key, x, y = os.pullEvent()
        
        if event == "key" then
            if key == keys.escape then
                logger.debug("Radio", "YouTube search cancelled")
                break
            end
        elseif event == "mouse_click" then
            local result = appState.modules.input.handleClick(searchState, x, y)
            if result == "back" then
                logger.debug("Radio", "Back from YouTube search")
                break
            elseif result == "search" then
                logger.debug("Radio", "Performing search in playlist mode")
                appState.modules.input.handleSearchInput(searchState)
            elseif type(result) == "table" and result.action == "add_to_radio" then
                -- Add selected song to radio playlist
                logger.info("Radio", "Adding song to playlist: " .. result.song.name)
                appState.modules.radio.addToPlaylist(appState.radioState, result.song)
                break
            end
        end
        
        sleep(0.05)
    end
end

return input_handlers 