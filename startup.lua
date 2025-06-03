-- Bognesferga Radio - Main Entry Point with Telemetry
-- A comprehensive music and radio system for ComputerCraft with advanced logging and dual-screen support

-- Initialize telemetry system first
local telemetry = require("musicplayer.telemetry.telemetry")
local logger

-- Initialize system with telemetry
local function initializeSystem()
    -- Initialize telemetry with INFO level logging
    telemetry.init(telemetry.getLogger().LEVELS.INFO)
    logger = telemetry.getLogger()
    
    logger.info("Startup", "Bognesferga Radio starting up...")
    logger.info("Startup", "System capabilities detected")
    
    -- Start performance monitoring
    telemetry.startPerformanceMonitoring()
    
    -- Display system info on log monitor if available
    if telemetry.hasDualScreen() then
        logger.info("Startup", "Dual screen setup detected - using separate displays")
        telemetry.displaySystemInfo()
    else
        logger.info("Startup", "Single screen setup - using terminal")
    end
    
    return telemetry.getSystemInfo(), telemetry.getCapabilities()
end

-- Load modules with error handling
local function loadModules()
    logger.info("Startup", "Loading application modules...")
    
    local modules = {}
    local moduleList = {
        "config", "state", "ui", "input", "audio", "network", 
        "main", "menu", "radio", "radio_ui"
    }
    
    for _, moduleName in ipairs(moduleList) do
        local success, module = pcall(require, "musicplayer." .. moduleName)
        if success then
            modules[moduleName] = module
            logger.debug("Startup", "Loaded module: " .. moduleName)
        else
            logger.error("Startup", "Failed to load module " .. moduleName .. ": " .. tostring(module))
            telemetry.emergency("Startup", "Critical module load failure: " .. moduleName)
            return nil
        end
    end
    
    logger.info("Startup", "All modules loaded successfully")
    return modules
end

-- Initialize the application state
local function initAppState(systemInfo, capabilities, modules)
    logger.info("Startup", "Initializing application state...")
    
    -- Switch to application display if available
    telemetry.switchToAppDisplay()
    
    local width, height = term.getSize()
    logger.debug("Startup", "Display size: " .. width .. "x" .. height)
    
    local appState = {
        width = width,
        height = height,
        mode = "menu", -- menu, youtube, radio_client, radio_host
        menuState = nil,
        musicState = nil,
        radioState = nil,
        systemInfo = systemInfo,
        capabilities = capabilities,
        telemetry = telemetry
    }
    
    -- Initialize menu state
    if modules.menu then
        appState.menuState = modules.menu.init()
        logger.debug("Startup", "Menu state initialized")
    end
    
    logger.info("Startup", "Application state initialized")
    return appState
end

-- Check system requirements
local function checkRequirements(capabilities)
    logger.info("Startup", "Checking system requirements...")
    
    local warnings = {}
    local errors = {}
    
    if not capabilities.canPlayAudio then
        table.insert(warnings, "No speakers detected - audio playback unavailable")
        logger.warn("Requirements", "No speakers found")
    end
    
    if not capabilities.canUseNetwork then
        table.insert(warnings, "No modems detected - network features unavailable")
        logger.warn("Requirements", "No modems found")
    end
    
    if capabilities.hasExternalDisplay then
        logger.info("Requirements", "External display available")
    end
    
    if capabilities.canUseDualScreen then
        logger.info("Requirements", "Dual screen setup available")
    end
    
    -- Display warnings to user
    if #warnings > 0 then
        term.setTextColor(colors.yellow)
        print("Warnings:")
        for _, warning in ipairs(warnings) do
            print("• " .. warning)
        end
        term.setTextColor(colors.white)
        print()
    end
    
    if #errors > 0 then
        term.setTextColor(colors.red)
        print("Errors:")
        for _, error in ipairs(errors) do
            print("• " .. error)
        end
        term.setTextColor(colors.white)
        return false
    end
    
    logger.info("Requirements", "System requirements check completed")
    return true
