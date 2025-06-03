-- Mode handlers module for Bognesferga Radio
-- Handles all the different application modes (menu, YouTube, radio client/host)

local mode_handlers = {}

-- Main menu loop with telemetry
function mode_handlers.runMainMenu(appState, logger, telemetry)
    local input_handlers = require("musicplayer.input_handlers")
    
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
                local stationName = input_handlers.getStationName(appState, logger, telemetry)
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
function mode_handlers.runYouTubePlayer(appState, logger, telemetry)
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
function mode_handlers.runRadioClient(appState, logger, telemetry)
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

-- Radio host loop with telemetry
function mode_handlers.runRadioHost(appState, logger, telemetry)
    local input_handlers = require("musicplayer.input_handlers")
    
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
                input_handlers.addSongsToPlaylist(appState, logger, telemetry)
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
                input_handlers.addSongsToPlaylist(appState, logger, telemetry)
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

return mode_handlers 