end

-- Get station name input with logging
local function getStationName(appState)
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

-- Main menu loop with telemetry
local function runMainMenu(appState)
    logger.info("Menu", "Entering main menu")
    
    while appState.mode == "menu" do
        telemetry.logPerformanceEvent("menu_loop")
        
        if appState.modules.menu then
            appState.modules.menu.drawMenu(appState, appState.menuState)
            local result = appState.modules.menu.handleInput(appState.menuState)
            
            if result == "redraw" then
                -- Continue loop to redraw
            elseif result == "YouTube Music Player" then
                logger.info("Menu", "YouTube Music Player selected")
                appState.mode = "youtube"
                appState.musicState = appState.modules.state.init()
                return true
            elseif result == "Network Radio" then
                logger.info("Menu", "Network Radio selected")
                appState.mode = "radio_client"
                appState.radioState = appState.modules.radio.initClient()
                local success, message = appState.modules.radio.startClient(appState.radioState)
                if not success then
                    logger.error("Radio", "Failed to start radio client: " .. message)
                    term.clear()
                    term.setCursorPos(1, 1)
                    term.setTextColor(colors.red)
                    print("Error: " .. message)
                    print("Press any key to continue...")
                    os.pullEvent("key")
                    appState.mode = "menu"
                end
                return true
            elseif result == "Host Radio Station" then
                logger.info("Menu", "Host Radio Station selected")
                local stationName = getStationName(appState)
                if stationName then
                    appState.mode = "radio_host"
                    appState.radioState = appState.modules.radio.initHost(stationName)
                    local success, message = appState.modules.radio.startHost(appState.radioState)
                    if not success then
                        logger.error("Radio", "Failed to start radio host: " .. message)
                        term.clear()
                        term.setCursorPos(1, 1)
                        term.setTextColor(colors.red)
                        print("Error: " .. message)
                        print("Press any key to continue...")
                        os.pullEvent("key")
                        appState.mode = "menu"
                    end
                else
                    appState.mode = "menu"
                end
                return true
            elseif result == "Exit" then
                logger.info("Menu", "Exit selected")
                return false
            end
        end
        
        sleep(0.05)
    end
    return true
end

-- YouTube music player loop with telemetry
local function runYouTubePlayer(appState)
    logger.info("YouTube", "Starting YouTube music player")
    
    -- Convert system speakers to the format expected by the music state
    local speakers = {}
    for _, speakerInfo in ipairs(appState.systemInfo.speakers) do
        table.insert(speakers, speakerInfo.peripheral)
    end
    
    -- Initialize speakers in music state
    appState.musicState.speakers = speakers
    if #appState.musicState.speakers == 0 then
        logger.error("YouTube", "No speakers available for audio playback")
        term.clear()
        term.setCursorPos(1, 1)
        term.setTextColor(colors.red)
        print("No speakers found! Please attach a speaker.")
        print("Press any key to return to menu...")
        os.pullEvent("key")
        appState.mode = "menu"
        return
    end
    
    logger.info("YouTube", "Using " .. #appState.musicState.speakers .. " speaker(s)")
    
    -- Run the music player with telemetry
    parallel.waitForAny(
        function() 
            logger.debug("YouTube", "Starting UI loop")
            appState.modules.main.uiLoop(appState.musicState) 
        end,
        function() 
            logger.debug("YouTube", "Starting audio loop")
            appState.modules.audio.loop(appState.musicState) 
        end,
        function() 
            logger.debug("YouTube", "Starting network loop")
            appState.modules.network.loop(appState.musicState) 
        end,
        function()
            while appState.mode == "youtube" do
                local event, key = os.pullEvent()
                telemetry.logPerformanceEvent("youtube_event")
                
                if event == "key" and key == keys.escape then
                    logger.info("YouTube", "Escape key pressed - returning to menu")
                    appState.mode = "menu"
                    break
                elseif event == "return_to_menu" or (appState.musicState and appState.musicState.return_to_menu) then
                    logger.info("YouTube", "Return to menu requested")
                    appState.mode = "menu"
                    break
                end
            end
        end
    )
    
    logger.info("YouTube", "YouTube player session ended")
end

-- Radio client loop with telemetry
local function runRadioClient(appState)
    logger.info("Radio", "Starting radio client")
    
    while appState.mode == "radio_client" do
        telemetry.logPerformanceEvent("radio_client_loop")
        
        if appState.modules.radio_ui then
            appState.modules.radio_ui.drawClientInterface(appState, appState.radioState)
        end
        
        -- Handle network messages
        if appState.modules.radio then
            appState.modules.radio.handleClientMessages(appState.radioState)
        end
        
        -- Handle input with logging
        local event, button, x, y = os.pullEvent()
        telemetry.logPerformanceEvent("radio_input")
        
        if event == "key" then
            local key = button
            if key == keys.escape then
                logger.info("Radio", "Radio client shutting down")
                if appState.modules.radio then
                    appState.modules.radio.shutdown(appState.radioState)
                end
                appState.mode = "menu"
                break
            elseif key == keys.s then
                logger.debug("Radio", "Scanning for stations")
                appState.modules.radio.scanForStations(appState.radioState)
            elseif key == keys.up and #appState.radioState.station_list > 0 then
                appState.radioState.selected_station = appState.radioState.selected_station - 1
                if appState.radioState.selected_station < 1 then
                    appState.radioState.selected_station = #appState.radioState.station_list
                end
                logger.debug("Radio", "Selected station: " .. appState.radioState.selected_station)
            elseif key == keys.down and #appState.radioState.station_list > 0 then
                appState.radioState.selected_station = appState.radioState.selected_station + 1
                if appState.radioState.selected_station > #appState.radioState.station_list then
                    appState.radioState.selected_station = 1
                end
                logger.debug("Radio", "Selected station: " .. appState.radioState.selected_station)
            elseif key == keys.enter and #appState.radioState.station_list > 0 then
                local selectedStation = appState.radioState.station_list[appState.radioState.selected_station]
                logger.info("Radio", "Connecting to station: " .. selectedStation.name)
                appState.modules.radio.connectToStation(appState.radioState, selectedStation.id)
            elseif key == keys.d and appState.radioState.connected_station then
                logger.info("Radio", "Disconnecting from station")
                appState.modules.radio.disconnectFromStation(appState.radioState)
            end
        elseif event == "mouse_click" then
            logger.debug("Radio", "Mouse click at " .. x .. "," .. y)
            -- Check for button clicks
            if appState.radioState.scan_button and 
               x >= appState.radioState.scan_button.x1 and x <= appState.radioState.scan_button.x2 and
               y >= appState.radioState.scan_button.y1 and y <= appState.radioState.scan_button.y2 then
                logger.debug("Radio", "Scan button clicked")
                appState.modules.radio.scanForStations(appState.radioState)
            elseif appState.radioState.connect_button and 
                   x >= appState.radioState.connect_button.x1 and x <= appState.radioState.connect_button.x2 and
                   y >= appState.radioState.connect_button.y1 and y <= appState.radioState.connect_button.y2 then
                if #appState.radioState.station_list > 0 then
                    local selectedStation = appState.radioState.station_list[appState.radioState.selected_station]
                    logger.info("Radio", "Connect button clicked - connecting to: " .. selectedStation.name)
                    appState.modules.radio.connectToStation(appState.radioState, selectedStation.id)
                end
            elseif appState.radioState.disconnect_button and 
                   x >= appState.radioState.disconnect_button.x1 and x <= appState.radioState.disconnect_button.x2 and
                   y >= appState.radioState.disconnect_button.y1 and y <= appState.radioState.disconnect_button.y2 then
                logger.info("Radio", "Disconnect button clicked")
                appState.modules.radio.disconnectFromStation(appState.radioState)
            elseif appState.radioState.back_button and 
                   x >= appState.radioState.back_button.x1 and x <= appState.radioState.back_button.x2 and
                   y >= appState.radioState.back_button.y1 and y <= appState.radioState.back_button.y2 then
                logger.info("Radio", "Back button clicked")
                appState.modules.radio.shutdown(appState.radioState)
                appState.mode = "menu"
                break
            else
                -- Check for station selection clicks
                for i, station in ipairs(appState.radioState.station_list) do
                    if station.click_area and 
                       x >= station.click_area.x1 and x <= station.click_area.x2 and
                       y >= station.click_area.y1 and y <= station.click_area.y2 then
                        appState.radioState.selected_station = i
                        logger.debug("Radio", "Station clicked: " .. station.name)
                        break
                    end
                end
            end
        end
        
        sleep(0.1)
    end
    
    logger.info("Radio", "Radio client session ended")
end

-- Add songs to radio playlist using YouTube search
local function addSongsToPlaylist(appState)
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

-- Radio host loop with telemetry
local function runRadioHost(appState)
    logger.info("Radio", "Starting radio host")
    
    while appState.mode == "radio_host" do
        telemetry.logPerformanceEvent("radio_host_loop")
        
        if appState.modules.radio_ui then
            appState.modules.radio_ui.drawHostInterface(appState, appState.radioState)
        end
        
        -- Handle network messages
        if appState.modules.radio then
            appState.modules.radio.handleHostMessages(appState.radioState)
        end
        
        -- Handle input with logging
        local event, button, x, y = os.pullEvent()
        telemetry.logPerformanceEvent("radio_host_input")
        
        if event == "key" then
            local key = button
            if key == keys.escape then
                logger.info("Radio", "Radio host shutting down")
                if appState.modules.radio then
                    appState.modules.radio.shutdown(appState.radioState)
                end
                appState.mode = "menu"
                break
            elseif key == keys.a then
                logger.info("Radio", "Add songs shortcut pressed")
                -- Add songs to playlist (integrate with YouTube search)
                addSongsToPlaylist(appState)
            elseif key == keys.space and #appState.radioState.playlist > 0 then
                if appState.radioState.is_playing then
                    logger.info("Radio", "Stopping playback via spacebar")
                    appState.modules.radio.hostStopPlayback(appState.radioState)
                else
                    local currentSong = appState.radioState.playlist[appState.radioState.current_track]
                    logger.info("Radio", "Starting playback via spacebar: " .. currentSong.name)
                    appState.modules.radio.hostPlaySong(appState.radioState, currentSong)
                end
            elseif key == keys.n and #appState.radioState.playlist > 0 then
                logger.info("Radio", "Next track shortcut pressed")
                appState.modules.radio.hostNextTrack(appState.radioState)
            end
        elseif event == "mouse_click" then
            logger.debug("Radio", "Mouse click at " .. x .. "," .. y)
            -- Check for button clicks
            if appState.radioState.add_button and 
               x >= appState.radioState.add_button.x1 and x <= appState.radioState.add_button.x2 and
               y >= appState.radioState.add_button.y1 and y <= appState.radioState.add_button.y2 then
                logger.info("Radio", "Add songs button clicked")
                addSongsToPlaylist(appState)
            elseif appState.radioState.play_stop_button and 
                   x >= appState.radioState.play_stop_button.x1 and x <= appState.radioState.play_stop_button.x2 and
                   y >= appState.radioState.play_stop_button.y1 and y <= appState.radioState.play_stop_button.y2 then
                if #appState.radioState.playlist > 0 then
                    if appState.radioState.is_playing then
                        logger.info("Radio", "Stop button clicked")
                        appState.modules.radio.hostStopPlayback(appState.radioState)
                    else
                        local currentSong = appState.radioState.playlist[appState.radioState.current_track]
                        logger.info("Radio", "Play button clicked: " .. currentSong.name)
                        appState.modules.radio.hostPlaySong(appState.radioState, currentSong)
                    end
                end
            elseif appState.radioState.next_button and 
                   x >= appState.radioState.next_button.x1 and x <= appState.radioState.next_button.x2 and
                   y >= appState.radioState.next_button.y1 and y <= appState.radioState.next_button.y2 then
                if #appState.radioState.playlist > 0 then
                    logger.info("Radio", "Next button clicked")
                    appState.modules.radio.hostNextTrack(appState.radioState)
                end
            elseif appState.radioState.back_button and 
                   x >= appState.radioState.back_button.x1 and x <= appState.radioState.back_button.x2 and
                   y >= appState.radioState.back_button.y1 and y <= appState.radioState.back_button.y2 then
                logger.info("Radio", "Back button clicked")
                appState.modules.radio.shutdown(appState.radioState)
                appState.mode = "menu"
                break
            else
                -- Check for playlist track selection clicks
                for i, song in ipairs(appState.radioState.playlist) do
                    if song.click_area and 
                       x >= song.click_area.x1 and x <= song.click_area.x2 and
                       y >= song.click_area.y1 and y <= song.click_area.y2 then
                        appState.radioState.current_track = i
                        logger.info("Radio", "Track selected: " .. song.name)
                        break
                    end
                end
            end
        end
        
        sleep(0.1)
    end
    
    logger.info("Radio", "Radio host session ended")
end

-- Main application loop with comprehensive error handling
local function main()
    local success, systemInfo, capabilities = pcall(initializeSystem)
    if not success then
        print("FATAL ERROR: Failed to initialize telemetry system")
        print("Error: " .. tostring(systemInfo))
        return
    end
    
    -- Load modules
    local modules = loadModules()
    if not modules then
        telemetry.emergency("Startup", "Failed to load required modules")
        return
    end
    
    -- Check requirements
    if not checkRequirements(capabilities) then
        logger.fatal("Startup", "System requirements not met")
        return
    end
    
    -- Initialize application
    local appState = initAppState(systemInfo, capabilities, modules)
    appState.modules = modules
    
    logger.info("Startup", "Bognesferga Radio fully initialized")
    
    -- Main application loop
    while true do
        telemetry.logPerformanceEvent("main_loop")
        
        -- Monitor system health periodically
        if math.random() < 0.01 then -- 1% chance per loop
            telemetry.monitorHealth()
        end
        
        local success, result = pcall(function()
            if appState.mode == "menu" then
                return runMainMenu(appState)
            elseif appState.mode == "youtube" then
                runYouTubePlayer(appState)
                return true
            elseif appState.mode == "radio_client" then
                runRadioClient(appState)
                return true
            elseif appState.mode == "radio_host" then
                runRadioHost(appState)
                return true
            end
            return true
        end)
        
        if not success then
            logger.error("Main", "Error in application loop: " .. tostring(result))
            appState.mode = "menu" -- Return to menu on error
        elseif result == false then
            break -- Exit requested
        end
    end
    
    logger.info("Startup", "Application shutting down")
    
    -- Cleanup
    telemetry.cleanup()
    
    -- Final message
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.white)
    print("Thanks for using Bognesferga Radio!")
    
    -- Show performance summary
    local perfSummary = telemetry.getPerformanceSummary()
    if perfSummary then
        print("Session runtime: " .. string.format("%.2f", perfSummary.runtime) .. " seconds")
        print("Final memory usage: " .. string.format("%.2f", perfSummary.memoryUsage) .. " KB")
    end
end

-- Start the application with global error handling
local function safeMain()
    local success, error = pcall(main)
    if not success then
        term.restore() -- Ensure we're back on terminal
        term.setTextColor(colors.red)
        print("FATAL ERROR in Bognesferga Radio:")
        print(tostring(error))
        print()
        print("Please check the log files in musicplayer/logs/")
        term.setTextColor(colors.white)
        
        -- Try to log the error if telemetry is available
        if telemetry then
            telemetry.emergency("Fatal", tostring(error))
        end
    end
end

-- Start the application
safeMain() 